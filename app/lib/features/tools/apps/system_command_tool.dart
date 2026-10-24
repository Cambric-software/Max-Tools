import 'dart:io';

import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// A natural-language front door for the file-system actions.
///
/// Type something like "delete a file called 1 in folder 2" and the tool
/// works out the verb and the paths, shows you what it understood, and asks
/// before doing anything destructive. Nothing leaves this machine.
class SystemCommandTool extends StatefulWidget {
  /// Create the tool.
  const SystemCommandTool({super.key});

  @override
  State<SystemCommandTool> createState() => _SystemCommandToolState();
}

class _SystemCommandToolState extends State<SystemCommandTool> {
  final TextEditingController _command = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _preview;
  String? _result;
  _ParsedCommand? _parsed;

  void _parse() {
    final text = _command.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Type a command first.');
      return;
    }
    final parsed = _ParsedCommand.parse(text);
    setState(() {
      _parsed = parsed;
      _preview = parsed.describe();
      _error = parsed.error;
      _result = null;
    });
  }

  Future<void> _run() async {
    final parsed = _parsed;
    if (parsed == null || parsed.error != null) {
      setState(() => _error = 'Nothing to run. Parse the command first.');
      return;
    }
    if (parsed.destructive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(parsed.describe()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Run'),
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
      final result = await parsed.execute();
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'System command',
      howTo: 'Type what you want in plain English, even with typos. The tool '
          'shows what it understood and asks before deleting anything. '
          'Examples: "delete file 1 in folder 2", "list files in C:/data", '
          '"move report.pdf to archive".',
      maxWidth: 760,
      children: <Widget>[
        TextField(
          controller: _command,
          decoration: const InputDecoration(
            labelText: 'Command',
            hintText: 'delete a file called 1 in folder 2',
          ),
          onSubmitted: (_) => _parse(),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed: _busy ? null : _parse,
              icon: const Icon(Icons.search),
              label: const Text('Parse'),
            ),
            const SizedBox(width: 8),
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
          ],
        ),
        if (_preview != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_preview!),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_result != null) ...<Widget>[
          const SizedBox(height: 12),
          SelectableText(_result!),
        ],
      ],
    );
  }
}

class _ParsedCommand {
  _ParsedCommand({
    required this.verb,
    required this.target,
    this.destination,
    this.error,
  });

  final String verb;
  final String target;
  final String? destination;
  final String? error;

  bool get destructive => verb == 'delete' || verb == 'deleteFolder';

  String describe() {
    if (error != null) return error!;
    switch (verb) {
      case 'delete':
        return 'Delete file: $target';
      case 'deleteFolder':
        return 'Delete folder: $target';
      case 'move':
        return 'Move $target -> $destination';
      case 'copy':
        return 'Copy $target -> $destination';
      case 'rename':
        return 'Rename $target -> $destination';
      case 'list':
        return 'List: $target';
      case 'mkdir':
        return 'Create folder: $target';
      case 'open':
        return 'Open: $target';
      default:
        return 'Unknown command';
    }
  }

  static _ParsedCommand parse(String text) {
    final lower = text.toLowerCase();
    String verb;
    if (lower.contains('delete') || lower.contains('remove')) {
      verb = lower.contains('folder') || lower.contains('directory')
          ? 'deleteFolder'
          : 'delete';
    } else if (lower.contains('move')) {
      verb = 'move';
    } else if (lower.contains('copy')) {
      verb = 'copy';
    } else if (lower.contains('rename')) {
      verb = 'rename';
    } else if (lower.contains('list') || lower.contains('show')) {
      verb = 'list';
    } else if (lower.contains('create') || lower.contains('make') || lower.contains('mkdir')) {
      verb = 'mkdir';
    } else if (lower.contains('open')) {
      verb = 'open';
    } else {
      return _ParsedCommand(verb: 'unknown', target: '', error: 'No recognised verb.');
    }

    final quotes = RegExp(r'''["']([^"']+)["']''').allMatches(text).map((m) => m.group(1)!).toList();
    String target;
    String? destination;
    if (quotes.isNotEmpty) {
      target = quotes.first;
      if (quotes.length > 1) destination = quotes[1];
    } else {
      // Fall back to the last two path-like tokens.
      final tokens = text.split(RegExp(r'\s+'));
      final paths = tokens.where((t) => t.contains('/') || t.contains('\\') || t.contains('.')).toList();
      if (paths.isNotEmpty) {
        target = paths.last;
        if (paths.length > 1) destination = paths[paths.length - 2];
      } else {
        // Use the last word as the name.
        target = tokens.last;
      }
    }

    // Handle "called X in folder Y" style.
    final calledMatch = RegExp(r'(?:called|named)\s+(\S+)', caseSensitive: false).firstMatch(text);
    if (calledMatch != null && quotes.isEmpty) {
      target = calledMatch.group(1)!;
    }
    final inFolderMatch = RegExp(r'in\s+(?:folder|directory)\s+(\S+)', caseSensitive: false).firstMatch(text);
    if (inFolderMatch != null && quotes.isEmpty) {
      final folder = inFolderMatch.group(1)!;
      if (!target.contains(Platform.pathSeparator)) {
        target = '$folder${Platform.pathSeparator}$target';
      }
    }

    if (target.isEmpty) {
      return _ParsedCommand(verb: verb, target: '', error: 'Could not find a target.');
    }
    return _ParsedCommand(verb: verb, target: target, destination: destination);
  }

  Future<String> execute() async {
    switch (verb) {
      case 'delete':
        await File(target).delete();
        return 'Deleted file: $target';
      case 'deleteFolder':
        await Directory(target).delete(recursive: true);
        return 'Deleted folder: $target';
      case 'move':
        if (destination == null) throw Exception('No destination.');
        final src = File(target);
        final dst = File(destination!);
        await dst.parent.create(recursive: true);
        await src.rename(dst.path);
        return 'Moved $target -> $destination';
      case 'copy':
        if (destination == null) throw Exception('No destination.');
        final src = File(target);
        final dst = File(destination!);
        await dst.parent.create(recursive: true);
        await src.copy(dst.path);
        return 'Copied $target -> $destination';
      case 'rename':
        if (destination == null) throw Exception('No destination.');
        await File(target).rename(destination!);
        return 'Renamed $target -> $destination';
      case 'list':
        final dir = Directory(target);
        final entries = dir.listSync();
        return entries.map((e) => e.path).join('\n');
      case 'mkdir':
        await Directory(target).create(recursive: true);
        return 'Created folder: $target';
      case 'open':
        await Process.start(target, [], runInShell: true);
        return 'Opened: $target';
      default:
        throw Exception('Unknown command.');
    }
  }
}
