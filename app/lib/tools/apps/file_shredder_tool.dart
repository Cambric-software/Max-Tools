import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'tool_io.dart';
import 'tool_shell.dart';

/// Overwrite [file] with random bytes, rename it, then delete it.
///
/// Kept as a free function so it can be tested directly against a temporary
/// file without driving the widget's asynchronous file reads through the fake
/// clock of a widget test.
Future<void> shredFile(
  File file, {
  int passes = 3,
  void Function(int pass, int total)? onPass,
}) async {
  final size = await file.length();
  final random = Random.secure();
  final chunk = Uint8List(64 * 1024);

  final handle = await file.open(mode: FileMode.write);
  try {
    for (var pass = 1; pass <= passes; pass++) {
      onPass?.call(pass, passes);
      await handle.setPosition(0);
      var remaining = size;
      while (remaining > 0) {
        final length = min(chunk.length, remaining);
        for (var index = 0; index < length; index++) {
          chunk[index] = random.nextInt(256);
        }
        await handle.writeFrom(chunk, 0, length);
        remaining -= length;
      }
      await handle.flush();
    }
  } finally {
    await handle.close();
  }

  // Renaming first means the original name is gone even if the delete is
  // interrupted, and it defeats recovery tools that look up files by name.
  var target = file;
  try {
    final folder = file.parent.path;
    final randomName =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}.tmp';
    target = await file.rename('$folder${Platform.pathSeparator}$randomName');
  } on FileSystemException {
    // Renaming is best-effort; the overwrite already happened.
  }
  await target.delete();
}

/// Overwrites a file before deleting it, and is honest about the limits.
///
/// The destructive part is deliberately slow to reach: the person has to pick
/// the file, read what will happen, and type DELETE. The screen never claims
/// the file is unrecoverable, because on flash storage and copy-on-write
/// filesystems it may not be.
class FileShredderTool extends StatefulWidget {
  /// Create the tool.
  const FileShredderTool({super.key});

  @override
  State<FileShredderTool> createState() => _FileShredderToolState();
}

class _FileShredderToolState extends State<FileShredderTool> {
  final TextEditingController _path = TextEditingController();

  int _passes = 3;
  bool _busy = false;
  String? _status;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final chosen = await pickFile(context, start: _path.text.trim());
    if (chosen == null) return;
    setState(() {
      _path.text = chosen;
      _result = null;
      _error = null;
    });
  }

  Future<void> _start() async {
    final path = _path.text.trim();
    if (path.isEmpty) {
      _showMessage('Choose a file first.');
      return;
    }

    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      setState(() => _error = 'That file does not exist.');
      return;
    }
    if (type == FileSystemEntityType.directory) {
      setState(() => _error = 'That is a folder. This tool shreds one file '
          'at a time.');
      return;
    }
    if (type == FileSystemEntityType.link) {
      setState(() => _error = 'That is a shortcut or symbolic link. Shredding '
          'the link would leave the real file untouched, so this tool '
          'refuses it.');
      return;
    }

    final file = File(path);
    final int size;
    try {
      size = await file.length();
    } on FileSystemException catch (error) {
      setState(() => _error = 'Cannot read that file: ${error.message}');
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmShred(path: path, size: size, passes: _passes),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _result = null;
      _error = null;
      _status = 'Preparing…';
    });

    try {
      await shredFile(
        file,
        passes: _passes,
        onPass: (int pass, int total) {
          if (mounted) {
            setState(() => _status = 'Pass $pass of $total…');
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _result = 'Overwrote $size ${size == 1 ? 'byte' : 'bytes'} '
            '$_passes ${_passes == 1 ? 'time' : 'times'}, renamed the file and '
            'deleted it.\n\n$path';
      });
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = 'The file was overwritten but could not be removed: '
            '${error.message}. Delete it yourself in your file manager.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = 'The file could not be shredded: $error';
      });
    } finally {
      if (mounted && _busy) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolShell(
      title: 'File shredder',
      howTo: 'Choose one file, decide how many times to overwrite it, and type '
          'DELETE to confirm. Read the limits below before using it on a '
          'modern drive.',
      children: <Widget>[
        ToolSection(
          title: 'Which file?',
          icon: Icons.insert_drive_file_outlined,
          children: <Widget>[
            TextField(
              controller: _path,
              onChanged: (_) => setState(() {
                _error = null;
                _result = null;
              }),
              decoration: const InputDecoration(
                labelText: 'File path',
                hintText: 'Choose a file, or paste its full path.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Choose file'),
                ),
                DropdownButton<int>(
                  value: _passes,
                  onChanged: _busy
                      ? null
                      : (int? value) {
                          if (value != null) setState(() => _passes = value);
                        },
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem<int>(value: 1, child: Text('1 pass')),
                    DropdownMenuItem<int>(value: 3, child: Text('3 passes')),
                    DropdownMenuItem<int>(value: 7, child: Text('7 passes')),
                  ],
                ),
              ],
            ),
          ],
        ),
        ToolSection(
          title: 'Overwrite and delete',
          icon: Icons.delete_forever,
          children: <Widget>[
            if (_busy) ...<Widget>[
              Row(
                children: <Widget>[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_status ?? 'Working…')),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: Text(_busy ? 'Shredding…' : 'Shred the file'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.check_circle_outline,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _result!,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const ToolSection(
          title: 'What this can and cannot do',
          icon: Icons.info_outline,
          children: <Widget>[
            ToolNote(
              'This overwrites the file through the operating system, then '
              'deletes it. It cannot be undone.',
              warning: true,
            ),
            ToolNote(
              'On a solid-state drive, a USB stick or an SD card, the '
              'controller may keep the old blocks and write the new data '
              'somewhere else. Overwriting is not a guaranteed erase there. '
              'Full-disk encryption is the reliable protection.',
            ),
            ToolNote(
              'On copy-on-write filesystems (APFS, Btrfs, ZFS) and on '
              'cloud-synced folders, snapshots, backups and sync history may '
              'hold another copy. Remove the file from those services too.',
            ),
            ToolNote(
              'A file that is open in another program may be overwritten but '
              'not deleted. Close it first.',
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmShred extends StatefulWidget {
  const _ConfirmShred({
    required this.path,
    required this.size,
    required this.passes,
  });

  final String path;
  final int size;
  final int passes;

  @override
  State<_ConfirmShred> createState() => _ConfirmShredState();
}

class _ConfirmShredState extends State<_ConfirmShred> {
  final TextEditingController _word = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  bool get _matches => _word.text.trim().toUpperCase() == 'DELETE';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Shred this file?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.path,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.size} ${widget.size == 1 ? 'byte' : 'bytes'} · '
              '${widget.passes} overwrite ${widget.passes == 1 ? 'pass' : 'passes'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'This cannot be undone. Type DELETE to confirm.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _word,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Shred file'),
        ),
      ],
    );
  }
}
