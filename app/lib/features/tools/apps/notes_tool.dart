import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_shell.dart';

/// A plain notes tool: write, search, pin, edit and delete.
///
/// Notes are stored on this device in plain text. The screen says so, because
/// a notes tool that looks like a vault without being one is worse than no
/// notes tool at all. It is deliberately not called a vault and it refuses to
/// imply encryption it does not have.
class NotesTool extends StatefulWidget {
  /// Create the tool.
  const NotesTool({super.key});

  @override
  State<NotesTool> createState() => _NotesToolState();
}

class _NotesToolState extends State<NotesTool> {
  static const String _storageKey = 'max_tools.notes.v1';

  final TextEditingController _search = TextEditingController();
  final List<_Note> _notes = <_Note>[];

  bool _loaded = false;

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

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _notes.addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(_Note.fromJson)
                .where((_Note note) => note.id.isNotEmpty),
          );
        }
      }
    } catch (_) {
      // Corrupt storage starts empty rather than blocking the tool.
    }
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_notes.map((_Note note) => note.toJson()).toList()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the note to this device.')),
      );
    }
  }

  List<_Note> get _visible {
    final query = _search.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? _notes
        : _notes
            .where((_Note note) =>
                note.title.toLowerCase().contains(query) ||
                note.body.toLowerCase().contains(query))
            .toList();
    matches.sort((_Note a, _Note b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.modified.compareTo(a.modified);
    });
    return matches;
  }

  Future<void> _create() async {
    final draft = await showDialog<_Note>(
      context: context,
      builder: (_) => const _NoteEditor(),
    );
    if (draft == null) return;
    setState(() {
      _notes.add(draft);
    });
    await _save();
  }

  Future<void> _edit(_Note note) async {
    final draft = await showDialog<_Note>(
      context: context,
      builder: (_) => _NoteEditor(note: note),
    );
    if (draft == null) return;
    setState(() {
      final index = _notes.indexWhere((_Note item) => item.id == note.id);
      if (index >= 0) _notes[index] = draft;
    });
    await _save();
  }

  Future<void> _togglePin(_Note note) async {
    setState(() {
      final index = _notes.indexWhere((_Note item) => item.id == note.id);
      if (index >= 0) {
        _notes[index] = note.copyWith(pinned: !note.pinned);
      }
    });
    await _save();
  }

  Future<void> _delete(_Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text(
          '"${note.displayTitle}" will be removed from this device. This '
          'cannot be undone.',
        ),
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
    if (confirmed != true) return;
    setState(() {
      _notes.removeWhere((_Note item) => item.id == note.id);
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;

    return ToolShell(
      title: 'Notes',
      howTo: 'Write a note, then search it or pin the ones you need often. '
          'Everything stays on this device.',
      actions: <Widget>[
        IconButton(
          tooltip: 'New note',
          onPressed: _create,
          icon: const Icon(Icons.add),
        ),
      ],
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Search your notes',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _notes.isEmpty
                    ? 'No notes yet'
                    : '${_notes.length} ${_notes.length == 1 ? 'note' : 'notes'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Write a note'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_loaded)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visible.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  Icon(
                    _notes.isEmpty
                        ? Icons.sticky_note_2_outlined
                        : Icons.search_off,
                    size: 36,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _notes.isEmpty
                        ? 'Nothing written yet.'
                        : 'No note matches "${_search.text.trim()}".',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _notes.isEmpty
                        ? 'Press Write a note. The first line becomes the '
                            'title.'
                        : 'Try a shorter word, or clear the search.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < visible.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: 1),
                  _NoteTile(
                    note: visible[index],
                    onOpen: () => _edit(visible[index]),
                    onPin: () => _togglePin(visible[index]),
                    onDelete: () => _delete(visible[index]),
                  ),
                ],
              ],
            ),
          ),
        const ToolNote(
          'Notes are saved on this device in plain text. Anyone who can use '
          'your computer account can read them. Do not keep passwords, card '
          'numbers or recovery codes here.',
          warning: true,
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onOpen,
    required this.onPin,
    required this.onDelete,
  });

  final _Note note;
  final VoidCallback onOpen;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = note.body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return ListTile(
      onTap: onOpen,
      leading: Icon(
        note.pinned ? Icons.push_pin : Icons.sticky_note_2_outlined,
        color: note.pinned ? theme.colorScheme.primary : null,
      ),
      title: Text(
        note.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (preview.isNotEmpty)
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            _formatDate(note.modified),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: note.pinned ? 'Unpin' : 'Pin to the top',
            icon: Icon(
              note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
            ),
            onPressed: onPin,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime when) {
    final now = DateTime.now();
    final sameDay = when.year == now.year &&
        when.month == now.month &&
        when.day == now.day;
    final time = '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'Today $time';
    final date = '${when.year}-${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({this.note});

  final _Note? note;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.note?.body ?? '');
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    _pinned = widget.note?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final body = _body.text;
    final title = _title.text.trim();
    if (title.isEmpty && body.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final previous = widget.note;
    Navigator.of(context).pop(
      _Note(
        id: previous?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        modified: DateTime.now(),
        pinned: _pinned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'New note' : 'Edit note'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  hintText: 'Left empty, the first line is the title.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 6,
                maxLines: 14,
                autofocus: widget.note == null,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pin to the top'),
                value: _pinned,
                onChanged: (bool value) => setState(() => _pinned = value),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _Note {
  const _Note({
    required this.id,
    required this.title,
    required this.body,
    required this.modified,
    required this.pinned,
  });

  final String id;
  final String title;
  final String body;
  final DateTime modified;
  final bool pinned;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = body
        .split('\n')
        .map((String line) => line.trim())
        .firstWhere((String line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return 'Untitled note';
    return firstLine.length <= 60 ? firstLine : '${firstLine.substring(0, 60)}…';
  }

  _Note copyWith({bool? pinned}) => _Note(
        id: id,
        title: title,
        body: body,
        modified: modified,
        pinned: pinned ?? this.pinned,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'modified': modified.millisecondsSinceEpoch,
        'pinned': pinned,
      };

  static _Note fromJson(Map<String, dynamic> json) => _Note(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        modified: DateTime.fromMillisecondsSinceEpoch(
          json['modified'] is int
              ? json['modified'] as int
              : DateTime.now().millisecondsSinceEpoch,
        ),
        pinned: json['pinned'] == true,
      );
}
