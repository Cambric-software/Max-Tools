import 'dart:core';

import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Tests a regular expression against sample text and shows every match,
/// its capture groups and its span, live as you type.
///
/// Regular expressions are written once and read a hundred times. This tool
/// makes the match visible instead of making you guess.
class RegexTesterTool extends StatefulWidget {
  const RegexTesterTool({super.key});

  @override
  State<RegexTesterTool> createState() => _RegexTesterToolState();
}

class _RegexTesterToolState extends State<RegexTesterTool> {
  final TextEditingController _pattern = TextEditingController();
  final TextEditingController _text = TextEditingController();

  bool _caseInsensitive = false;
  bool _multiline = false;
  bool _dotAll = false;
  String? _error;
  List<RegExpMatch> _matches = <RegExpMatch>[];

  @override
  void dispose() {
    _pattern.dispose();
    _text.dispose();
    super.dispose();
  }

  void _run() {
    final p = _pattern.text;
    if (p.isEmpty) {
      setState(() {
        _error = null;
        _matches = <RegExpMatch>[];
      });
      return;
    }
    try {
      final re = RegExp(p, caseSensitive: !_caseInsensitive, multiLine: _multiline, dotAll: _dotAll);
      setState(() {
        _error = null;
        _matches = re.allMatches(_text.text).toList();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _matches = <RegExpMatch>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'Regex tester',
      howTo: 'Type a pattern and some text. Matches and capture groups update '
          'live. Toggle flags below the pattern.',
      children: [
        TextField(
          controller: _pattern,
          decoration: const InputDecoration(labelText: 'Pattern'),
          onChanged: (_) => _run(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Case-insensitive'),
              selected: _caseInsensitive,
              onSelected: (v) { setState(() => _caseInsensitive = v); _run(); },
            ),
            FilterChip(
              label: const Text('Multiline mode'),
              selected: _multiline,
              onSelected: (v) { setState(() => _multiline = v); _run(); },
            ),
            FilterChip(
              label: const Text('Dot matches newline'),
              selected: _dotAll,
              onSelected: (v) { setState(() => _dotAll = v); _run(); },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          decoration: const InputDecoration(labelText: 'Test text'),
          maxLines: 6,
          onChanged: (_) => _run(),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        Text('Matches: ${_matches.length}',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Expanded(
          child: _matches.isEmpty
              ? const Center(child: Text('No matches.'))
              : ListView.builder(
                  itemCount: _matches.length,
                  itemBuilder: (context, i) {
                    final m = _matches[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Match ${i + 1}: "${m.group(0)}" '
                                'at ${m.start}..${m.end}'),
                            if (m.groupCount > 0) ...[
                              const SizedBox(height: 4),
                              for (var g = 1; g <= m.groupCount; g++)
                                Text('  group $g: ${m.group(g)}'),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}