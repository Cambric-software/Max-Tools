/// Turns a plain-English sentence into a tool call.
///
/// The palette is offline and rule-based on purpose: it must work with no
/// network, respond instantly, and never hallucinate a tool. When the input is
/// ambiguous it says so and offers alternatives instead of guessing.
library;

import '../features/tools/tool_descriptor.dart';
import '../features/tools/tool_registry.dart';
import '../features/tools/variable_store.dart';
import 'corrector.dart';
import 'text_distance.dart';

/// How a candidate tool matched the sentence.
enum MatchKind {
  /// The dotted tool id was typed directly.
  id('id'),
  /// A word of the tool name matched.
  name('name'),
  /// A declared synonym matched.
  synonym('synonym'),
  /// A tag or description word matched.
  keyword('keyword'),
  /// Only matched after typo correction.
  corrected('corrected'),
  /// Matched on edit distance alone.
  fuzzy('fuzzy');

  const MatchKind(this.label);

  /// Human-readable label shown in the UI.
  final String label;

  /// How much this kind of match should be trusted.
  double get weight => switch (this) {
        MatchKind.id => 1.0,
        MatchKind.name => 0.9,
        MatchKind.synonym => 0.8,
        MatchKind.keyword => 0.6,
        MatchKind.corrected => 0.55,
        MatchKind.fuzzy => 0.4,
      };
}

/// One ranked tool candidate.
class ToolCandidate {
  /// Create a candidate.
  const ToolCandidate({
    required this.tool,
    required this.score,
    required this.kind,
    this.matchedOn = '',
  });

  /// The tool this candidate points at.
  final ToolDescriptor tool;

  /// 0.0 to 1.0.
  final double score;

  /// What kind of match produced it.
  final MatchKind kind;

  /// The word that matched, for display.
  final String matchedOn;

  @override
  String toString() => '${tool.id} (${score.toStringAsFixed(2)}, ${kind.name})';
}

/// What the parser understood.
class PaletteIntent {
  /// Create an intent.
  const PaletteIntent({
    required this.sentence,
    this.candidates = const <ToolCandidate>[],
    this.arguments = const <String, dynamic>{},
    this.missingParameters = const <ToolParameter>[],
    this.wasCorrected = false,
    this.correctionNote = '',
  });

  /// The sentence that was parsed.
  final String sentence;

  /// Ranked candidates, best first.
  final List<ToolCandidate> candidates;

  /// Arguments extracted from the sentence.
  final Map<String, dynamic> arguments;

  /// Required parameters still missing, so the UI can prompt for them.
  final List<ToolParameter> missingParameters;

  /// Whether typo correction changed the input.
  final bool wasCorrected;

  /// Human note describing the correction.
  final String correctionNote;

  /// The best candidate, or null when nothing matched.
  ToolCandidate? get best => candidates.isEmpty ? null : candidates.first;

  /// Whether one tool stands out clearly enough to run without asking.
  bool get isConfident {
    final candidate = best;
    if (candidate == null) return false;
    return IntentParser.isConfidentMatch(candidate);
  }

  /// Whether the sentence named no tool at all.
  bool get isEmpty => candidates.isEmpty;
}

/// Parses sentences into tool candidates and arguments.
class IntentParser {
  final ToolRegistry _registry;
  final Corrector _corrector;

  /// Create a parser over [registry].
  IntentParser(this._registry, {Corrector? corrector})
      : _corrector = corrector ?? Corrector.forRegistry(_registry);

  /// The corrector in use, so the UI can offer spelling help.
  Corrector get corrector => _corrector;

  static final RegExp _numberPattern = RegExp(r'-?\d+(?:\.\d+)?');
  static final RegExp _wordPattern = RegExp(r'[A-Za-z]+');
  static final RegExp _pathPattern = RegExp(
    // A drive letter, UNC-ish prefix, home dir, or relative path — with no
    // embedded spaces, so the surrounding sentence is never swallowed.
    r'(?:[A-Za-z]:[\\/]|~[\\/]|\.{1,2}[\\/]|/)[^\s,;]*',
  );

  /// Multipliers for recognised units, so "2gb" reads as a byte count.
  static const Map<String, int> _unitMultipliers = <String, int>{
    'b': 1,
    'kb': 1024,
    'mb': 1024 * 1024,
    'gb': 1024 * 1024 * 1024,
    'tb': 1024 * 1024 * 1024 * 1024,
  };

  static const Map<String, double> _fpsMultipliers = <String, double>{
    '23.976': 23.976,
    '24': 24,
    '25': 25,
    '29.97': 29.97,
    '30': 30,
    '50': 50,
    '59.94': 59.94,
    '60': 60,
  };

  /// Parse [sentence] into an intent.
  PaletteIntent parse(String sentence, {VariableStore? variables}) {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) {
      return PaletteIntent(sentence: trimmed);
    }

    final correction = _corrector.correctPhrase(trimmed);
    final working = correction.changed ? correction.corrected : trimmed;
    final words = working
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9./\\_-]+'))
        .where((word) => word.isNotEmpty)
        .toList();

    final candidates = rank(working, words);
    if (candidates.isEmpty) {
      return PaletteIntent(
        sentence: trimmed,
        wasCorrected: correction.changed,
        correctionNote: correction.suggestion ?? '',
      );
    }

    final best = candidates.first;
    final arguments = extractArguments(
      best.tool,
      working,
      variables: variables,
      matchedOn: best.matchedOn,
    );
    final missing = best.tool.parameters
        .where((parameter) =>
            parameter.required && !arguments.containsKey(parameter.name))
        .toList();

    return PaletteIntent(
      sentence: trimmed,
      candidates: candidates.take(6).toList(),
      arguments: arguments,
      missingParameters: missing,
      wasCorrected: correction.changed,
      correctionNote: correction.suggestion ?? '',
    );
  }

  /// Generic verbs that are never decisive on their own.
  ///
  /// "hash" alone clearly means the hash tool; "convert" alone could mean six
  /// different things, so the palette offers options instead of guessing.
  static const Set<String> kAmbiguousAlone = <String>{
    'add', 'apply', 'build', 'change', 'check', 'compute', 'convert', 'create',
    'decode', 'edit', 'encode', 'export', 'filter', 'find', 'format', 'generate',
    'get', 'import', 'list', 'load', 'make', 'open', 'parse', 'process', 'read',
    'remove', 'rename', 'run', 'save', 'search', 'send', 'set', 'show', 'sort',
    'split', 'start', 'stop', 'update', 'write',
  };

  /// Rank tools against [words], best first.
  List<ToolCandidate> rank(String sentence, List<String> words) {
    final scored = <String, ToolCandidate>{};

    void offer(ToolDescriptor tool, MatchKind kind, String matched, double bonus) {
      final score = (kind.weight + bonus).clamp(0.0, 1.0);
      final existing = scored[tool.id];
      if (existing != null && existing.score >= score) return;
      scored[tool.id] = ToolCandidate(
        tool: tool,
        score: score,
        kind: kind,
        matchedOn: matched,
      );
    }

    final lowerSentence = sentence.toLowerCase();

    for (final tool in _registry.all()) {
      // 1. Direct id.
      if (lowerSentence.contains(tool.id.toLowerCase())) {
        offer(tool, MatchKind.id, tool.id, 0);
        continue;
      }

      // 2. Tool name: the whole name, or its head noun.
      //
      // The head noun ("hash ...", "sort these lines") is a strong signal and
      // outranks a tool that merely lists the word as a tag. A one-word
      // sentence is also accepted, but only for a head noun of four letters or
      // more: "hash" is deliberate, while "convert" is genuinely ambiguous and
      // must not look confident.
      final nameWords = tool.name.toLowerCase().split(RegExp(r'[^a-z0-9]+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (nameWords.length > 1) {
        if (_containsAll(lowerSentence, nameWords)) {
          offer(tool, MatchKind.name, tool.name, 0.1);
        } else if (_containsAll(lowerSentence, <String>[nameWords.first])) {
          final alone = words.length == 1;
          if (alone && kAmbiguousAlone.contains(nameWords.first)) {
            // Generic verb on its own: not decisive.
          } else if (!alone || nameWords.first.length >= 4) {
            offer(tool, MatchKind.name, nameWords.first, alone ? 0.05 : 0.02);
          }
        }
      } else if (nameWords.length == 1 && words.contains(nameWords.first)) {
        offer(tool, MatchKind.name, nameWords.first, 0.02);
      }

      // 3. Synonyms, tags and phrases, matched on whole words only.
      for (final synonym in <String>[
        ...tool.synonyms,
        ...tool.tags,
      ]) {
        final phrase = synonym.toLowerCase().trim();
        if (phrase.isEmpty) continue;
        final synonymWords = phrase.split(RegExp(r'[^a-z0-9]+'))
            .where((w) => w.isNotEmpty)
            .toList();
        if (synonymWords.isEmpty) continue;
        if (_containsAll(lowerSentence, synonymWords)) {
          // A longer phrase is a more specific match, so it outranks a bare
          // word: "list files" should pick the lister, not every file tool.
          offer(
            tool,
            synonymWords.length == 1 ? MatchKind.keyword : MatchKind.synonym,
            synonym,
            synonymWords.length == 1 ? 0 : 0.05 + synonymWords.length * 0.02,
          );
        }
      }

      // 4. Single keyword hit.
      for (final token in tool.searchTokens) {
        if (token.length > 3 && words.contains(token)) {
          offer(tool, MatchKind.keyword, token, 0);
        }
      }

      // 5. Fuzzy: every word of the tool name is a near miss of one word.
      if (nameWords.isNotEmpty) {
        final hits = nameWords
            .map((w) => words.any((candidate) => isTypoOf(w, candidate)))
            .where((matched) => matched)
            .length;
        if (hits == nameWords.length && nameWords.isNotEmpty) {
          offer(tool, MatchKind.fuzzy, tool.name, 0);
        }
      }
    }

    final ranked = scored.values.toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.tool.id.compareTo(b.tool.id);
      });
    return ranked;
  }

  /// Whether the palette should act on [candidate] without asking.
  ///
  /// A strong match on a specific signal (id, name, multi-word synonym) is
  /// enough. A bare keyword hit is not: "convert" alone could mean several
  /// tools, so the palette offers options instead of guessing.
  static bool isConfidentMatch(ToolCandidate candidate) {
    if (candidate.score < 0.75) return false;
    return switch (candidate.kind) {
      MatchKind.id || MatchKind.name || MatchKind.fuzzy => true,
      MatchKind.synonym => candidate.matchedOn.trim().contains(' '),
      MatchKind.keyword || MatchKind.corrected => false,
    };
  }

  /// Pull arguments for [tool] out of [sentence].
  ///
  /// Numbers go to numeric parameters, `$name` references are interpolated when
  /// a [variables] store is supplied, a path-looking string goes to a
  /// path parameter, and whatever text is left over feeds the first required
  /// text parameter.
  Map<String, dynamic> extractArguments(
    ToolDescriptor tool,
    String sentence, {
    VariableStore? variables,
    String matchedOn = '',
  }) {
    final arguments = <String, dynamic>{};
    // Tokens already used for an argument. They are removed from the leftover
    // prose so "useHeaders yes" does not end up as the text to hash.
    final consumed = <String>[];
    if (tool.parameters.isEmpty) return arguments;

    final numbers = _numberPattern
        .allMatches(sentence)
        .map((m) => num.tryParse(m.group(0)!))
        .whereType<num>()
        .toList();

    final numbersUsed = <int>{};
    for (final parameter in tool.parameters) {
      final name = parameter.name.toLowerCase();
      final isNumeric = parameter.isNumeric || _isNumericParameter(name);

      if (isNumeric && numbers.isNotEmpty) {
        final index = numbers.indexWhere((value) => !numbersUsed.contains(numbers.indexOf(value)));
        if (index >= 0) {
          numbersUsed.add(index);
          final value = numbers[index];
          arguments[parameter.name] = parameter.type == VariableType.number
              ? _asNumber(value)
              : value;
          continue;
        }
      }

      if (parameter.isBoolean) {
        if (RegExp(r'\b(yes|true|enable|on)\b').hasMatch(sentence.toLowerCase())) {
          arguments[parameter.name] = true;
          consumed.add('yes');
          continue;
        }
        if (RegExp(r'\b(no|false|disable|off)\b').hasMatch(sentence.toLowerCase())) {
          arguments[parameter.name] = false;
          consumed.add('no');
          continue;
        }
      }

      // Option-style text parameter: a String default such as "ascending"
      // means the tool accepts a small set of words. Both the option itself
      // and its opposite are recognised, so "descending" is understood even
      // when the default is "ascending".
      final defaultValue = parameter.defaultValue;
      if (defaultValue is String && defaultValue.isNotEmpty) {
        final chosen = _firstOptionMatch(
          sentence,
          <String>[defaultValue, ..._synonymsFor(defaultValue)],
        ) ?? _firstOptionMatch(sentence, _oppositeFor(defaultValue));
        if (chosen != null) {
          arguments[parameter.name] = chosen;
          consumed.add(chosen);
          continue;
        }
      }

      final isPath = _isPathParameter(name);
      if (isPath) {
        final path = _firstPath(sentence);
        if (path != null) {
          arguments[parameter.name] = path;
          continue;
        }
      }
    }

    // Leftover prose feeds the first required text-like parameter. Parameter
    // names are command words too: "useHeaders yes" is not text to hash.
    // Only the names that actually produced a value are stripped, so a word
    // that merely shares a parameter's name stays in the user's text.
    final usedNames = tool.parameters
        .where((parameter) => arguments.containsKey(parameter.name))
        .map((parameter) => parameter.name)
        .toList();
    final leftover = _stripCommandWords(
      sentence,
      matchedOn,
      <String>[...consumed, ...usedNames],
    );
    if (leftover.isNotEmpty) {
      for (final parameter in tool.parameters) {
        if (arguments.containsKey(parameter.name)) continue;
        // A leftover sentence is content, not a file location or a number.
        if (parameter.isNumeric || parameter.isBoolean) continue;
        if (_isPathParameter(parameter.name)) continue;
        if (parameter.required) {
          arguments[parameter.name] = leftover;
          break;
        }
      }
    }

    // Variable interpolation last, so numbers and paths resolve first.
    if (variables != null && arguments.isNotEmpty) {
      try {
        return variables.interpolateArgs(arguments);
      } catch (_) {
        // An unknown variable must not hide the parsed arguments; the tool
        // layer will report the real problem when it runs.
        return arguments;
      }
    }
    return arguments;
  }

  /// Whether a parameter name denotes a filesystem location.
  static bool _isPathParameter(String name) =>
      name.contains('path') ||
      name.contains('file') ||
      name.contains('folder') ||
      name.contains('dir');

  /// Extra words accepted for a given option default.
  static List<String> _synonymsFor(String option) => switch (option) {
        'ascending' => <String>['asc', 'up', 'a-z', 'forward'],
        'descending' => <String>['desc', 'down', 'z-a', 'reverse', 'backwards'],
        'left' => <String>['leading'],
        'right' => <String>['trailing', 'end'],
        'center' => <String>['centre', 'middle'],
        'keep' => <String>['with', 'only'],
        'remove' => <String>['without', 'drop', 'exclude'],
        'pretty' => <String>['prettyprint', 'indent', 'formatted'],
        _ => const <String>[],
      };

  /// The opposite of an option, so "descending" is recognised when the tool's
  /// default is "ascending".
  static List<String> _oppositeFor(String option) => switch (option) {
        'ascending' => <String>['descending', 'desc', 'down', 'z-a'],
        'descending' => <String>['ascending', 'asc', 'up', 'a-z'],
        'keep' => <String>['remove', 'drop', 'without', 'exclude'],
        'remove' => <String>['keep', 'only', 'with'],
        'left' => <String>['right'],
        'right' => <String>['left'],
        'center' => <String>['left', 'right'],
        _ => const <String>[],
      };

  /// Return the first of [options] that appears in [sentence].
  static String? _firstOptionMatch(String sentence, List<String> options) {
    final lower = sentence.toLowerCase();
    for (final option in options) {
      final word = option.toLowerCase();
      if (RegExp('(^|[^a-z])${RegExp.escape(word)}([^a-z]|\$)')
          .hasMatch(lower)) {
        return option;
      }
    }
    return null;
  }

  /// Keep whole numbers whole so a count of 12 does not arrive as 12.0.
  static Object _asNumber(num value) {
    if (value is int) return value;
    if (value == value.roundToDouble()) return value.toInt();
    return value.toDouble();
  }

  static bool _isNumericParameter(String name) =>
      <String>{
        'width',
        'height',
        'size',
        'length',
        'limit',
        'count',
        'fps',
        'frames',
        'seconds',
        'minutes',
        'hours',
        'amount',
        'rate',
        'price',
        'quantity',
        'percentage',
        'spaces',
        'number',
      }.contains(name);

  /// Whether every word of [words] appears in [haystack] as a whole word.
  ///
  /// The boundary class must exclude letters, not just non-word characters:
  /// with `[^a-z0-9]` the word "file" matches inside "files", which sent
  /// "list files" to every file tool instead of the lister.
  static bool _containsAll(String haystack, List<String> words) {
    for (final word in words) {
      if (!RegExp('(^|[^A-Za-z0-9])${RegExp.escape(word)}([^A-Za-z0-9]|\$)')
          .hasMatch(haystack)) {
        return false;
      }
    }
    return true;
  }

  static String? _firstPath(String sentence) {
    for (final match in _pathPattern.allMatches(sentence)) {
      final candidate = match.group(0)!.trim().replaceAll(RegExp(r'[.,;:]+$'), '');
      if (candidate.isEmpty) continue;
      // A bare "/" is punctuation, not a path.
      if (candidate == '/' || candidate == '\\') continue;
      return candidate;
    }
    return null;
  }

  /// Remove the command words, the words that produced the match, and any
  /// numbers, so the remainder can serve as a tool's text input.
  ///
  /// Using the words that actually matched (rather than a fixed verb list)
  /// means "pad text width 12" leaves nothing behind, while
  /// "hash my secret password" correctly leaves "my secret password".
  static String _stripCommandWords(
    String sentence,
    String matchedOn, [
    List<String> consumed = const <String>[],
  ]) {
    var text = sentence;
    // The phrase that produced the match, word by word.
    for (final word in matchedOn.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (word.isEmpty) continue;
      text = _removeWord(text, word);
    }
    // Values already claimed by another argument.
    for (final token in consumed) {
      for (final word in token.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
        if (word.isEmpty) continue;
        text = _removeWord(text, word);
      }
    }
    for (final verb in <String>[
      'please',
      'convert',
      'format',
      'hash',
      'checksum',
      'parse',
      'build',
      'make',
      'create',
      'run',
      'with',
      'for',
      'the',
      'to',
      'and',
      'in',
      'of',
      'a',
      'an',
      'my',
      'me',
    ]) {
      text = _removeWord(text, verb);
    }
    text = text.replaceAll(_numberPattern, ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Remove [word] from [text] on whole-word boundaries only.
  static String _removeWord(String text, String word) => text.replaceAll(
        RegExp('(^|[^A-Za-z])${RegExp.escape(word)}([^A-Za-z]|\$)',
            caseSensitive: false),
        ' ',
      );

  /// Unit-aware numeric extraction, used by the animator and business tools.
  static num? parseSize(String text) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(b|kb|mb|gb|tb)\b',
            caseSensitive: false)
        .firstMatch(text);
    if (match == null) return null;
    final value = num.tryParse(match.group(1)!);
    final multiplier = _unitMultipliers[match.group(2)!.toLowerCase()];
    if (value == null || multiplier == null) return null;
    return value * multiplier;
  }

  /// Frame-rate extraction, tolerating the decimal forms studios use.
  static double? parseFrameRate(String text) {
    final match = RegExp(r'(\d{2}(?:\.\d+)?)\s*fps', caseSensitive: false)
        .firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    return _fpsMultipliers[value.toString()] ?? value;
  }

  /// Bare words used when scanning for parameter names.
  static List<String> words(String text) => _wordPattern
      .allMatches(text)
      .map((m) => m.group(0)!.toLowerCase())
      .toList();
}
