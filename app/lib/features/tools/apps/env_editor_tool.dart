import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Parses and edits a .env file as a table of keys and values.
///
/// Paste the contents of a .env file. Each non-comment line becomes a row you
/// can edit. The tool re-emits a clean .env file, preserving comments.
class EnvEditorTool extends StatefulWidget {
  const EnvEditorTool({super.key});

  @override
  State<EnvEditorTool> createState() => _EnvEditorToolState();
}

class _EnvEditorToolState extends State<EnvEditorTool> {
  final TextEditingController _input = TextEditingController();
  List<_EnvRow> _rows = <_EnvRow>[];
  String _output = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _parse() {
    final lines = _input.text.split('\n');
    final rows = <_EnvRow>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        rows.add(_EnvRow(comment: trimmed));
        continue;
      }
      final idx = trimmed.indexOf('=');
      if (idx < 0) {
        rows.add(_EnvRow(comment: trimmed));
        continue;
      }
      rows.add(_EnvRow(
        key: trimmed.substring(0, idx).trim(),
        value: trimmed.substring(idx + 1).trim(),
      ));
    }
    setState(() {
      _rows = rows;
      _rebuild();
    });
  }

  void _rebuild() {
    final buf = StringBuffer();
    for (final r in _rows) {
      if (r.comment != null) {
        buf.writeln(r.comment);
      } else {
        buf.writeln('${r.key}=${r.value}');
      }
    }
    _output = buf.toString().trimRight();
  }

  void _update(int i, String key, String value) {
    setState(() {
      _rows[i].key = key;
      _rows[i].value = value;
      _rebuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: '.env editor',
      howTo: 'Paste a .env file. Edit keys and values in the table. The '
          'rebuilt file appears below; copy it when done.',
      children: [
        TextField(
          controller: _input,
          decoration: const InputDecoration(labelText: '.env contents'),
          maxLines: 6,
          onChanged: (_) => _parse(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _rows.length,
            itemBuilder: (context, i) {
              final r = _rows[i];
              if (r.comment != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(r.comment!,
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: r.key,
                      decoration: const InputDecoration(labelText: 'Key'),
                      onChanged: (v) => _update(i, v, r.value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: r.value,
                      decoration: const InputDecoration(labelText: 'Value'),
                      onChanged: (v) => _update(i, r.key, v),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: SelectableText(_output,
                style: const TextStyle(fontFamily: 'monospace')),
          ),
        ),
      ],
    );
  }
}

class _EnvRow {
  _EnvRow({this.key = '', this.value = '', this.comment});
  String key;
  String value;
  String? comment;
}