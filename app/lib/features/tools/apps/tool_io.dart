import 'dart:io';

import 'package:flutter/material.dart';

/// True on platforms where file system tools can do anything useful.
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// The person's home directory, used as the starting point for pickers.
String get homeDirectory {
  final environment = Platform.environment;
  return environment['USERPROFILE'] ??
      environment['HOME'] ??
      Directory.current.path;
}

/// Size in the largest unit that keeps the number readable.
String formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = unit == 0 ? 0 : (value >= 100 ? 0 : 1);
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

/// Ask for a folder. Returns null if the person cancels.
Future<String?> pickDirectory(BuildContext context, {String? start}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PathPicker(
      start: start ?? homeDirectory,
      mode: _PickerMode.directory,
    ),
  );
}

/// Ask for a file. Returns null if the person cancels.
Future<String?> pickFile(BuildContext context, {String? start}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PathPicker(
      start: start ?? homeDirectory,
      mode: _PickerMode.file,
    ),
  );
}

enum _PickerMode { directory, file }

class _PathPicker extends StatefulWidget {
  const _PathPicker({required this.start, required this.mode});

  final String start;
  final _PickerMode mode;

  @override
  State<_PathPicker> createState() => _PathPickerState();
}

class _PathPickerState extends State<_PathPicker> {
  late String _path = widget.start;
  List<FileSystemEntity> _entries = <FileSystemEntity>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      final directory = Directory(_path);
      if (!directory.existsSync()) {
        setState(() => _error = 'That folder does not exist.');
        return;
      }
      final entries = directory.listSync(followLinks: false).where((entity) {
        final name = _name(entity);
        if (name.startsWith('.')) return false;
        if (widget.mode == _PickerMode.directory) {
          return entity is Directory;
        }
        return entity is Directory || entity is File;
      }).toList()
        ..sort((a, b) {
          final aDir = a is Directory ? 0 : 1;
          final bDir = b is Directory ? 0 : 1;
          if (aDir != bDir) return aDir - bDir;
          return _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
        });

      setState(() {
        // A directory with a hundred thousand entries would build a list the
        // person cannot use; show the first thousand and say so.
        _entries = entries.take(1000).toList();
        _error = entries.length > 1000
            ? 'Showing the first 1000 entries of ${entries.length}.'
            : null;
      });
    } on FileSystemException catch (error) {
      setState(() => _error = 'Cannot read this folder: ${error.message}');
    }
  }

  static String _name(FileSystemEntity entity) {
    final parts = entity.path.split(Platform.pathSeparator);
    return parts.isEmpty ? entity.path : parts.last;
  }

  void _enter(String path) {
    setState(() {
      _path = path;
      _error = null;
    });
    _load();
  }

  String? get _parent {
    final directory = Directory(_path);
    final parent = directory.parent.path;
    return parent == _path ? null : parent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.mode == _PickerMode.directory
            ? 'Choose a folder'
            : 'Choose a file',
      ),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Up one level',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: _parent == null ? null : () => _enter(_parent!),
                ),
                Expanded(
                  child: SelectableText(
                    _path,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _entries.length,
                itemBuilder: (BuildContext context, int index) {
                  final entity = _entries[index];
                  final isDirectory = entity is Directory;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isDirectory
                          ? Icons.folder_outlined
                          : Icons.insert_drive_file_outlined,
                      color: isDirectory ? theme.colorScheme.primary : null,
                    ),
                    title: Text(_name(entity)),
                    onTap: () {
                      if (isDirectory) {
                        _enter(entity.path);
                      } else if (widget.mode == _PickerMode.file) {
                        Navigator.of(context).pop(entity.path);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.mode == _PickerMode.directory)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_path),
            child: const Text('Use this folder'),
          ),
      ],
    );
  }
}
