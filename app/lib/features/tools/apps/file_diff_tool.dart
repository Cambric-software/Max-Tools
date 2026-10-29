import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Compares two pieces of text and shows what changed.
///
/// Paste the old version on the left and the new one on the right. Lines that
/// were added, removed or kept are shown with their line numbers, so a review
/// takes seconds instead of minutes.
class FileDiffTool extends StatefulWidget {
  const FileDiffTool({super.key});

  @override
  State<FileDiffTool> createState() => _FileDiffToolState();
}

class _DiffLine {
  _DiffLine(this.kind, this.text, this.leftNo, this.rightNo);
  final String kind; // 'same', 'removed', 'added'
  final String text;
  final int? leftNo;
  final int? rightNo;
}

class _FileDiffToolState extends State<FileDiffTool> {
  final TextEditingController _left = TextEditingController();
  final TextEditingController _right = TextEditingController();
  List<_DiffLine> _diff = <_DiffLine>[];

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  void _run() {
    final a = _left.text.split('\n');
    final b = _right.text.split('\n');
    // Simple line LCS diff.
    final n = a.length, m = b.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        if (a[i] == b[j]) {
          dp[i][j] = 1 + dp[i + 1][j + 1];
        } else {
          dp[i][j] = dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }
    final result = <_DiffLine>[];
    var i = 0, j = 0;
    var li = 1, ri = 1;
    while (i < n || j < m) {
      if (i < n && j < m && a[i] == b[j]) {
        result.add(_DiffLine('same', a[i], li++, ri++));
        i++;
        j++;
      } else if (j < m && (i >= n || dp[i][j + 1] >= dp[i + 1][j])) {
        result.add(_DiffLine('added', b[j], null, ri++));
        j++;
      } else {
        result.add(_DiffLine('removed', a[i], li++, null));
        i++;
      }
    }
    setState(() => _diff = result);
  }

  Color _color(String kind, BuildContext context) {
    switch (kind) {
      case 'added':
        return Colors.green.shade700;
      case 'removed':
        return Colors.red.shade700;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  String _prefix(String kind) {
    switch (kind) {
      case 'added':
        return '+';
      case 'removed':
        return '-';
      default:
        return ' ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'File diff',
      howTo: 'Paste the old version on the left and the new one on the right. '
          'Lines are matched exactly; added and removed lines are coloured.',
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _left,
                  decoration: const InputDecoration(labelText: 'Left (old)'),
                  maxLines: null,
                  expands: true,
                  onChanged: (_) => _run(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _right,
                  decoration: const InputDecoration(labelText: 'Right (new)'),
                  maxLines: null,
                  expands: true,
                  onChanged: (_) => _run(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _diff.length,
              itemBuilder: (context, i) {
                final d = _diff[i];
                return Text(
                  '${_prefix(d.kind)} ${d.leftNo ?? ' '} | ${d.rightNo ?? ' '}  ${d.text}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _color(d.kind, context),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}