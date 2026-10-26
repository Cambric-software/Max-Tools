import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tool_shell.dart';

enum _Transform {
  upper('UPPER CASE'),
  lower('lower case'),
  title('Title Case'),
  sentence('Sentence case'),
  reverse('Reverse characters'),
  sortLines('Sort lines A→Z'),
  sortLinesReverse('Sort lines Z→A'),
  dedupe('Remove duplicate lines'),
  removeBlank('Remove blank lines'),
  trimEach('Trim spaces on every line'),
  numberLines('Number the lines'),
  slug('Make a URL slug'),
  stripExtraSpaces('Collapse repeated spaces');

  const _Transform(this.label);
  final String label;
}

/// Counting, reshaping and cleaning up text.
///
/// Aimed at the ordinary jobs: shortening a bio, tidying a pasted list,
/// checking whether an essay is over a word limit, finding and replacing.
class TextToolkitTool extends StatefulWidget {
  /// Create the tool.
  const TextToolkitTool({super.key});

  @override
  State<TextToolkitTool> createState() => _TextToolkitToolState();
}

class _TextToolkitToolState extends State<TextToolkitTool> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _find = TextEditingController();
  final TextEditingController _replace = TextEditingController();
  _Transform _transform = _Transform.upper;
  bool _caseSensitive = false;

  @override
  void dispose() {
    _text.dispose();
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  // ── statistics ───────────────────────────────────────────────────────────

  int get _characters => _text.text.length;
  int get _charactersNoSpaces =>
      _text.text.replaceAll(RegExp(r'\s'), '').length;

  int get _words {
    final trimmed = _text.text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  int get _lines {
    if (_text.text.isEmpty) return 0;
    return _text.text.split('\n').length;
  }

  int get _sentences {
    final matches = RegExp(r'[.!?…]+(?=\s|$)').allMatches(_text.text);
    final paragraphs = _paragraphs;
    return matches.isEmpty
        ? (paragraphs > 0 ? paragraphs : 0)
        : matches.length;
  }

  int get _paragraphs {
    final blocks = _text.text
        .split(RegExp(r'\n\s*\n'))
        .where((String block) => block.trim().isNotEmpty);
    return blocks.length;
  }

  /// 200 words a minute is the usual planning figure for reading.
  String get _readingTime {
    final words = _words;
    if (words == 0) return '0 min';
    final minutes = words / 200;
    if (minutes < 1) return 'under a minute';
    return '${minutes.ceil()} min';
  }

  // ── actions ──────────────────────────────────────────────────────────────

  void _apply() {
    final input = _text.text;
    final output = switch (_transform) {
      _Transform.upper => input.toUpperCase(),
      _Transform.lower => input.toLowerCase(),
      _Transform.title => _titleCase(input),
      _Transform.sentence => _sentenceCase(input),
      _Transform.reverse => String.fromCharCodes(
          input.runes.toList().reversed,
        ),
      _Transform.sortLines => _sortedLines(input, reverse: false)
          .join('\n'),
      _Transform.sortLinesReverse => _sortedLines(input, reverse: true)
          .join('\n'),
      _Transform.dedupe => _dedupeLines(input).join('\n'),
      _Transform.removeBlank => input
          .split('\n')
          .where((String line) => line.trim().isNotEmpty)
          .join('\n'),
      _Transform.trimEach =>
        input.split('\n').map((String line) => line.trim()).join('\n'),
      _Transform.numberLines => input
          .split('\n')
          .asMap()
          .entries
          .map((MapEntry<int, String> e) => '${e.key + 1}. ${e.value}')
          .join('\n'),
      _Transform.slug => _slug(input),
      _Transform.stripExtraSpaces =>
        input.replaceAll(RegExp(r'[ \t]{2,}'), ' '),
    };
    _text.text = output;
    setState(() {});
  }

  static String _titleCase(String input) {
    // Title case keeps short joining words lower-case unless they are first.
    const minor = <String>{
      'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'in', 'nor', 'of',
      'on', 'or', 'per', 'the', 'to', 'via', 'vs',
    };
    final words = input.toLowerCase().split(RegExp(r'(\s+)'));
    final buffer = StringBuffer();
    var wordIndex = 0;
    for (final chunk in words) {
      if (chunk.trim().isEmpty) {
        buffer.write(chunk);
        continue;
      }
      final isFirst = wordIndex == 0;
      final isLast = !input
          .toLowerCase()
          .substring(input.toLowerCase().indexOf(chunk) + chunk.length)
          .contains(RegExp(r'\S'));
      if (!isFirst && !isLast && minor.contains(chunk)) {
        buffer.write(chunk);
      } else {
        buffer.write(chunk[0].toUpperCase() + chunk.substring(1));
      }
      wordIndex++;
    }
    return buffer.toString();
  }

  static String _sentenceCase(String input) {
    final buffer = StringBuffer();
    var atStart = true;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (atStart && RegExp(r'[A-Za-z]').hasMatch(char)) {
        buffer.write(char.toUpperCase());
        atStart = false;
      } else {
        buffer.write(char.toLowerCase());
      }
      if (char == '.' || char == '!' || char == '?' || char == '\n') {
        atStart = true;
      }
    }
    return buffer.toString();
  }

  static List<String> _sortedLines(String input, {required bool reverse}) {
    final lines = input.split('\n');
    lines.sort((String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase()));
    return reverse ? lines.reversed.toList() : lines;
  }

  static List<String> _dedupeLines(String input) {
    final seen = <String>{};
    final result = <String>[];
    for (final line in input.split('\n')) {
      if (seen.add(line)) result.add(line);
    }
    return result;
  }

  static String _slug(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'[\s_]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  void _replaceAll() {
    final find = _find.text;
    if (find.isEmpty) return;
    // Literal replacement, not a regular expression: a person replacing "$1"
    // means the characters, not a back-reference.
    final source = _caseSensitive ? _text.text : _text.text.toLowerCase();
    final needle = _caseSensitive ? find : find.toLowerCase();
    final buffer = StringBuffer();
    var index = 0;
    while (true) {
      final hit = source.indexOf(needle, index);
      if (hit < 0) {
        buffer.write(_text.text.substring(index));
        break;
      }
      buffer.write(_text.text.substring(index, hit));
      buffer.write(_replace.text);
      index = hit + find.length;
    }
    final replaced = buffer.toString();
    final count =
        find.isEmpty ? 0 : RegExp(RegExp.escape(find), caseSensitive: _caseSensitive)
            .allMatches(_text.text)
            .length;
    _text.text = replaced;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count replacement${count == 1 ? '' : 's'} made.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolShell(
      title: 'Text & documents',
      howTo: 'Paste or type text. The counters update as you type, the buttons '
          'change the case and structure of the whole text, and find and '
          'replace works on literal text without regular-expression surprises.',
      children: <Widget>[
        ToolSection(
          title: 'Your text',
          icon: Icons.article_outlined,
          children: <Widget>[
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 22,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                hintText: 'Paste or type here…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ToolSection(
          title: 'Counts',
          icon: Icons.numbers,
          children: <Widget>[
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: <Widget>[
                _Stat('Words', '$_words'),
                _Stat('Characters', '$_characters'),
                _Stat('Characters without spaces', '$_charactersNoSpaces'),
                _Stat('Lines', '$_lines'),
                _Stat('Sentences', '$_sentences'),
                _Stat('Paragraphs', '$_paragraphs'),
                _Stat('Reading time', _readingTime),
              ],
            ),
            const ToolNote(
              'Reading time assumes 200 words a minute, the usual planning '
              'figure. Word counts treat any run of whitespace as one '
              'separator.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        ToolSection(
          title: 'Change the text',
          icon: Icons.auto_fix_high_outlined,
          children: <Widget>[
            DropdownButtonFormField<_Transform>(
              initialValue: _transform,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Change to apply',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<_Transform>>[
                for (final transform in _Transform.values)
                  DropdownMenuItem<_Transform>(
                    value: transform,
                    child: Text(transform.label),
                  ),
              ],
              onChanged: (_Transform? value) {
                if (value != null) setState(() => _transform = value);
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('Apply to the text above'),
            ),
            const ToolNote(
              '“Title Case” keeps short joining words such as “of” and “the” '
              'lower-case unless they are the first or last word.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        ToolSection(
          title: 'Find and replace',
          icon: Icons.find_replace,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _find,
                    decoration: const InputDecoration(
                      labelText: 'Find',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _replace,
                    decoration: const InputDecoration(
                      labelText: 'Replace with',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Checkbox(
                  value: _caseSensitive,
                  onChanged: (bool? value) =>
                      setState(() => _caseSensitive = value ?? false),
                ),
                const Text('Match case'),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _replaceAll,
                  icon: const Icon(Icons.find_replace),
                  label: const Text('Replace all'),
                ),
              ],
            ),
            const ToolNote(
              'The text you type is replaced exactly as written. A “\$1” in '
              'the replacement box stays as the characters “\$1”.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _text.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy the text'),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _text.clear()),
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
