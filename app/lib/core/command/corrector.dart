/// Typo correction for the command palette.
///
/// Recovers from the mistakes people actually make: transposed letters
/// ("csv" -> "cvs"), missing letters ("chksum" -> "checksum"), doubled letters
/// ("worde" -> "word"), and words the palette simply does not know.
///
/// Correction is conservative by design. A word is only rewritten when it is
/// close to something in the vocabulary *and* rewriting it actually improves
/// the query — an unknown word is left alone so the user sees their own text
/// rather than a confident wrong guess.
library;

import '../features/tools/tool_registry.dart';
import 'text_distance.dart';

/// One offered correction.
class Correction {
  /// Create a correction from [original] to [corrected].
  const Correction({
    required this.original,
    required this.corrected,
    required this.distance,
    required this.reason,
  });

  /// The word as the user typed it.
  final String original;

  /// The word the palette believes was meant.
  final String corrected;

  /// Edit distance between the two.
  final int distance;

  /// Why this correction was offered.
  final String reason;

  @override
  String toString() => '$original -> $corrected ($reason)';
}

/// Common words that must never be "corrected" into a tool word.
///
/// Without this the palette rewrites perfectly good English: "list files" has
/// no entry for the plural "files", so it would helpfully change it to "file"
/// and break the very match it was trying to help with.
const Set<String> kNeverCorrect = <String>{
  'a', 'about', 'all', 'also', 'an', 'and', 'any', 'are', 'as', 'at', 'be',
  'been', 'but', 'by', 'can', 'come', 'could', 'do', 'does', 'each', 'even',
  'every', 'file', 'files', 'find', 'first', 'for', 'from', 'get', 'give',
  'go', 'has', 'have', 'he', 'her', 'here', 'how', 'i', 'if', 'in', 'into',
  'is', 'it', 'its', 'just', 'last', 'let', 'line', 'lines', 'make', 'me',
  'more', 'most', 'my', 'new', 'no', 'not', 'now', 'of', 'on', 'one', 'only',
  'or', 'other', 'our', 'out', 'over', 'please', 'same', 'she', 'should',
  'show', 'so', 'some', 'text', 'texts', 'than', 'that', 'the', 'their',
  'them', 'then', 'there', 'these', 'they', 'this', 'to', 'too', 'up', 'us',
  'use', 'used', 'very', 'want', 'was', 'we', 'were', 'what', 'when', 'where',
  'which', 'while', 'who', 'why', 'will', 'with', 'would', 'you', 'your',
};

/// Corrects user input against the tool vocabulary.
class Corrector {
  /// Maps a known word to the tool ids that mention it.
  final Map<String, List<String>> _sources;
  final Set<String> _knownWords;

  /// Build a corrector from the words a [registry] exposes, plus [extraWords].
  factory Corrector.forRegistry(
    ToolRegistry registry, {
    List<String> extraWords = const <String>[],
  }) {
    final sources = <String, List<String>>{};

    void register(String word, String source) {
      final key = word.toLowerCase().trim();
      if (key.isEmpty) return;
      final list = sources.putIfAbsent(key, () => <String>[]);
      if (!list.contains(source)) list.add(source);
    }

    for (final tool in registry.all()) {
      for (final token in tool.searchTokens) {
        register(token, tool.id);
      }
      // Phrases too: "parse csv" should be correctable as a unit.
      register(tool.name.toLowerCase(), tool.id);
      register(tool.id, tool.id);
    }
    for (final word in extraWords) {
      register(word, 'vocabulary');
    }
    return Corrector._(sources, sources.keys.toSet());
  }

  Corrector._(this._sources, this._knownWords);

  /// Whether [word] is already known.
  ///
  /// A simple plural counts as known: the vocabulary holds "file", so "files"
  /// is understood rather than corrected into something else.
  bool isKnown(String word) {
    final lower = word.toLowerCase();
    if (_knownWords.contains(lower)) return true;
    return _knownWords.contains(_singular(lower));
  }

  static String _singular(String word) {
    if (word.endsWith('ies') && word.length > 3) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.endsWith('es') && word.length > 3) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && !word.endsWith('ss') && word.length > 2) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  /// Best correction for [word], or null when nothing is close enough.
  ///
  /// Exact matches return null, so callers can treat a non-null result as
  /// "this word needed fixing".
  Correction? correct(String word) {
    final lower = word.toLowerCase();
    if (lower.isEmpty) return null;
    if (isKnown(lower)) return null;
    if (kNeverCorrect.contains(lower)) return null;

    final candidates = <Correction>[];
    for (final known in _knownWords) {
      if (isTypoOf(lower, known)) {
        candidates.add(
          Correction(
            original: word,
            corrected: known,
            distance: editDistance(lower, known),
            reason: _reason(lower, known),
          ),
        );
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final byDistance = a.distance.compareTo(b.distance);
      if (byDistance != 0) return byDistance;
      // Prefer the longer word: "sort" should beat "sor".
      return b.corrected.length.compareTo(a.corrected.length);
    });
    return candidates.first;
  }

  /// Up to [limit] words that [word] could have meant, best first.
  List<String> suggestions(String word, {int limit = 5}) {
    final lower = word.toLowerCase();
    if (lower.isEmpty) return const <String>[];
    final scored = <String, double>{};
    for (final known in _knownWords) {
      final score = similarity(lower, known);
      if (score >= 0.6) scored[known] = score;
    }
    final ranked = scored.keys.toList()
      ..sort((a, b) {
        final byScore = scored[b]!.compareTo(scored[a]!);
        if (byScore != 0) return byScore;
        return a.compareTo(b);
      });
    return ranked.take(limit).toList();
  }

  /// Correct every standalone word of [phrase] that has a confident fix.
  ///
  /// Returns the corrected phrase plus the list of corrections applied, so the
  /// UI can show "did you mean" rather than silently changing the input.
  ///
  /// Only whitespace-delimited chunks that are *entirely* a plain word are
  /// touched. Anything else is left exactly as typed, which is what keeps
  /// paths, URLs, filenames and identifiers intact: a token-level pass turned
  /// `C:/tmp/data.bin` into `a:/tmp/data.big`.
  PhraseCorrection correctPhrase(String phrase) {
    final corrections = <Correction>[];
    final chunks = phrase.split(RegExp(r'\s+'));
    final rebuilt = chunks.map((chunk) {
      if (!RegExp(r'^[A-Za-z]+$').hasMatch(chunk)) return chunk;
      final fix = correct(chunk);
      if (fix == null) return chunk;
      corrections.add(fix);
      // Preserve the user's capitalisation style.
      if (chunk.length > 1 && chunk[0] == chunk[0].toUpperCase()) {
        return fix.corrected[0].toUpperCase() + fix.corrected.substring(1);
      }
      return fix.corrected;
    }).toList();
    return PhraseCorrection(
      original: phrase,
      corrected: rebuilt.join(' '),
      corrections: corrections,
    );
  }

  /// The tool ids that mention [word], for "did you mean" hints.
  List<String> toolsFor(String word) {
    final entry = _sources[word.toLowerCase()];
    if (entry == null) return const <String>[];
    final ids = entry.toList()..sort();
    return ids;
  }

  static String _reason(String typed, String candidate) {
    if (typed.length == candidate.length && typed != candidate) {
      return 'letters are transposed';
    }
    if (typed.length > candidate.length) {
      return 'extra letters';
    }
    return 'missing letters';
  }
}

/// The result of correcting a whole phrase.
class PhraseCorrection {
  /// Create a correction result.
  const PhraseCorrection({
    required this.original,
    required this.corrected,
    required this.corrections,
  });

  /// The phrase as typed.
  final String original;

  /// The phrase with confident fixes applied.
  final String corrected;

  /// Every fix that was applied.
  final List<Correction> corrections;

  /// Whether anything changed.
  bool get changed => original != corrected;

  /// A one-line "did you mean" description, or null when nothing changed.
  String? get suggestion {
    if (!changed) return null;
    return corrections.map((c) => c.corrected).join(', ');
  }
}
