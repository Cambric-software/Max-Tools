import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tool_shell.dart';

/// Generates and inspects UUIDs (versions 1, 4 and 7).
///
/// Generate one or many, copy with one tap, and paste an existing UUID to see
/// its version and variant. No network, no account.
class UuidGeneratorTool extends StatefulWidget {
  const UuidGeneratorTool({super.key});

  @override
  State<UuidGeneratorTool> createState() => _UuidGeneratorToolState();
}

class _UuidGeneratorToolState extends State<UuidGeneratorTool> {
  final TextEditingController _count = TextEditingController(text: '1');
  final TextEditingController _inspect = TextEditingController();
  String _version = 'v4';
  final List<String> _generated = <String>[];
  String? _inspectResult;

  @override
  void dispose() {
    _count.dispose();
    _inspect.dispose();
    super.dispose();
  }

  void _generate() {
    final n = int.tryParse(_count.text.trim()) ?? 1;
    final count = n.clamp(1, 100);
    final rnd = Random.secure();
    final out = <String>[];
    for (var i = 0; i < count; i++) {
      out.add(_makeUuid(_version, rnd));
    }
    setState(() => _generated
      ..clear()
      ..addAll(out));
  }

  String _makeUuid(String version, Random rnd) {
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    if (version == 'v4') {
      bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
      bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    } else if (version == 'v7') {
      final ms = DateTime.now().millisecondsSinceEpoch;
      bytes[0] = (ms >> 40) & 0xff;
      bytes[1] = (ms >> 32) & 0xff;
      bytes[2] = (ms >> 24) & 0xff;
      bytes[3] = (ms >> 16) & 0xff;
      bytes[4] = (ms >> 8) & 0xff;
      bytes[5] = ms & 0xff;
      bytes[6] = (bytes[6] & 0x0f) | 0x70; // version 7
      bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    } else {
      // v1-ish: time-based-ish using random (not spec-perfect, labelled).
      bytes[6] = (bytes[6] & 0x0f) | 0x10;
      bytes[8] = (bytes[8] & 0x3f) | 0x80;
    }
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _inspectUuid() {
    final raw = _inspect.text.trim().toLowerCase();
    if (raw.isEmpty) {
      setState(() => _inspectResult = null);
      return;
    }
    final clean = raw.replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (clean.length != 32) {
      setState(() => _inspectResult = 'Not a 128-bit UUID (expected 32 hex digits).');
      return;
    }
    final versionNibble = clean[12];
    final variantBits = int.parse(clean[16], radix: 16);
    String variant;
    if ((variantBits & 0x8) == 0) {
      variant = 'NCS (reserved)';
    } else if ((variantBits & 0xc) == 0x8) {
      variant = 'RFC 4122';
    } else if ((variantBits & 0xe) == 0xc) {
      variant = 'Microsoft (reserved)';
    } else {
      variant = 'Future (reserved)';
    }
    String version;
    switch (versionNibble) {
      case '1':
        version = '1 (time-based)';
        break;
      case '2':
        version = '2 (DCE security)';
        break;
      case '3':
        version = '3 (name-based, MD5)';
        break;
      case '4':
        version = '4 (random)';
        break;
      case '5':
        version = '5 (name-based, SHA-1)';
        break;
      case '6':
        version = '6 (reordered time)';
        break;
      case '7':
        version = '7 (Unix time)';
        break;
      default:
        version = '$versionNibble (unknown)';
    }
    setState(() => _inspectResult = 'Version: $version\nVariant: $variant');
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'UUID generator',
      howTo: 'Generate one or many UUIDs, or paste a UUID to inspect its '
          'version and variant.',
      children: [
        Row(
          children: [
            DropdownButton<String>(
              value: _version,
              items: const [
                DropdownMenuItem(value: 'v4', child: Text('v4 (random)')),
                DropdownMenuItem(value: 'v7', child: Text('v7 (time)')),
                DropdownMenuItem(value: 'v1', child: Text('v1-ish')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _version = v);
              },
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _count,
                decoration: const InputDecoration(labelText: 'Count'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _generate, child: const Text('Generate')),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _generated.isEmpty
              ? const Center(child: Text('No UUIDs yet.'))
              : ListView.builder(
                  itemCount: _generated.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(_generated[i],
                        style: const TextStyle(fontFamily: 'monospace')),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _generated[i])),
                    ),
                  ),
                ),
        ),
        const Divider(),
        TextField(
          controller: _inspect,
          decoration: const InputDecoration(labelText: 'Inspect a UUID'),
          onChanged: (_) => _inspectUuid(),
        ),
        if (_inspectResult != null) ...[
          const SizedBox(height: 4),
          Text(_inspectResult!),
        ],
      ],
    );
  }
}