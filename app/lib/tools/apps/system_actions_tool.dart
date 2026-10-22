import 'dart:io';

import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// A small, honest file-system operator.
///
/// Max Tools is local-first, so the deepest "system action" it can offer
/// without pretending to be an OS is working with the files on this machine:
/// listing, copying, moving, renaming and deleting. Every destructive action
/// asks for confirmation and reports exactly what it did.
class SystemActionsTool extends StatefulWidget {
  /// Create the tool.
  const SystemActionsTool({super.key});

  @override
  State<SystemActionsTool> createState() => _SystemActionsToolState();
}

enum _Action { list, copy, move, rename, deleteFile, deleteFolder }

class _SystemActionsToolState extends State<SystemActionsTool> {
  final TextEditingController _path = TextEditingController();
  final TextEditingController _destination = TextEditingController();

  _Action _action = _Action.list;
  bool _busy = false;
  String? _error;
  String? _result;
  final List<String> _log = <String>[];

  bool get _needsDestination =>
      _action == _Action.copy || _action == _Action.move || _action == _Action.rename;

  Future<void> _run() async {
    final path = _path.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Enter a path first.');
      return;
    }
    if (_needsDestination && _destination.text.trim().isEmpty) {
      setState(() => _error = 'Enter a destination first.');
      return;
    }

    if (_action == _Action.deleteFile || _action == _Action.deleteFolder) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm delete'),
          content: Text('Delete "$path"? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      switch (_action) {
        case _Action.list:
          final entity = FileSystemEntity.typeSync(path);
          if (entity == FileSystemEntityType.directory) {
            final entries = Directory(path).listSync();
            _log.insert(0, 'Listed ${entries.length} entries in $path');
            setState(() => _result = entries.map((e) => e.path).join('\n'));
          } else if (entity == FileSystemEntityType.file) {
            final info = await File(path).stat();
            _log.insert(0, 'File: $path (${info.size} bytes)');
            setState(() => _result = '$path\n${info.size} bytes');
          } else {
            throw FileSystemException('Path not found', path);
          }
          break;
        case _Action.copy:
          final src = File(path);
          final dst = File(_destination.text.trim());
          await dst.parent.create(recursive: true);
          await src.copy(dst.path);
          _log.insert(0, 'Copied $path -> ${dst.path}');
          setState(() => _result = 'Copied to ${dst.path}');
          break;
        case _Action.move:
          final src = File(path);
          final dst = File(_destination.text.trim());
          await dst.parent.create(recursive: true);
          await src.rename(dst.path);
          _log.insert(0, 'Moved $path -> ${dst.path}');
          setState(() => _result = 'Moved to ${dst.path}');
          break;
        case _Action.rename:
          final src = File(path);
          final dst = File(_destination.text.trim());
          await src.rename(dst.path);
          _log.insert(0, 'Renamed $path -> ${dst.path}');
          setState(() => _result = 'Renamed to ${dst.path}');
          break;
        case _Action.deleteFile:
          await File(path).delete();
          _log.insert(0, 'Deleted file $path');
          setState(() => _result = 'Deleted $path');
          break;
        case _Action.deleteFolder:
          await Directory(path).delete(recursive: true);
          _log.insert(0, 'Deleted folder $path');
          setState(() => _result = 'Deleted $path');
          break;
      }
    } catch (e) {
      _log.insert(0, 'Failed: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'System actions',
      howTo: 'Work with files and folders on this machine: list, copy, move, '
          'rename and delete. Destructive actions ask for confirmation. '
          'Nothing runs in the background and nothing leaves your machine.',
      maxWidth: 760,
      children: <Widget>[
        DropdownButtonFormField<_Action>(
          initialValue: _action,
          decoration: const InputDecoration(labelText: 'Action'),
          items: const <DropdownMenuItem<_Action>>[
            DropdownMenuItem(value: _Action.list, child: Text('List / inspect')),
            DropdownMenuItem(value: _Action.copy, child: Text('Copy file')),
            DropdownMenuItem(value: _Action.move, child: Text('Move file')),
            DropdownMenuItem(value: _Action.rename, child: Text('Rename file')),
            DropdownMenuItem(value: _Action.deleteFile, child: Text('Delete file')),
            DropdownMenuItem(value: _Action.deleteFolder, child: Text('Delete folder')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _action = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _path,
          decoration: const InputDecoration(
            labelText: 'Path',
            hintText: r'C:\Users\name\folder\file.txt',
          ),
        ),
        if (_needsDestination) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _destination,
            decoration: const InputDecoration(
              labelText: 'Destination',
              hintText: r'C:\Users\name\other\file.txt',
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(_busy ? 'Working…' : 'Run'),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_result != null) ...<Widget>[
          const SizedBox(height: 12),
          SelectableText(_result!),
        ],
        if (_log.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          const Text('Recent actions'),
          const SizedBox(height: 4),
          for (final entry in _log.take(10)) Text('• $entry'),
        ],
      ],
    );
  }
}
