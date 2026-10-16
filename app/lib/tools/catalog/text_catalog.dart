/// Text and formatting tools.
///
/// These are pure functions: no I/O, no services, no state. That makes them
/// the safest possible first surface — and the most obviously correct, which
/// matters when the user is checking a number before trusting it.
library;

import 'dart:convert';

import '../tool_descriptor.dart';

/// Convenience for a required single-value text parameter.
ToolParameter _text(String name, String description) => ToolParameter(
      name: name,
      description: description,
      required: true,
    );

/// Convenience for an optional single-value text parameter.
ToolParameter _optional(
  String name,
  String description, {
  Object? defaultValue,
}) =>
    ToolParameter(
      name: name,
      description: description,
      defaultValue: defaultValue,
    );

/// Read the required `text` argument, guaranteed present by validation.
String _arg(Map<String, dynamic> args) => args['text'] as String;

List<ToolDescriptor> textTools() => <ToolDescriptor>[
      ToolDescriptor(
        id: 'text.base64Encode',
        name: 'Base64 Encode',
        description: 'Encode text as Base64.',
        category: ToolCategory.developer,
        tags: <String>['base64', 'encode', 'binary'],
        synonyms: <String>['encode base64', 'to base64'],
        parameters: <ToolParameter>[_text('text', 'Text to encode.')],
        run: (args) async => ToolResult.success(base64Encode(_arg(args))),
      ),
      ToolDescriptor(
        id: 'text.base64Decode',
        name: 'Base64 Decode',
        description: 'Decode Base64 back to text.',
        category: ToolCategory.developer,
        tags: <String>['base64', 'decode', 'binary'],
        synonyms: <String>['decode base64', 'from base64'],
        parameters: <ToolParameter>[_text('text', 'Base64 text to decode.')],
        run: (args) async {
          try {
            return ToolResult.success(base64Decode(_arg(args)));
          } on FormatException catch (error) {
            return ToolResult.failure('Not valid Base64: ${error.message}');
          }
        },
      ),
      ToolDescriptor(
        id: 'text.urlEncode',
        name: 'URL Encode',
        description: 'Percent-encode text for use in a URL.',
        category: ToolCategory.network,
        tags: <String>['url', 'encode', 'percent', 'escape'],
        synonyms: <String>['encode url', 'escape url'],
        parameters: <ToolParameter>[_text('text', 'Text to encode.')],
        run: (args) async => ToolResult.success(Uri.encodeComponent(_arg(args))),
      ),
      ToolDescriptor(
        id: 'text.urlDecode',
        name: 'URL Decode',
        description: 'Decode percent-encoded URL text.',
        category: ToolCategory.network,
        tags: <String>['url', 'decode', 'unescape'],
        synonyms: <String>['decode url', 'unescape url'],
        parameters: <ToolParameter>[_text('text', 'Encoded text to decode.')],
        run: (args) async {
          try {
            return ToolResult.success(Uri.decodeComponent(_arg(args)));
          } on FormatException catch (error) {
            return ToolResult.failure('Not valid URL encoding: ${error.message}');
          }
        },
      ),
      ToolDescriptor(
        id: 'text.toUpper',
        name: 'UPPERCASE',
        description: 'Convert text to uppercase.',
        category: ToolCategory.developer,
        tags: <String>['case', 'upper', 'caps'],
        synonyms: <String>['uppercase', 'make caps'],
        parameters: <ToolParameter>[_text('text', 'Text to convert.')],
        run: (args) async => ToolResult.success(_arg(args).toUpperCase()),
      ),
      ToolDescriptor(
        id: 'text.toLower',
        name: 'lowercase',
        description: 'Convert text to lowercase.',
        category: ToolCategory.developer,
        tags: <String>['case', 'lower'],
        synonyms: <String>['lowercase', 'make lower'],
        parameters: <ToolParameter>[_text('text', 'Text to convert.')],
        run: (args) async => ToolResult.success(_arg(args).toLowerCase()),
      ),
      ToolDescriptor(
        id: 'text.titleCase',
        name: 'Title Case',
        description: 'Capitalise the first letter of every word.',
        category: ToolCategory.developer,
        tags: <String>['case', 'title'],
        synonyms: <String>['title case', 'capitalise words'],
        parameters: <ToolParameter>[_text('text', 'Text to convert.')],
        run: (args) async {
          final source = _arg(args);
          // Capitalise the first letter of each word, leaving the rest as-is
          // so "iPhone" and "NASA" survive intact.
          return ToolResult.success(source.replaceAllMapped(
            RegExp(r"[A-Za-z0-9']+"),
            (match) => _capitalize(match.group(0)!),
          ));
        },
      ),
      ToolDescriptor(
        id: 'text.reverse',
        name: 'Reverse Text',
        description: 'Reverse the characters of the text.',
        category: ToolCategory.developer,
        tags: <String>['reverse', 'flip'],
        synonyms: <String>['flip text', 'backwards'],
        parameters: <ToolParameter>[_text('text', 'Text to reverse.')],
        run: (args) async => ToolResult.success(_arg(args).split('').reversed.join()),
      ),
      ToolDescriptor(
        id: 'text.wordCount',
        name: 'Word Count',
        description: 'Count words, characters, lines and sentences.',
        category: ToolCategory.developer,
        tags: <String>['count', 'words', 'characters', 'statistics'],
        synonyms: <String>['count words', 'how many words', 'text stats'],
        parameters: <ToolParameter>[_text('text', 'Text to measure.')],
        run: (args) async {
          final value = _arg(args);
          final words = value
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .length;
          final sentences = value
              .split(RegExp(r'[.!?]+'))
              .where((part) => part.trim().isNotEmpty)
              .length;
          return ToolResult.success(<String, int>{
            'words': words,
            'characters': value.length,
            'charactersNoSpaces': value.replaceAll(RegExp(r'\s'), '').length,
            'lines': value.isEmpty ? 0 : '\n'.allMatches(value).length + 1,
            'sentences': sentences,
          });
        },
      ),
      ToolDescriptor(
        id: 'text.trim',
        name: 'Trim Text',
        description: 'Remove leading and trailing whitespace.',
        category: ToolCategory.developer,
        tags: <String>['trim', 'whitespace', 'clean'],
        synonyms: <String>['strip whitespace', 'clean text'],
        parameters: <ToolParameter>[_text('text', 'Text to trim.')],
        run: (args) async => ToolResult.success(_arg(args).trim()),
      ),
      ToolDescriptor(
        id: 'text.dedupeLines',
        name: 'Remove Duplicate Lines',
        description: 'Drop repeated lines, keeping the first occurrence.',
        category: ToolCategory.developer,
        tags: <String>['dedupe', 'unique', 'lines'],
        synonyms: <String>['remove duplicate lines', 'unique lines'],
        parameters: <ToolParameter>[_text('text', 'Text whose lines to deduplicate.')],
        run: (args) async {
          final seen = <String>{};
          final kept = <String>[];
          for (final line in _arg(args).split('\n')) {
            if (seen.add(line)) kept.add(line);
          }
          return ToolResult.success(kept.join('\n'));
        },
      ),
      ToolDescriptor(
        id: 'text.sortLines',
        name: 'Sort Lines',
        description: 'Sort lines alphabetically or numerically.',
        category: ToolCategory.developer,
        tags: <String>['sort', 'order', 'lines'],
        synonyms: <String>['sort lines', 'order lines'],
        parameters: <ToolParameter>[
          _text('text', 'Text whose lines to sort.'),
          _optional('order', 'ascending or descending.', defaultValue: 'ascending'),
          _optional('numeric', 'true to sort numbers, false for text.',
              defaultValue: false),
        ],
        run: (args) async {
          final descending =
              (args['order'] as String? ?? 'ascending').toLowerCase() == 'descending';
          final numeric = args['numeric'] == true;
          final lines = _arg(args).split('\n').toList();
          lines.sort((a, b) {
            final int result;
            if (numeric) {
              final left = num.tryParse(a.trim());
              final right = num.tryParse(b.trim());
              if (left == null || right == null) {
                return a.compareTo(b);
              }
              result = left.compareTo(right);
            } else {
              result = a.toLowerCase().compareTo(b.toLowerCase());
            }
            return descending ? -result : result;
          });
          return ToolResult.success(lines.join('\n'));
        },
      ),
      ToolDescriptor(
        id: 'text.filterLines',
        name: 'Filter Lines',
        description: 'Keep only the lines containing a substring, or drop them.',
        category: ToolCategory.developer,
        tags: <String>['filter', 'lines', 'grep'],
        synonyms: <String>['filter lines', 'keep lines with'],
        parameters: <ToolParameter>[
          _text('text', 'Text whose lines to filter.'),
          _text('query', 'Substring to match.'),
          _optional('mode', 'keep (default) or remove.', defaultValue: 'keep'),
          _optional('ignoreCase', 'true for case-insensitive matching.',
              defaultValue: false),
        ],
        run: (args) async {
          final keep =
              (args['mode'] as String? ?? 'keep').toLowerCase() != 'remove';
          final ignoreCase = args['ignoreCase'] == true;
          final query = args['query'] as String;
          final haystack = ignoreCase ? query.toLowerCase() : query;
          final kept = <String>[];
          for (final line in _arg(args).split('\n')) {
            final candidate = ignoreCase ? line.toLowerCase() : line;
            if (candidate.contains(haystack) == keep) kept.add(line);
          }
          return ToolResult.success(kept.join('\n'));
        },
      ),
      ToolDescriptor(
        id: 'text.replaceAll',
        name: 'Replace Text',
        description: 'Replace every occurrence of a substring.',
        category: ToolCategory.developer,
        tags: <String>['replace', 'find', 'substitute'],
        synonyms: <String>['replace text', 'find and replace'],
        parameters: <ToolParameter>[
          _text('text', 'Text to search in.'),
          _text('find', 'Text to find.'),
          _text('replace', 'Replacement text.'),
          _optional('ignoreCase', 'true for case-insensitive matching.',
              defaultValue: false),
        ],
        run: (args) async {
          final find = args['find'] as String;
          if (find.isEmpty) {
            return const ToolResult.failure('"find" cannot be empty.');
          }
          final replace = args['replace'] as String;
          final source = _arg(args);
          if (args['ignoreCase'] == true) {
            final pattern = RegExp(RegExp.escape(find), caseSensitive: false);
            return ToolResult.success(source.replaceAll(pattern, replace));
          }
          return ToolResult.success(source.split(find).join(replace));
        },
      ),
      ToolDescriptor(
        id: 'text.caseTo',
        name: 'Convert Case',
        description: 'Convert an identifier between camel, snake, kebab and Pascal.',
        category: ToolCategory.developer,
        tags: <String>['camel', 'snake', 'kebab', 'pascal', 'identifier'],
        synonyms: <String>['snake to camel', 'camel to snake', 'convert case'],
        parameters: <ToolParameter>[
          _text('text', 'Identifier to convert.'),
          _optional('to', 'camel, pascal, snake, kebab or constant.',
              defaultValue: 'camel'),
        ],
        run: (args) async => ToolResult.success(
          convertIdentifierCase(_arg(args), args['to'] as String? ?? 'camel'),
        ),
      ),
      ToolDescriptor(
        id: 'text.slug',
        name: 'Make Slug',
        description: 'Turn a title into a URL-safe slug.',
        category: ToolCategory.developer,
        tags: <String>['slug', 'url', 'permalink'],
        synonyms: <String>['url slug', 'permalink'],
        parameters: <ToolParameter>[
          _text('text', 'Text to slugify.'),
          _optional('separator', 'Separator character.', defaultValue: '-'),
        ],
        run: (args) async {
          final separator = args['separator'] as String? ?? '-';
          final slug = _arg(args)
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), separator)
              .replaceAll(RegExp('${RegExp.escape(separator)}{2,}'), separator)
              .replaceAll(RegExp('^${RegExp.escape(separator)}|'
                  '${RegExp.escape(separator)}\$'), '');
          return ToolResult.success(slug);
        },
      ),
      ToolDescriptor(
        id: 'text.pad',
        name: 'Pad Text',
        description: 'Pad text to a fixed width with a fill character.',
        category: ToolCategory.developer,
        tags: <String>['pad', 'align', 'width'],
        synonyms: <String>['pad text', 'align columns'],
        parameters: <ToolParameter>[
          _text('text', 'Text to pad.'),
          _optional('width', 'Target width in characters.', defaultValue: 10),
          _optional('fill', 'Fill character.', defaultValue: ' '),
          _optional('align', 'left, right or center.', defaultValue: 'left'),
        ],
        run: (args) async {
          final text = _arg(args);
          final width = args['width'] as int? ?? 10;
          final fill = (args['fill'] as String? ?? ' ').isEmpty
              ? ' '
              : (args['fill'] as String)[0];
          final align = args['align'] as String? ?? 'left';
          if (text.length >= width) return ToolResult.success(text);
          final missing = width - text.length;
          switch (align) {
            case 'right':
              return ToolResult.success(fill * missing + text);
            case 'center':
              final left = missing ~/ 2;
              return ToolResult.success(
                fill * left + text + fill * (missing - left),
              );
            default:
              return ToolResult.success(text + fill * missing);
          }
        },
      ),
      ToolDescriptor(
        id: 'text.regexMatch',
        name: 'Regex Match',
        description: 'List every match of a pattern in the text.',
        category: ToolCategory.developer,
        tags: <String>['regex', 'pattern', 'match'],
        synonyms: <String>['regex match', 'apply pattern'],
        parameters: <ToolParameter>[
          _text('text', 'Text to search.'),
          _text('pattern', 'Regular expression.'),
          _optional('ignoreCase', 'true for case-insensitive matching.',
              defaultValue: false),
        ],
        run: (args) async {
          final matches = _compile(args).allMatches(_arg(args)).toList();
          return ToolResult.success(<String, dynamic>{
            'count': matches.length,
            'matches': matches.map((m) => m.group(0)).toList(),
          });
        },
      ),
      ToolDescriptor(
        id: 'text.regexReplace',
        name: 'Regex Replace',
        description: 'Replace every match of a pattern.',
        category: ToolCategory.developer,
        tags: <String>['regex', 'replace', 'substitute'],
        synonyms: <String>['regex replace', 'pattern replace'],
        parameters: <ToolParameter>[
          _text('text', 'Text to modify.'),
          _text('pattern', 'Regular expression.'),
          _text('replace', 'Replacement, with \$1 for capture groups.'),
          _optional('ignoreCase', 'true for case-insensitive matching.',
              defaultValue: false),
        ],
        run: (args) async {
          // Dart has no RegExp.replaceAll, so capture groups ($1, $2) are
          // expanded here via replaceAllMapped.
          final replaced = _arg(args).replaceAllMapped(
            _compile(args),
            (match) => expandCaptureGroups(match, args['replace'] as String),
          );
          return ToolResult.success(replaced);
        },
      ),
      ToolDescriptor(
        id: 'text.regexTest',
        name: 'Regex Test',
        description: 'Report whether a pattern matches, and where.',
        category: ToolCategory.developer,
        tags: <String>['regex', 'test', 'validate'],
        synonyms: <String>['test regex', 'does pattern match'],
        parameters: <ToolParameter>[
          _text('text', 'Text to test.'),
          _text('pattern', 'Regular expression.'),
          _optional('ignoreCase', 'true for case-insensitive matching.',
              defaultValue: false),
        ],
        run: (args) async {
          final match = _compile(args).firstMatch(_arg(args));
          return ToolResult.success(<String, dynamic>{
            'matches': match != null,
            if (match != null) 'group': match.group(0),
            if (match != null) 'start': match.start,
            if (match != null) 'end': match.end,
          });
        },
      ),
      ToolDescriptor(
        id: 'text.markdownTableToCsv',
        name: 'Markdown Table to CSV',
        description: 'Convert a markdown table into CSV.',
        category: ToolCategory.developer,
        tags: <String>['markdown', 'table', 'csv', 'convert'],
        synonyms: <String>['markdown to csv', 'table to csv'],
        parameters: <ToolParameter>[_text('text', 'The markdown table.')],
        run: (args) async => ToolResult.success(markdownTableToCsv(_arg(args))),
      ),
      ToolDescriptor(
        id: 'text.diffLines',
        name: 'Compare Lines',
        description: 'Compare two texts line by line and list the differences.',
        category: ToolCategory.developer,
        tags: <String>['diff', 'compare', 'changes'],
        synonyms: <String>['diff text', 'compare texts'],
        parameters: <ToolParameter>[
          _text('before', 'Original text.'),
          _text('after', 'Modified text.'),
        ],
        run: (args) async {
          final before = (args['before'] as String).split('\n');
          final after = (args['after'] as String).split('\n');
          final changes = <Map<String, dynamic>>[];
          final longest = before.length > after.length ? before.length : after.length;
          for (var i = 0; i < longest; i++) {
            final left = i < before.length ? before[i] : null;
            final right = i < after.length ? after[i] : null;
            if (left != right) {
              changes.add(<String, dynamic>{
                'line': i + 1,
                'before': left,
                'after': right,
              });
            }
          }
          return ToolResult.success(<String, dynamic>{
            'identical': changes.isEmpty,
            'changedLines': changes.length,
            'changes': changes,
          });
        },
      ),
      ToolDescriptor(
        id: 'text.indent',
        name: 'Indent Text',
        description: 'Indent every line by a number of spaces or a tab.',
        category: ToolCategory.developer,
        tags: <String>['indent', 'format', 'spacing'],
        synonyms: <String>['indent text', 'add indentation'],
        parameters: <ToolParameter>[
          _text('text', 'Text to indent.'),
          _optional('spaces', 'Number of spaces (0 to use a tab).', defaultValue: 2),
        ],
        run: (args) async {
          final spaces = args['spaces'] as int? ?? 2;
          final prefix = spaces == 0 ? '\t' : ' ' * spaces;
          return ToolResult.success(
            _arg(args).split('\n').map((line) => '$prefix$line').join('\n'),
          );
        },
      ),
      ToolDescriptor(
        id: 'text.joinLines',
        name: 'Join Lines',
        description: 'Join lines into one line using a separator.',
        category: ToolCategory.developer,
        tags: <String>['join', 'merge', 'lines'],
        synonyms: <String>['join lines', 'merge lines'],
        parameters: <ToolParameter>[
          _text('text', 'Text whose lines to join.'),
          _optional('separator', 'Text placed between lines.', defaultValue: ' '),
        ],
        run: (args) async => ToolResult.success(
          _arg(args).split('\n').join(args['separator'] as String? ?? ' '),
        ),
      ),
      ToolDescriptor(
        id: 'text.split',
        name: 'Split Text',
        description: 'Split text on a separator into a list.',
        category: ToolCategory.developer,
        tags: <String>['split', 'separate', 'parts'],
        synonyms: <String>['split text', 'separate by'],
        parameters: <ToolParameter>[
          _text('text', 'Text to split.'),
          _optional('separator', 'Separator text.', defaultValue: '\n'),
        ],
        run: (args) async => ToolResult.success(
          _arg(args).split(args['separator'] as String? ?? '\n'),
        ),
      ),
      ToolDescriptor(
        id: 'text.charsToNumbers',
        name: 'Character Codes',
        description: 'Show the code point of each character.',
        category: ToolCategory.developer,
        tags: <String>['code', 'unicode', 'character', 'ascii'],
        synonyms: <String>['ascii codes', 'unicode values'],
        parameters: <ToolParameter>[_text('text', 'Text to inspect.')],
        run: (args) async => ToolResult.success(<Map<String, Object?>>[
          for (final char in _arg(args).split(''))
            <String, Object?>{'char': char, 'code': char.codeUnitAt(0)},
        ]),
      ),
      ToolDescriptor(
        id: 'text.escapeCsv',
        name: 'Escape for CSV',
        description: 'Quote and escape a value for safe CSV output.',
        category: ToolCategory.developer,
        tags: <String>['csv', 'escape', 'quote'],
        synonyms: <String>['escape csv', 'quote csv value'],
        parameters: <ToolParameter>[_text('text', 'Value to escape.')],
        run: (args) async {
          final value = _arg(args);
          final needsQuotes =
              value.contains(',') || value.contains('"') || value.contains('\n');
          if (!needsQuotes) return ToolResult.success(value);
          return ToolResult.success('"${value.replaceAll('"', '""')}"');
        },
      ),
    ];

/// Compile the `pattern` argument, honouring `ignoreCase`.
RegExp _compile(Map<String, dynamic> args) {
  final pattern = args['pattern'] as String;
  try {
    return RegExp(pattern, caseSensitive: args['ignoreCase'] != true);
  } on FormatException catch (error) {
    throw ToolArgumentError('Invalid regular expression: ${error.message}');
  }
}

/// Base64 encode text as UTF-8 bytes.
String base64Encode(String input) => base64.encode(utf8.encode(input));

/// Base64 decode back to text, throwing [FormatException] on bad input.
String base64Decode(String input) => utf8.decode(
      base64.decode(input.replaceAll(RegExp(r'\s'), '')),
      allowMalformed: true,
    );

/// Substitute `$1`, `$2`, ... in [replacement] with the groups of [match].
///
/// `$$` is an escaped dollar sign. A reference to a group that did not
/// participate in the match expands to the empty string rather than throwing.
String expandCaptureGroups(Match match, String replacement) {
  final buffer = StringBuffer();
  for (var i = 0; i < replacement.length; i++) {
    final char = replacement[i];
    if (char != r'$') {
      buffer.write(char);
      continue;
    }
    if (i + 1 < replacement.length && replacement[i + 1] == r'$') {
      buffer.write(r'$');
      i++;
      continue;
    }
    var digits = '';
    var cursor = i + 1;
    while (cursor < replacement.length && digits.length < 2) {
      final digit = int.tryParse(replacement[cursor]);
      if (digit == null) break;
      digits += replacement[cursor];
      cursor++;
    }
    if (digits.isEmpty) {
      buffer.write(char);
      continue;
    }
    final index = int.parse(digits);
    buffer.write(match.group(index) ?? '');
    i = cursor - 1;
  }
  return buffer.toString();
}

/// Convert an identifier between casing styles.
String convertIdentifierCase(String input, String target) {
  final words = _splitIdentifier(input);
  if (words.isEmpty) return '';
  switch (target.toLowerCase()) {
    case 'snake':
      return words.map((w) => w.toLowerCase()).join('_');
    case 'kebab':
      return words.map((w) => w.toLowerCase()).join('-');
    case 'constant':
      return words.map((w) => w.toUpperCase()).join('_');
    case 'pascal':
      return words.map((w) => _capitalize(w)).join();
    case 'camel':
    default:
      if (words.length == 1) return words.first.toLowerCase();
      return words.first.toLowerCase() +
          words.skip(1).map(_capitalize).join();
  }
}

List<String> _splitIdentifier(String input) {
  if (input.trim().isEmpty) return <String>[];
  final spaced = input
      .replaceAllMapped(RegExp('([A-Z])'), (m) => ' ${m.group(0)}')
      .replaceAll(RegExp('[_\\-.]+'), ' ')
      .trim();
  return spaced
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
}

String _capitalize(String word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1).toLowerCase();

/// Convert a markdown table into CSV text.
String markdownTableToCsv(String markdown) {
  final lines = markdown
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('|'))
      .toList();
  if (lines.isEmpty) return '';
  final rows = <List<String>>[];
  for (final line in lines) {
    // Skip the |---|---| separator row.
    final cells = line
        .replaceAll(RegExp(r'^\|'), '')
        .replaceAll(RegExp(r'\|$'), '')
        .split('|')
        .map((cell) => cell.trim())
        .toList();
    if (cells.every((cell) => RegExp(r'^:?-{2,}:?$').hasMatch(cell))) continue;
    rows.add(cells);
  }
  if (rows.isEmpty) return '';
  final buffer = StringBuffer();
  for (final row in rows) {
    buffer
      ..write(row.map(_csvCell).join(','))
      ..writeln();
  }
  return buffer.toString().trimRight();
}

String _csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Thrown for a user-correctable input problem (for example a bad pattern).
class ToolArgumentError implements Exception {
  /// Create an argument error with a user-facing [message].
  const ToolArgumentError(this.message);

  /// What is wrong, phrased for the person using the app.
  final String message;

  @override
  String toString() => message;
}
