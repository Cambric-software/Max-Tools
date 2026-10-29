import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tool_shell.dart';

/// Formats, validates and minifies JSON.
///
/// Paste a blob of JSON and the tool tells you whether it is valid, where the
/// error is, and shows it pretty-printed. Useful for API responses, config
/// files and log lines.
class JsonFormatterTool extends StatefulWidget {
  const JsonFormatterTool({super.key});

  @override
  State<JsonFormatterTool> createState() => _JsonFormatterToolState();
}

class _JsonFormatterToolState extends State<JsonFormatterTool> {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _output = TextEditingController();
  String? _error;
  bool _pretty = true;

  @override
  void dispose() {
    _input.dispose();
    _output.dispose();
    super.dispose();
  }

  void _run() {
    final raw = _input.text;
    if (raw.trim().isEmpty) {
      setState(() {
        _error = null;
        _output.text = '';
      });
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      setState(() {
        _error = null;
        _output.text = _pretty
            ? const JsonEncoder.withIndent('  ').convert(decoded)
            : jsonEncode(decoded);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _output.text = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'JSON formatter',
      howTo: 'Paste JSON on the left, press Format. Invalid input shows the '
          'parse error. Switch between pretty and minified output.',
      children: [
        TextField(
          controller: _input,
          decoration: const InputDecoration(labelText: 'Input JSON'),
          maxLines: 8,
          onChanged: (_) => _run(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilterChip(
              label: const Text('Pretty'),
              selected: _pretty,
              onSelected: (v) {
                setState(() => _pretty = v);
                _run();
              },
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _run, child: const Text('Format')),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _output.text.isEmpty
                  ? null
                  : () => Clipboard.setData(ClipboardData(text: _output.text)),
              child: const Text('Copy output'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
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