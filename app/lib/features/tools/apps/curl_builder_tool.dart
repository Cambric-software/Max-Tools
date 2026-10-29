import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Builds a curl command from its parts, and parses one back into parts.
///
/// Type method, URL, headers and body to get a ready-to-paste curl command.
/// Paste a curl command to see its parts. Nothing is executed.
class CurlBuilderTool extends StatefulWidget {
  const CurlBuilderTool({super.key});

  @override
  State<CurlBuilderTool> createState() => _CurlBuilderToolState();
}

class _CurlBuilderToolState extends State<CurlBuilderTool> {
  final TextEditingController _method = TextEditingController(text: 'GET');
  final TextEditingController _url = TextEditingController();
  final TextEditingController _headers = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _parse = TextEditingController();
  String _output = '';

  @override
  void dispose() {
    _method.dispose();
    _url.dispose();
    _headers.dispose();
    _body.dispose();
    _parse.dispose();
    super.dispose();
  }

  void _build() {
    final buf = StringBuffer('curl -X ${_method.text.trim().toUpperCase()}');
    final url = _url.text.trim();
    if (url.isNotEmpty) buf.write(" '$url'");
    for (final line in _headers.text.split('\n')) {
      final h = line.trim();
      if (h.isNotEmpty) {
        buf.write(" \\\n  -H '$h'");
      }
    }
    final body = _body.text.trim();
    if (body.isNotEmpty) buf.write(" \\\n  -d '$body'");
    setState(() => _output = buf.toString());
  }

  void _parseCurl() {
    final raw = _parse.text.trim();
    if (raw.isEmpty) {
      setState(() => _output = '');
      return;
    }
    final methodMatch = RegExp(r'-X\s+(\w+)').firstMatch(raw);
    final urlMatch = RegExp(r"'(https?://[^']+)'").firstMatch(raw);
    final headers = RegExp(r"-H\s+'([^']+)'").allMatches(raw).map((m) => m.group(1)!).toList();
    final bodyMatch = RegExp(r"-d\s+'([^']*)'").firstMatch(raw);
    final buf = StringBuffer();
    buf.writeln('Method: ${methodMatch?.group(1) ?? 'GET'}');
    buf.writeln('URL: ${urlMatch?.group(1) ?? '(not found)'}');
    buf.writeln('Headers:');
    for (final h in headers) {
      buf.writeln('  $h');
    }
    if (headers.isEmpty) buf.writeln('  (none)');
    buf.writeln('Body: ${bodyMatch?.group(1) ?? '(none)'}');
    setState(() => _output = buf.toString().trimRight());
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'cURL builder',
      howTo: 'Fill the fields to build a curl command, or paste a curl '
          'command below to parse it back into parts.',
      children: [
        TextField(
          controller: _method,
          decoration: const InputDecoration(labelText: 'Method'),
          onChanged: (_) => _build(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          decoration: const InputDecoration(labelText: 'URL'),
          onChanged: (_) => _build(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _headers,
          decoration: const InputDecoration(
              labelText: 'Headers (one per line)'),
          maxLines: 3,
          onChanged: (_) => _build(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _body,
          decoration: const InputDecoration(labelText: 'Body'),
          maxLines: 3,
          onChanged: (_) => _build(),
        ),
        const SizedBox(height: 8),
        const Divider(),
        TextField(
          controller: _parse,
          decoration: const InputDecoration(labelText: 'Paste a curl command to parse'),
          maxLines: 4,
          onChanged: (_) => _parseCurl(),
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