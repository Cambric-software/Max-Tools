import 'dart:convert';

import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Decodes a JSON Web Token and shows its header, payload and signature,
/// including expiry and issued-at in human-readable form.
///
/// A JWT is three Base64Url parts separated by dots. This tool reads them
/// without verifying the signature, so it is for inspection, not trust.
class JwtInspectorTool extends StatefulWidget {
  const JwtInspectorTool({super.key});

  @override
  State<JwtInspectorTool> createState() => _JwtInspectorToolState();
}

class _JwtInspectorToolState extends State<JwtInspectorTool> {
  final TextEditingController _input = TextEditingController();
  String? _error;
  Map<String, dynamic>? _header;
  Map<String, dynamic>? _payload;
  String? _signature;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _run() {
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _error = null;
        _header = null;
        _payload = null;
        _signature = null;
      });
      return;
    }
    final parts = raw.split('.');
    if (parts.length != 3) {
      setState(() {
        _error = 'A JWT has three parts separated by dots.';
        _header = null;
        _payload = null;
        _signature = null;
      });
      return;
    }
    try {
      final header = jsonDecode(_b64UrlDecode(parts[0])) as Map<String, dynamic>;
      final payload = jsonDecode(_b64UrlDecode(parts[1])) as Map<String, dynamic>;
      setState(() {
        _error = null;
        _header = header;
        _payload = payload;
        _signature = parts[2];
      });
    } catch (e) {
      setState(() {
        _error = 'Could not decode: $e';
        _header = null;
        _payload = null;
        _signature = null;
      });
    }
  }

  String _b64UrlDecode(String input) {
    var s = input.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    return utf8.decode(base64Decode(s));
  }

  String _formatClaim(dynamic v) {
    if (v is int) {
      // Heuristic: treat large ints as epoch seconds.
      if (v > 1000000000 && v < 10000000000) {
        final dt = DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true);
        return '$v (${dt.toLocal()})';
      }
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'JWT inspector',
      howTo: 'Paste a JWT. The header, payload and signature are shown. '
          'Expiry and issued-at are converted to local time. The signature is '
          'not verified.',
      children: [
        TextField(
          controller: _input,
          decoration: const InputDecoration(labelText: 'JWT'),
          maxLines: 4,
          onChanged: (_) => _run(),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_header != null) ...[
          Text('Header', style: Theme.of(context).textTheme.titleSmall),
          ..._header!.entries.map((e) => Text('  ${e.key}: ${_formatClaim(e.value)}')),
          const SizedBox(height: 8),
          Text('Payload', style: Theme.of(context).textTheme.titleSmall),
          ..._payload!.entries.map((e) => Text('  ${e.key}: ${_formatClaim(e.value)}')),
          const SizedBox(height: 8),
          Text('Signature (not verified):',
              style: Theme.of(context).textTheme.titleSmall),
          Text('  $_signature', style: const TextStyle(fontFamily: 'monospace')),
        ],
      ],
    );
  }
}