import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tool_io.dart';
import 'tool_shell.dart';

/// Fingerprints text or a file, and checks a fingerprint against a published
/// one.
///
/// This is the tool for the everyday question "did this download arrive
/// intact, and is it the file the publisher meant to send?" — paste the
/// checksum the publisher listed, and the tool says match or no match.
///
/// Hashing is not signing. A match proves the file is identical to the file the
/// checksum was taken from, provided that checksum itself came from a trusted
/// place. A checksum posted on the same page as the download proves very
/// little.
class HashTool extends StatefulWidget {
  /// Create the tool.
  const HashTool({super.key});

  @override
  State<HashTool> createState() => _HashToolState();
}

class _HashToolState extends State<HashTool> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _filePath = TextEditingController();
  final TextEditingController _expected = TextEditingController();

  String? _fileName;
  int? _fileSize;
  Map<String, String> _digests = <String, String>{};
  String? _error;
  bool _busy = false;
  bool _comparing = false;

  @override
  void dispose() {
    _text.dispose();
    _filePath.dispose();
    _expected.dispose();
    super.dispose();
  }

  void _hashText() {
    final bytes = utf8.encode(_text.text);
    setState(() {
      _fileName = null;
      _fileSize = bytes.length;
      _error = null;
      _digests = _digestsOf(bytes);
    });
  }

  Future<void> _pickFile() async {
    final chosen = await pickFile(context, start: homeDirectory);
    if (chosen == null) return;
    await _hashFile(chosen);
  }

  Future<void> _hashFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      setState(() => _error = 'That file does not exist.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _filePath.text = path;
        _fileName = path.split(Platform.pathSeparator).last;
        _fileSize = bytes.length;
        _digests = _digestsOf(bytes);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not read that file: $error';
      });
    }
  }

  static Map<String, String> _digestsOf(List<int> bytes) {
    return <String, String>{
      'SHA-256': sha256.convert(bytes).toString(),
      'SHA-1': sha1.convert(bytes).toString(),
      'SHA-512': sha512.convert(bytes).toString(),
      'MD5': md5.convert(bytes).toString(),
    };
  }

  void _compare() {
    final expected = _expected.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
    if (expected.isEmpty) {
      setState(() => _comparing = false);
      return;
    }
    setState(() {
      _comparing = true;
      _error = null;
    });
  }

  /// Which algorithm the pasted checksum belongs to, judged by its length.
  /// Shown as information, never used to hide a mismatch.
  String? get _matchResult {
    if (!_comparing) return null;
    final expected = _expected.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
    for (final entry in _digests.entries) {
      if (entry.value == expected) return entry.key;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = _matchResult;

    return ToolShell(
      title: 'Hash & checksum',
      howTo: 'Type or paste text, or choose a file, to get its fingerprints. '
          'To verify a download, paste the checksum the publisher listed into '
          'the “Expected checksum” box: a green Match means the file is '
          'byte-for-byte identical, a red mismatch means it is not.',
      children: <Widget>[
        ToolSection(
          title: 'Text',
          icon: Icons.text_fields,
          children: <Widget>[
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              onChanged: (_) => _hashText(),
              decoration: const InputDecoration(
                labelText: 'Text to fingerprint',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ToolSection(
          title: 'File',
          icon: Icons.insert_drive_file_outlined,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _filePath,
                    onSubmitted: _hashFile,
                    decoration: const InputDecoration(
                      labelText: 'File path',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Browse',
                  onPressed: _busy ? null : _pickFile,
                  icon: const Icon(Icons.folder_open_outlined),
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        if (_digests.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          ToolSection(
            title: _fileName == null ? 'Text fingerprints' : 'Fingerprints',
            icon: Icons.fingerprint,
            children: <Widget>[
              if (_fileName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '$_fileName · ${formatBytes(_fileSize ?? 0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final entry in _digests.entries) ...<Widget>[
                Text(entry.key, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                _HashLine(value: entry.value),
                const SizedBox(height: 12),
              ],
              const ToolNote(
                'MD5 and SHA-1 are included because old software still '
                'publishes them. They are no longer safe against a '
                'deliberately crafted collision; prefer SHA-256.',
                warning: true,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        ToolSection(
          title: 'Verify against a published checksum',
          icon: Icons.verified_outlined,
          children: <Widget>[
            TextField(
              controller: _expected,
              onChanged: (_) => _compare(),
              decoration: const InputDecoration(
                labelText: 'Expected checksum',
                hintText: 'Paste the checksum the publisher listed',
                border: OutlineInputBorder(),
              ),
            ),
            if (match != null) ...<Widget>[
              const SizedBox(height: 12),
              if (match.isEmpty)
                Row(
                  children: <Widget>[
                    Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No match. The file or text is not the one the '
                        'checksum was taken from.',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline,
                        color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Match — this is the $match fingerprint of the '
                        'content above.',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
            ],
            const ToolNote(
              'A checksum is only as trustworthy as the page it came from. '
              'Take it from the publisher’s own site, not from an email or a '
              'mirror.',
            ),
          ],
        ),
      ],
    );
  }
}

class _HashLine extends StatelessWidget {
  const _HashLine({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_outlined, size: 17),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
