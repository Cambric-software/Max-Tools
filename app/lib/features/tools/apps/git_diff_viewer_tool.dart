import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Reads a unified diff and summarises it.
///
/// Paste the output of `git diff` or a `.patch` file. The tool counts added
/// and removed lines per file and shows the changed hunks with colour.
class GitDiffViewerTool extends StatefulWidget {
  const GitDiffViewerTool({super.key});

  @override
  State<GitDiffViewerTool> createState() => _GitDiffViewerToolState();
}

class _GitDiffViewerToolState extends State<GitDiffViewerTool> {
  final TextEditingController _input = TextEditingController();
  final List<_FileDiff> _files = <_FileDiff>[];
  int _added = 0, _removed = 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _run() {
    final lines = _input.text.split('\n');
    final files = <_FileDiff>[];
    _FileDiff? current;
    var added = 0, removed = 0;
    for (final line in lines) {
      if (line.startsWith('diff --git') || line.startsWith('--- a/') || line.startsWith('+++ b/')) {
        // new file header
        if (line.startsWith('+++ b/')) {
          current = _FileDiff(line.substring(6));
          files.add(current);
        }
        continue;
      }
      if (current == null) continue;
      if (line.startsWith('+') && !line.startsWith('+++')) {
        current.lines.add(_DiffLine('+', line.substring(1)));
        added++;
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        current.lines.add(_DiffLine('-', line.substring(1)));
        removed++;
      } else if (line.startsWith('@@')) {
        current.lines.add(_DiffLine('hunk', line));
      } else if (line.startsWith(' ')) {
        current.lines.add(_DiffLine('ctx', line.substring(1)));
      }
    }
    setState(() {
      _files
        ..clear()
        ..addAll(files);
      _added = added;
      _removed = removed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'Git diff viewer',
      howTo: 'Paste a unified diff (git diff or a .patch). Added and removed '
          'lines are coloured; a summary counts them.',
      children: [
        TextField(
          controller: _input,
          decoration: const InputDecoration(labelText: 'Unified diff'),
          maxLines: 8,
          onChanged: (_) => _run(),
        ),
        const SizedBox(height: 8),
        Text('Files: ${_files.length}  +$_added  -$_removed',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Expanded(
          child: _files.isEmpty
              ? const Center(child: Text('Paste a diff.'))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, i) {
                    final f = _files[i];
                    return Card(
                      child: ExpansionTile(
                        title: Text(f.name),
                        children: f.lines.map((l) {
                          Color? c;
                          if (l.kind == '+') c = Colors.green.shade700;
                          if (l.kind == '-') c = Colors.red.shade700;
                          return Text(
                            '${l.kind == 'hunk' ? '' : l.kind} ${l.text}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: c,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FileDiff {
  _FileDiff(this.name);
  final String name;
  final List<_DiffLine> lines = <_DiffLine>[];
}

class _DiffLine {
  _DiffLine(this.kind, this.text);
  final String kind;
  final String text;
}