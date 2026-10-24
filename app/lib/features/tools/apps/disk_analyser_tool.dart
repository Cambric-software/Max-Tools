import 'dart:io';

import 'package:flutter/material.dart';

import 'tool_io.dart';
import 'tool_shell.dart';

/// One immediate child of the analysed folder.
class _Child {
  _Child(this.name, this.isDirectory);

  final String name;
  final bool isDirectory;
  int bytes = 0;
  int files = 0;
}

/// Shows where the space in a folder actually goes.
///
/// The useful question is never "how big is this folder" but "which of these
/// sub-folders is eating the drive". This measures each immediate child and
/// sorts them, so the answer is the first line of the list rather than
/// something to work out.
class DiskAnalyserTool extends StatefulWidget {
  /// Create the tool.
  const DiskAnalyserTool({super.key});

  @override
  State<DiskAnalyserTool> createState() => _DiskAnalyserToolState();
}

class _DiskAnalyserToolState extends State<DiskAnalyserTool> {
  final TextEditingController _path =
      TextEditingController(text: homeDirectory);

  bool _running = false;
  bool _done = false;
  String _activity = '';
  int _totalBytes = 0;
  int _totalFiles = 0;
  int _totalFolders = 0;
  int _unreadable = 0;
  bool _truncated = false;
  List<_Child> _children = <_Child>[];

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final chosen = await pickDirectory(context, start: _path.text.trim());
    if (chosen == null) return;
    setState(() => _path.text = chosen);
  }

  Future<void> _analyse() async {
    final root = Directory(_path.text.trim());
    if (!root.existsSync()) {
      setState(() {
        _done = true;
        _running = false;
        _activity = '';
        _children = <_Child>[];
        _totalBytes = 0;
        _totalFiles = 0;
        _totalFolders = 0;
        _unreadable = 0;
        _truncated = false;
      });
      return;
    }

    setState(() {
      _running = true;
      _done = false;
      _activity = 'Reading…';
      _children = <_Child>[];
      _totalBytes = 0;
      _totalFiles = 0;
      _totalFolders = 0;
      _unreadable = 0;
      _truncated = false;
    });

    final children = <String, _Child>{};
    var totalBytes = 0;
    var totalFiles = 0;
    var totalFolders = 0;
    var unreadable = 0;
    var truncated = false;

    try {
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (!mounted) return;
        if (totalFiles > 400000) {
          truncated = true;
          break;
        }

        final relative = entity.path
            .substring(root.path.length)
            .replaceAll(RegExp(r'^[\\/]+'), '');
        if (relative.isEmpty) continue;
        final segments = relative.split(RegExp(r'[\\/]'));
        final childName = segments.first;
        final isTopFolder = segments.length > 1 || entity is Directory;

        if (entity is Directory) {
          totalFolders++;
          children.putIfAbsent(
            childName,
            () => _Child(childName, true),
          );
          continue;
        }
        if (entity is! File) continue;

        int size;
        try {
          size = entity.statSync().size;
        } on FileSystemException {
          unreadable++;
          continue;
        }

        totalFiles++;
        totalBytes += size;
        final child = children.putIfAbsent(
          childName,
          () => _Child(childName, isTopFolder && segments.length > 1),
        );
        child.bytes += size;
        child.files++;

        if (totalFiles % 500 == 0) {
          setState(() => _activity = 'Reading… $totalFiles files');
        }
      }
    } on FileSystemException catch (error) {
      unreadable++;
      if (mounted) {
        setState(() => _activity = 'Stopped early: ${error.message}');
      }
    }

    if (!mounted) return;
    final ordered = children.values.toList()
      ..sort((a, b) => b.bytes.compareTo(a.bytes));
    setState(() {
      _running = false;
      _done = true;
      _activity = '';
      _children = ordered;
      _totalBytes = totalBytes;
      _totalFiles = totalFiles;
      _totalFolders = totalFolders;
      _unreadable = unreadable;
      _truncated = truncated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolShell(
      title: 'Disk analyser',
      howTo: 'Choose a folder and press Analyse. Every immediate child of that '
          'folder is measured and listed largest first, so the item at the top '
          'is what is filling the drive. Nothing is moved or deleted.',
      maxWidth: 980,
      children: <Widget>[
        ToolSection(
          title: 'Folder to measure',
          icon: Icons.folder_outlined,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _path,
                    decoration: const InputDecoration(
                      labelText: 'Folder path',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Browse',
                  onPressed: _running ? null : _pick,
                  icon: const Icon(Icons.folder_open_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _running ? null : _analyse,
              icon: const Icon(Icons.pie_chart_outline),
              label: const Text('Analyse'),
            ),
          ],
        ),
        if (_running) ...<Widget>[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(_activity),
        ],
        if (_done) ...<Widget>[
          const SizedBox(height: 16),
          ToolSection(
            title: 'Total',
            icon: Icons.straighten,
            children: <Widget>[
              Text(
                formatBytes(_totalBytes),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_totalFiles files in $_totalFolders folders.',
                style: theme.textTheme.bodyMedium,
              ),
              if (_unreadable > 0)
                ToolNote(
                  '$_unreadable item${_unreadable == 1 ? '' : 's'} could not '
                  'be read or measured, so the total is a little low.',
                  warning: true,
                ),
              if (_truncated)
                const ToolNote(
                  'There were more files than this tool will count in one '
                  'pass, so the totals below are partial.',
                  warning: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ToolSection(
            title: 'What is taking the space',
            icon: Icons.stacked_bar_chart,
            children: <Widget>[
              if (_children.isEmpty)
                const Text('This folder has nothing in it.')
              else
                for (final child in _children) ...<Widget>[
                  _ChildRow(child: child, total: _totalBytes),
                  const SizedBox(height: 12),
                ],
              const ToolNote(
                'Only the immediate contents of the chosen folder are '
                'measured. The biggest folder here is where to look next.',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child, required this.total});

  final _Child child;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total <= 0 ? 0.0 : child.bytes / total;
    final percent = (fraction * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              child.isDirectory
                  ? Icons.folder_outlined
                  : Icons.insert_drive_file_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                child.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatBytes(child.bytes),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${percent.toStringAsFixed(percent < 1 ? 1 : 0)}% of the folder'
            '${child.files > 0 ? ' · ${child.files} files' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
