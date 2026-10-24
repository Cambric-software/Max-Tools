import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';

import 'tool_io.dart';
import 'tool_shell.dart';

/// The largest archive this tool will hold in memory, in either direction.
const int maxArchiveBytes = 256 * 1024 * 1024;

/// The largest total uncompressed size it will write out. A small zip can
/// expand into a very large tree; this is the guard against that.
const int maxExtractedBytes = 1024 * 1024 * 1024;

/// The most entries it will extract from one archive.
const int maxArchiveEntries = 20000;

/// What an extraction did. A record keeps it sendable from an isolate.
typedef ExtractSummary = ({
  int files,
  int skipped,
  int bytes,
  List<String> refused,
});

/// Zip the files at [paths] into one archive.
///
/// [root] is the folder the relative names are taken from, so the archive keeps
/// its top-level folder instead of dumping loose files.
Future<Uint8List> zipPaths(List<String> paths, String root) async {
  final archive = Archive();
  final prefix = root.endsWith(Platform.pathSeparator)
      ? root
      : '$root${Platform.pathSeparator}';

  for (final path in paths) {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final name = path.startsWith(prefix)
        ? path.substring(prefix.length)
        : file.uri.pathSegments.last;
    archive.addFile(
      ArchiveFile.bytes(name.replaceAll('\\', '/'), bytes),
    );
  }

  return ZipEncoder().encodeBytes(archive);
}

/// Extract [bytes] into [destination].
///
/// Every entry name is checked before anything is written. Absolute paths and
/// `..` segments are refused rather than sanitised, because a name that tries
/// to escape is not a name to guess about.
Future<ExtractSummary> extractZip(
  Uint8List bytes,
  String destination,
) async {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final root = Directory(destination);
  await root.create(recursive: true);

  var files = 0;
  var skipped = 0;
  var written = 0;
  final refused = <String>[];

  for (final entry in archive.files) {
    final name = entry.name;
    if (entry.isSymbolicLink) {
      skipped++;
      refused.add('$name (symbolic link)');
      continue;
    }
    if (entry.isDirectory) continue;
    final relative = _safeRelative(name);
    if (relative == null) {
      skipped++;
      refused.add(name);
      continue;
    }
    if (files >= maxArchiveEntries || written + entry.size > maxExtractedBytes) {
      skipped++;
      refused.add('$name (limit reached)');
      continue;
    }
    final target = File('${root.path}${Platform.pathSeparator}$relative');
    await target.parent.create(recursive: true);
    await target.writeAsBytes(entry.content, flush: false);
    files++;
    written += entry.size;
  }

  return (
    files: files,
    skipped: skipped,
    bytes: written,
    refused: refused,
  );
}

/// A name that stays inside the destination, or null if it does not.
String? _safeRelative(String name) {
  final slashed = name.replaceAll('\\', '/');
  if (slashed.startsWith('/')) return null;
  if (RegExp(r'^[A-Za-z]:').hasMatch(slashed)) return null;
  final parts = <String>[];
  for (final part in slashed.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') return null;
    parts.add(part);
  }
  if (parts.isEmpty) return null;
  return parts.join(Platform.pathSeparator);
}

enum _Mode { create, extract }

/// Zips a folder or file, and extracts zip archives.
class ArchiveTool extends StatefulWidget {
  /// Create the tool.
  const ArchiveTool({super.key});

  @override
  State<ArchiveTool> createState() => _ArchiveToolState();
}

class _ArchiveToolState extends State<ArchiveTool> {
  final TextEditingController _source = TextEditingController();
  final TextEditingController _destination = TextEditingController();

  _Mode _mode = _Mode.create;
  bool _busy = false;
  String? _status;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _source.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final chosen = await pickFile(context, start: _source.text.trim());
    if (chosen == null) return;
    setState(() {
      _source.text = chosen;
      _result = null;
      _error = null;
    });
  }

  Future<void> _pickFolder({required bool destination}) async {
    final chosen = await pickDirectory(
      context,
      start: destination ? _destination.text.trim() : _source.text.trim(),
    );
    if (chosen == null) return;
    setState(() {
      if (destination) {
        _destination.text = chosen;
      } else {
        _source.text = chosen;
      }
      _result = null;
      _error = null;
    });
  }

  Future<void> _start() async {
    final source = _source.text.trim();
    if (source.isEmpty) {
      setState(() => _error = _mode == _Mode.create
          ? 'Choose a file or folder to zip.'
          : 'Choose a .zip file to extract.');
      return;
    }
    final type = FileSystemEntity.typeSync(source, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      setState(() => _error = 'That path does not exist.');
      return;
    }

    setState(() {
      _busy = true;
      _status = _mode == _Mode.create ? 'Reading the files…' : 'Reading the zip…';
      _result = null;
      _error = null;
    });

    try {
      if (_mode == _Mode.create) {
        await _create(source, type);
      } else {
        await _extract(source, type);
      }
    } on FormatException catch (error) {
      _fail('This is not a readable zip file: ${error.message}');
    } on FileSystemException catch (error) {
      _fail('The file system refused the operation: ${error.message}');
    } catch (error) {
      _fail('Something went wrong: $error');
    }
  }

  Future<void> _create(String source, FileSystemEntityType type) async {
    if (type == FileSystemEntityType.directory) {
      final folder = Directory(source);
      final files = folder
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((File file) => file.path)
          .toList();
      if (files.isEmpty) {
        _fail('That folder is empty, so there is nothing to zip.');
        return;
      }
      final total = files.fold<int>(
        0,
        (int sum, String path) => sum + File(path).lengthSync(),
      );
      if (total > maxArchiveBytes) {
        _fail('Those files total ${formatBytes(total)}. The limit is '
            '${formatBytes(maxArchiveBytes)}.');
        return;
      }
      final parent = folder.parent.path;
      final destination = _unique('$source.zip');
      setState(() => _status = 'Compressing ${files.length} files…');
      final bytes = await Isolate.run(() => zipPaths(files, parent));
      await _write(destination, bytes);
      _done(
        'Zipped ${files.length} files from ${formatBytes(total)} into '
        '${formatBytes(bytes.length)}.\n\n$destination',
      );
      return;
    }

    if (type != FileSystemEntityType.file) {
      _fail('That is not a file or folder this tool can zip.');
      return;
    }
    final file = File(source);
    final size = file.lengthSync();
    if (size > maxArchiveBytes) {
      _fail('That file is ${formatBytes(size)}. The limit is '
          '${formatBytes(maxArchiveBytes)}.');
      return;
    }
    final destination = _unique('$source.zip');
    setState(() => _status = 'Compressing…');
    final bytes = await Isolate.run(() => zipPaths(<String>[source], file.parent.path));
    await _write(destination, bytes);
    _done(
      'Zipped ${formatBytes(size)} into ${formatBytes(bytes.length)}.\n\n'
      '$destination',
    );
  }

  Future<void> _extract(String source, FileSystemEntityType type) async {
    if (type != FileSystemEntityType.file) {
      _fail('Choose a .zip file, not a folder.');
      return;
    }
    final file = File(source);
    final size = file.lengthSync();
    if (size > maxArchiveBytes) {
      _fail('That zip is ${formatBytes(size)}. The limit is '
          '${formatBytes(maxArchiveBytes)}.');
      return;
    }

    final chosen = _destination.text.trim();
    final destination = chosen.isEmpty ? _unique(_withoutZip(source)) : chosen;
    setState(() => _status = 'Extracting…');
    final bytes = await file.readAsBytes();
    final summary = await Isolate.run(() => extractZip(bytes, destination));

    final refused = summary.refused.take(5).join('\n');
    final more = summary.refused.length > 5
        ? '\n…and ${summary.refused.length - 5} more.'
        : '';
    _done(
      'Extracted ${summary.files} '
      '${summary.files == 1 ? 'file' : 'files'} '
      '(${formatBytes(summary.bytes)}) into:\n\n$destination'
      '${summary.skipped == 0 ? '' : '\n\nSkipped ${summary.skipped} '
          '${summary.skipped == 1 ? 'entry' : 'entries'} for safety:\n'
          '$refused$more'}',
    );
  }

  static String _withoutZip(String path) =>
      path.toLowerCase().endsWith('.zip')
          ? path.substring(0, path.length - 4)
          : '$path.extracted';

  static String _unique(String path) {
    if (!File(path).existsSync() && !Directory(path).existsSync()) return path;
    for (var attempt = 2; attempt < 1000; attempt++) {
      final candidate = '$path ($attempt)';
      if (!File(candidate).existsSync() && !Directory(candidate).existsSync()) {
        return candidate;
      }
    }
    return '$path (${DateTime.now().millisecondsSinceEpoch})';
  }

  Future<void> _write(String path, List<int> bytes) async {
    final temporary = File('$path.part');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(path);
  }

  void _done(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
      _result = message;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ToolShell(
      title: 'Archive (zip)',
      howTo: 'Zip a file or a whole folder, or extract a zip somewhere you '
          'choose. Folder contents keep their names and structure.',
      children: <Widget>[
        ToolSection(
          title: 'What are you doing?',
          icon: Icons.folder_zip_outlined,
          children: <Widget>[
            SegmentedButton<_Mode>(
              segments: const <ButtonSegment<_Mode>>[
                ButtonSegment<_Mode>(
                  value: _Mode.create,
                  label: Text('Zip'),
                  icon: Icon(Icons.archive_outlined, size: 18),
                ),
                ButtonSegment<_Mode>(
                  value: _Mode.extract,
                  label: Text('Extract'),
                  icon: Icon(Icons.unarchive_outlined, size: 18),
                ),
              ],
              selected: <_Mode>{_mode},
              onSelectionChanged: _busy
                  ? null
                  : (Set<_Mode> selection) => setState(() {
                        _mode = selection.first;
                        _result = null;
                        _error = null;
                      }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _source,
              onChanged: (_) => setState(() {
                _result = null;
                _error = null;
              }),
              decoration: InputDecoration(
                labelText: _mode == _Mode.create
                    ? 'File or folder to zip'
                    : 'Zip file to extract',
                hintText: 'Choose below, or paste a full path.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickFile,
                  icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
                  label: Text(_mode == _Mode.create ? 'Choose file' : 'Choose zip'),
                ),
                if (_mode == _Mode.create)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _pickFolder(destination: false),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Choose folder'),
                  ),
              ],
            ),
            if (_mode == _Mode.extract) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _destination,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Extract into (optional)',
                  hintText: 'Left empty, a folder is created beside the zip.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    _busy ? null : () => _pickFolder(destination: true),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Choose destination'),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: Icon(
                  _mode == _Mode.create
                      ? Icons.archive_outlined
                      : Icons.unarchive_outlined,
                  size: 18,
                ),
                label: Text(
                  _busy
                      ? (_status ?? 'Working…')
                      : _mode == _Mode.create
                          ? 'Create the zip'
                          : 'Extract the zip',
                ),
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
        ToolSection(
          title: 'What this can and cannot do',
          icon: Icons.info_outline,
          children: <Widget>[
            const ToolNote(
              'Zip uses deflate compression. Files that are already compressed '
              '(photos, video, other zips) will barely shrink, and can grow '
              'slightly.',
            ),
            const ToolNote(
              'Extraction refuses absolute paths, drive letters and ".." '
              'segments instead of rewriting them. A zip that tries to escape '
              'the destination is a sign to stop, not a puzzle to solve.',
              warning: true,
            ),
            const ToolNote(
              'Symbolic links inside a zip are skipped, not followed. They can '
              'point anywhere on the disk.',
            ),
            ToolNote(
              'Archives are processed in memory, up to '
              '${formatBytes(maxArchiveBytes)} compressed and '
              '${formatBytes(maxExtractedBytes)} extracted.',
            ),
            const ToolNote(
              'A password-protected zip is not supported. This tool does not '
              'guess or bypass archive passwords.',
            ),
          ],
        ),
      ],
    );
  }
}
