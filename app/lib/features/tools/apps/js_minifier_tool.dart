import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Minifies or beautifies JavaScript by collapsing whitespace and removing
/// comments. A quick tidy, not a full parser.
class JsMinifierTool extends StatefulWidget {
  const JsMinifierTool({super.key});

  @override
  State<JsMinifierTool> createState() => _JsMinifierToolState();
}

class _JsMinifierToolState extends State<JsMinifierTool> {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _output = TextEditingController();
  bool _minify = true;

  @override
  void dispose() {
    _input.dispose();
    _output.dispose();
    super.dispose();
  }

  void _run() {
    final raw = _input.text;
    if (raw.trim().isEmpty) {
      setState(() => _output.text = '');
      return;
    }
    String result;
    if (_minify) {
      var s = raw;
      // Remove line and block comments.
      s = s.replaceAll(RegExp(r'//.*'), '');
      s = s.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      // Collapse whitespace.
      s = s.replaceAll(RegExp(r'\s+'), ' ');
      s = s.replaceAll(RegExp(r'\s*([{}();,=+\-*/])\s*'), r'\1');
      result = s.trim();
    } else {
      // Very light beautify: put each brace on its own line and indent.
      var s = raw.replaceAll(RegExp(r'\s+'), ' ');
      final buf = StringBuffer();
      var indent = 0;
      for (var i = 0; i < s.length; i++) {
        final c = s[i];
        if (c == '{') {
          buf.write('{\n${'  ' * ++indent}');
        } else if (c == '}') {
          indent = indent > 0 ? indent - 1 : 0;
          buf.write('\n${'  ' * indent}}');
        } else if (c == ';') {
          buf.write(';\n${'  ' * indent}');
        } else {
          buf.write(c);
        }
      }
      result = buf.toString().trim();
    }
    setState(() => _output.text = result);
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'JS minifier / beautifier',
      howTo: 'Paste JavaScript, pick minify or beautify, and read the result. '
          'This is a whitespace and comment pass, not a full parser.',
      children: [
        TextField(
          controller: _input,
          decoration: const InputDecoration(labelText: 'Input JavaScript'),
          maxLines: 8,
          onChanged: (_) => _run(),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Minify')),
            ButtonSegment(value: false, label: Text('Beautify')),
          ],
          selected: {_minify},
          onSelectionChanged: (s) {
            setState(() => _minify = s.first);
            _run();
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _output,
            decoration: const InputDecoration(labelText: 'Output'),
            maxLines: null,
            expands: true,
            readOnly: true,
          ),
        ),
      ],
    );
  }
}