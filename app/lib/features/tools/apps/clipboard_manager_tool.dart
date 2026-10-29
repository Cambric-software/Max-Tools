import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'tool_shell.dart';

/// Captures, searches and reuses clipboard history.
///
/// The clipboard is the most-used and least-remembered surface on a computer.
/// This tool keeps the last few dozen entries, lets you search them, pin the
/// ones you use every day, and put any of them back on the clipboard with one
/// tap. Nothing leaves the machine.
class ClipboardManagerTool extends StatefulWidget {
  const ClipboardManagerTool({super.key});

  @override
  State<ClipboardManagerTool> createState() => _ClipboardManagerToolState();
}

class _ClipboardEntry {
  _ClipboardEntry({required this.text, required this.capturedAt, this.pinned = false});

  final String text;
  final DateTime capturedAt;
  bool pinned;

  Map<String, dynamic> toJson() => {
        'text': text,
        'capturedAt': capturedAt.toIso8601String(),
        'pinned': pinned,
      };

  factory _ClipboardEntry.fromJson(Map<String, dynamic> json) => _ClipboardEntry(
        text: json['text'] as String? ?? '',
        capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
            DateTime.now(),
        pinned: json['pinned'] as bool? ?? false,
      );
}

class _ClipboardManagerToolState extends State<ClipboardManagerTool> {
  final TextEditingController _search = TextEditingController();
  final List<_ClipboardEntry> _entries = <_ClipboardEntry>[];
  bool _busy = false;
  String? _status;

  static const int _maxEntries = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<File> _storeFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}clipboard_history.json');
  }

  Future<void> _load() async {
    try {
      final file = await _storeFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final list = jsonDecode(raw) as List<dynamic>;
        setState(() {
          _entries
            ..clear()
            ..addAll(list
                .whereType<Map<String, dynamic>>()
                .map(_ClipboardEntry.fromJson));
        });
      }
    } catch (_) {
      // A corrupt history file is not worth failing startup over.
    }
  }

  Future<void> _save() async {
    try {
      final file = await _storeFile();
      await file.writeAsString(
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  Future<void> _capture() async {
    setState(() => _busy = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) {
        setState(() => _status = 'Clipboard is empty or not text.');
        return;
      }
      setState(() {
        _entries.removeWhere((e) => e.text == text);
        _entries.insert(0, _ClipboardEntry(text: text, capturedAt: DateTime.now()));
        if (_entries.length > _maxEntries) {
          _entries.removeRange(_maxEntries, _entries.length);
        }
        _status = 'Captured.';
      });
      await _save();
    } catch (e) {
      setState(() => _status = 'Capture failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _copy(_ClipboardEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.text));
    setState(() => _status = 'Copied to clipboard.');
  }

  void _togglePin(_ClipboardEntry entry) {
    setState(() => entry.pinned = !entry.pinned);
    _save();
  }

  void _remove(_ClipboardEntry entry) {
    setState(() => _entries.remove(entry));
    _save();
  }

  void _clearAll() {
    setState(() {
      _entries.removeWhere((e) => !e.pinned);
      _status = 'Cleared unpinned entries.';
    });
    _save();
  }

  List<_ClipboardEntry> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries
        .where((e) => e.text.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filtered;
    return ToolShell(
      title: 'Clipboard manager',
      howTo: 'Press Capture to store the current clipboard, then search or tap '
          'an entry to copy it back. Pin entries you use every day.',
      children: [
        Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search history',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _capture,
                icon: const Icon(Icons.content_paste_go),
                label: const Text('Capture'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_status != null)
                Expanded(child: Text(_status!, style: Theme.of(context).textTheme.bodySmall)),
              TextButton(
                onPressed: _entries.any((e) => !e.pinned) ? _clearAll : null,
                child: const Text('Clear unpinned'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No entries yet. Press Capture.'))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final e = shown[i];
                      return Card(
                        child: ListTile(
                          leading: Icon(e.pinned ? Icons.push_pin : Icons.content_paste),
                          title: Text(
                            e.text.length > 80 ? '${e.text.substring(0, 80)}…' : e.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(e.capturedAt.toLocal().toString()),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Copy',
                                icon: const Icon(Icons.copy),
                                onPressed: () => _copy(e),
                              ),
                              IconButton(
                                tooltip: e.pinned ? 'Unpin' : 'Pin',
                                icon: Icon(e.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                                onPressed: () => _togglePin(e),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _remove(e),
                              ),
                            ],
                          ),
                          onTap: () => _copy(e),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ],
    );
  }
}