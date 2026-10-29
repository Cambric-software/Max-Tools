import 'dart:convert';

import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Encodes and decodes text in the formats developers meet every day.
///
/// Base64, hexadecimal, percent-encoded (URL) and HTML entities, in both
/// directions. Nothing is sent anywhere; the conversion happens on the device.
class EncodingConverterTool extends StatefulWidget {
  const EncodingConverterTool({super.key});

  @override
  State<EncodingConverterTool> createState() => _EncodingConverterToolState();
}

class _EncodingConverterToolState extends State<EncodingConverterTool> {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _output = TextEditingController();
  String _mode = 'base64';
  bool _encode = true;
  String? _error;

  static const List<String> _modes = <String>[
    'base64', 'hex', 'url', 'html',
  ];

  @override
  void dispose() {
    _input.dispose();
    _output.dispose();
    super.dispose();
  }

  void _run() {
    final raw = _input.text;
    if (raw.isEmpty) {
      setState(() {
        _error = null;
        _output.text = '';
      });
      return;
    }
    try {
      String result;
      if (_encode) {
        switch (_mode) {
          case 'base64':
            result = base64Encode(utf8.encode(raw));
            break;
          case 'hex':
            result = utf8.encode(raw).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            break;
          case 'url':
            result = Uri.encodeComponent(raw);
            break;
          case 'html':
            result = raw
                .replaceAll('&', '&amp;')
                .replaceAll('<', '&lt;')
                .replaceAll('>', '&gt;')
                .replaceAll('"', '&quot;')
                .replaceAll("'", '&#39;');
            break;
          default:
            result = raw;
        }
      } else {
        switch (_mode) {
          case 'base64':
            result = utf8.decode(base64Decode(raw));
            break;
          case 'hex':
            final bytes = <int>[];
            for (var i = 0; i + 1 < raw.length; i += 2) {
              bytes.add(int.parse(raw.substring(i, i + 2), radix: 16));
            }
            result = utf8.decode(bytes);
            break;
          case 'url':
            result = Uri.decodeComponent(raw);
            break;
          case 'html':
            result = raw
                .replaceAll('&amp;', '&')
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>')
                .replaceAll('&quot;', '"')
                .replaceAll('&#39;', "'");
            break;
          default:
            result = raw;
        }
      }
      setState(() {
        _error = null;
        _output.text = result;
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
      title: 'Encoding converter',
      howTo: 'Choose a format and a direction, paste text, and read the '
          'converted result. Nothing leaves the device.',
      children: [
        DropdownButtonFormField<String>(
          initialValue: _mode,
          decoration: const InputDecoration(labelText: 'Format'),
          items: _modes
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _mode = v);
            _run();
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Encode')),
            ButtonSegment(value: false, label: Text('Decode')),
          ],
          selected: {_encode},
          onSelectionChanged: (s) {
            setState(() => _encode = s.first);
            _run();
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _input,
          decoration: const InputDecoration(labelText: 'Input'),
          maxLines: 6,
          onChanged: (_) => _run(),
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