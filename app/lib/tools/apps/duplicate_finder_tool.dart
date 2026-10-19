import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'tool_io.dart';
import 'tool_shell.dart';

/// A set of files that are byte-for-byte identical.
class _DupGroup {
  _DupGroup(this.bytes, this.paths);

  final int bytes;
  final List<String> paths;

  int get wasted => bytes * (paths.length - 1);
}

/// Finds files that are copied more than once.
///
/// Files are grouped by size first, because two files can only be identical if
/// they are the same length — that throws away almost everything before a
/// single byte is read. Whatever is left in a group of two or more is then
/// hashed and compared properly, so a match here is a real match, not a
/// filename guess.
///
/// **This tool never deletes anything.** It shows you exactly which copies
/// exist and lets you decide, because only you know which copy you want to
/// keep.
class DuplicateFinderTool extends StatefulWidget {
  /// Create the tool.
  const DuplicateFinderTool({super.key});

  @override
  State<DuplicateFinderTool> createState() => _DuplicateFinderToolState();
}

class _DuplicateFinderToolState extends State<DuplicateFinderTool> {
  static const int _maxFiles = 200000;
  static const int _maxHashBytes = 256 * 1024 * 1024;

  static const Set<String> _skipFolders = <String>{
    '.git', '.dart_tool', '.gradle', '.idea', '.vscode', 'node_modules',
    'build', 'AppData', 'Windows', 'System Volume Information',
    r'$Recycle.Bin', 'Program Files', 'Program Files (x86)',
  };

  final TextEditingController _path =
      TextEditingController(text: homeDirectory);
  final TextEditingController _minSize =
      TextEditingController(text: '1024');

  bool _skipNoise = true;
  bool _running = false;
  bool _done = false;
  String _activity = '';
  int _scanned = 0;
  int _tooBigToCompare = 0;
  bool _truncated = false;
  List<_DupGroup> _groups = <_DupGroup>[];

  @override
  void dispose() {
    _path.dispose();
    _minSize.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final chosen = await pickDirectory(context, start: _path.text.trim());
    if (chosen == null) return;
    setState(() => _path.text = chosen);
  }

  Future<void> _find() async {
    final root = Directory(_path.text.trim());
    final minimum = int.tryParse(_minSize.text.trim()) ?? 1024;

    if (!root.existsSync()) {
      setState(() {
        _done = true;
        _running = false;
        _activity = '';
        _groups = <_DupGroup>[];
        _scanned = 0;
        _tooBigToCompare = 0;
        _truncated = false;
      });
      return;
    }

    setState(() {
      _running = true;
      _done = false;
      _activity = 'Reading file sizes…';
      _groups = <_DupGroup>[];
      _scanned = 0;
      _tooBigToCompare = 0;
      _truncated = false;
    });

    // 1. Group by size. Two files of different length cannot be identical.
    final bySize = <int, List<File>>{};
    var scanned = 0;
    var truncated = false;

    try {
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (!mounted) return;
        if (scanned >= _maxFiles) {
          truncated = true;
          break;
        }
        if (entity is! File) continue;

        final segments = entity.path.split(RegExp(r'[\\/]'));
        final name = segments.last;
        if (_skipNoise) {
          if (name.startsWith('.')) continue;
          if (segments.any(_skipFolders.contains)) continue;
        }

        int size;
        try {
          size = entity.statSync().size;
        } on FileSystemException {
          continue;
        }
        if (size < minimum) continue;

        scanned++;
        bySize.putIfAbsent(size, () => <File>[]).add(entity);
        if (scanned % 500 == 0) {
          setState(() => _activity = 'Reading sizes… $scanned files');
        }
      }
    } on FileSystemException catch (error) {
      if (mounted) setState(() => _activity = 'Stopped early: ${error.message}');
    }

    // 2. Hash only the groups that could contain a duplicate.
    final candidates = bySize.entries
        .where((MapEntry<int, List<File>> entry) => entry.value.length > 1)
        .toList();
    final groups = <_DupGroup>[];
    var tooBig = 0;
    var compared = 0;
    var hashedBytes = 0;

    for (final entry in candidates) {
      if (!mounted) return;
      if (entry.key > _maxHashBytes) {
        tooBig += entry.value.length;
        continue;
      }
      final byHash = <String, List<String>>{};
      for (final file in entry.value) {
        try {
          final bytes = await file.readAsBytes();
          final digest = sha256.convert(bytes).toString();
          byHash.putIfAbsent(digest, () => <String>[]).add(file.path);
        } on FileSystemException {
          // Unreadable file: it cannot be reported as a duplicate.
        }
      }
      for (final paths in byHash.values) {
        if (paths.length > 1) {
          groups.add(_DupGroup(entry.key, paths..sort()));
        }
      }
      compared++;
      hashedBytes += entry.key * entry.value.length;
      if (mounted && compared % 25 == 0) {
        setState(
          () => _activity =
              'Comparing… ${formatBytes(hashedBytes)} read so far',
        );
      }
    }

    groups.sort((a, b) => b.wasted.compareTo(a.wasted));

    if (!mounted) return;
    setState(() {
      _running = false;
      _done = true;
      _activity = '';
      _groups = groups;
      _scanned = scanned;
      _tooBigToCompare = tooBig;
      _truncated = truncated;
    });
  }

  int get _wasted =>
      _groups.fold<int>(0, (int sum, _DupGroup g) => sum + g.wasted);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolShell(
      title: 'Duplicate finder',
      howTo: 'Choose a folder and press Find duplicates. Files with identical '
          'contents are grouped so you can see every copy at once. Nothing is '
          'ever deleted by this tool: it shows you what is there and leaves the '
          'decision to you.',
      maxWidth: 980,
      children: <Widget>[
        ToolSection(
          title: 'Where to look',
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
            Row(
              children: <Widget>[
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: _minSize,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Smallest file (bytes)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _skipNoise,
                    onChanged: (bool value) =>
                        setState(() => _skipNoise = value),
                    title: const Text('Skip system folders'),
                    subtitle: const Text(
                      'Ignores hidden files and folders such as .git, '
                      'node_modules and Windows.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _running ? null : _find,
              icon: const Icon(Icons.content_copy_outlined),
              label: const Text('Find duplicates'),
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
            title: 'Result',
            icon: Icons.fact_check_outlined,
            children: <Widget>[
              Text(
                _groups.isEmpty
                    ? 'No duplicates found among $_scanned files.'
                    : '${_groups.length} group'
                        '${_groups.length == 1 ? '' : 's'} of identical files, '
                        'wasting ${formatBytes(_wasted)}.',
                style: theme.textTheme.titleMedium,
              ),
              if (_tooBigToCompare > 0)
                ToolNote(
                  '$_tooBigToCompare very large file'
                  '${_tooBigToCompare == 1 ? '' : 's'} were not compared: '
                  'hashing files over ${formatBytes(_maxHashBytes)} in one go '
                  'would use too much memory.',
                  warning: true,
                ),
              if (_truncated)
                const ToolNote(
                  'There were more files than this tool will examine in one '
                  'pass, so the result is partial.',
                  warning: true,
                ),
            ],
          ),
          if (_groups.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            for (final group in _groups) ...<Widget>[
              ToolSection(
                title: '${group.paths.length} identical copies',
                icon: Icons.file_copy_outlined,
                trailing: Text(
                  'wastes ${formatBytes(group.wasted)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                children: <Widget>[
                  Text(
                    'Each is ${formatBytes(group.bytes)}. They are the same '
                    'file, byte for byte.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final path in group.paths)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(
                        path,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const ToolNote(
              'Keep the copy you want and remove the rest yourself, in your '
              'file manager. If you are not sure two files are the same, open '
              'them both before removing anything — identical contents do not '
              'always mean the same thing to you.',
              warning: true,
            ),
          ],
        ],
      ],
    );
  }
}
