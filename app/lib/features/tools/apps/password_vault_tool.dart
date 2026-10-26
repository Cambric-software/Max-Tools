import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_shell.dart';

/// An encrypted password vault.
///
/// The vault is one AES-GCM message whose key is derived from the master
/// password with PBKDF2-HMAC-SHA256. The salt and iteration count are stored
/// with the ciphertext; the password is never stored. Everything is local.
///
/// The screen is honest about the weak point: an attacker who copies the
/// stored ciphertext can guess master passwords offline, so the password is the
/// security. There is no recovery if it is forgotten.
class PasswordVaultTool extends StatefulWidget {
  /// Create the tool.
  const PasswordVaultTool({super.key});

  @override
  State<PasswordVaultTool> createState() => _PasswordVaultToolState();
}

enum _Stage { loading, create, unlock, open }

class _PasswordVaultToolState extends State<PasswordVaultTool>
    with WidgetsBindingObserver {
  static const String _storageKey = 'max_tools.vault.v1';
  static const int _iterations = 210000;

  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _search = TextEditingController();

  _Stage _stage = _Stage.loading;
  List<_VaultEntry> _entries = <_VaultEntry>[];
  List<int> _salt = const <int>[];
  SecretKey? _key;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _password.dispose();
    _confirm.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app locks the vault, so a person who walks away does not
    // leave every password on screen.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _lock();
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (!mounted) return;
    setState(() => _stage = raw == null ? _Stage.create : _Stage.unlock);
  }

  void _lock() {
    if (!mounted) return;
    if (_stage != _Stage.open) return;
    setState(() {
      _entries = <_VaultEntry>[];
      _key = null;
      _salt = const <int>[];
      _password.clear();
      _confirm.clear();
      _search.clear();
      _formError = null;
      _stage = _Stage.unlock;
    });
  }

  Future<void> _create() async {
    final password = _password.text;
    final confirm = _confirm.text;
    if (password.length < 10) {
      setState(() => _formError = 'Use at least 10 characters. Longer is '
          'better than complicated.');
      return;
    }
    if (password != confirm) {
      setState(() => _formError = 'The two passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final salt = _randomBytes(16);
      final key = await _derive(password, salt, _iterations);
      _salt = salt;
      _key = key;
      _entries = <_VaultEntry>[];
      await _persist();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = _Stage.open;
        _password.clear();
        _confirm.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = 'Could not create the vault: $error';
      });
    }
  }

  Future<void> _unlock() async {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _formError = 'Enter your master password.');
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final opened = await _openWith(password);
      if (!mounted) return;
      if (opened == null) {
        setState(() {
          _busy = false;
          _formError = 'That password did not unlock the vault.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _entries = opened.entries;
        _salt = opened.salt;
        _key = opened.key;
        _stage = _Stage.open;
        _password.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = 'The stored vault could not be read: $error';
      });
    }
  }

  Future<_OpenedVault?> _openWith(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final salt = _fromBase64('${decoded['salt'] ?? ''}');
    final nonce = _fromBase64('${decoded['nonce'] ?? ''}');
    final mac = _fromBase64('${decoded['mac'] ?? ''}');
    final data = _fromBase64('${decoded['data'] ?? ''}');
    final iterations = decoded['iterations'] is int
        ? decoded['iterations'] as int
        : _iterations;
    if (salt.isEmpty || nonce.isEmpty || mac.isEmpty) return null;

    final key = await _derive(password, salt, iterations);
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(data, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      final list = jsonDecode(utf8.decode(clear));
      final entries = list is List
          ? list
              .whereType<Map<String, dynamic>>()
              .map(_VaultEntry.fromJson)
              .toList()
          : <_VaultEntry>[];
      return _OpenedVault(key: key, salt: salt, entries: entries);
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  Future<void> _persist() async {
    final key = _key;
    if (key == null) return;
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(_entries.map((_VaultEntry e) => e.toJson()).toList())),
      secretKey: key,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(<String, dynamic>{
        'version': 1,
        'iterations': _iterations,
        'salt': base64Encode(_salt),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'data': base64Encode(box.cipherText),
      }),
    );
  }

  Future<SecretKey> _derive(String password, List<int> salt, int iterations) {
    return Pbkdf2.hmacSha256(iterations: iterations, bits: 256).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static List<int> _fromBase64(String value) {
    if (value.isEmpty) return const <int>[];
    try {
      return base64Decode(value);
    } catch (_) {
      return const <int>[];
    }
  }

  List<_VaultEntry> get _visible {
    final query = _search.text.trim().toLowerCase();
    final items = query.isEmpty
        ? _entries
        : _entries
            .where((_VaultEntry entry) =>
                entry.title.toLowerCase().contains(query) ||
                entry.username.toLowerCase().contains(query) ||
                entry.url.toLowerCase().contains(query))
            .toList();
    items.sort((_VaultEntry a, _VaultEntry b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return items;
  }

  Future<void> _add() async {
    final entry = await showDialog<_VaultEntry>(
      context: context,
      builder: (_) => const _EntryEditor(),
    );
    if (entry == null) return;
    setState(() => _entries.add(entry));
    await _persist();
  }

  Future<void> _edit(_VaultEntry entry) async {
    final updated = await showDialog<_VaultEntry>(
      context: context,
      builder: (_) => _EntryEditor(entry: entry),
    );
    if (updated == null) return;
    setState(() {
      final index = _entries.indexWhere((_VaultEntry item) => item.id == entry.id);
      if (index >= 0) _entries[index] = updated;
    });
    await _persist();
  }

  Future<void> _delete(_VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('"${entry.title}" will be removed from the vault.'),
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
    setState(() => _entries.removeWhere((_VaultEntry item) => item.id == entry.id));
    await _persist();
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<_PasswordChange>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == null) return;

    final stillThere = await _openWith(changed.current);
    if (stillThere == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The current password is wrong.')),
      );
      return;
    }

    final salt = _randomBytes(16);
    final key = await _derive(changed.next, salt, _iterations);
    setState(() {
      _salt = salt;
      _key = key;
    });
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Master password changed.')),
    );
  }

  void _copy(_VaultEntry entry) {
    Clipboard.setData(ClipboardData(text: entry.password));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password copied. Clear the clipboard when you are done.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.loading => const ToolShell(
          title: 'Password vault',
          howTo: 'Opening the vault…',
          children: <Widget>[
            Center(child: CircularProgressIndicator()),
          ],
        ),
      _Stage.create => _lockedShell(
          title: 'Create your vault',
          blurb: 'Choose one master password. It encrypts every entry and it is '
              'the only way in. There is no reset and no recovery.',
          action: 'Create vault',
          onAction: _create,
          showConfirm: true,
        ),
      _Stage.unlock => _lockedShell(
          title: 'Unlock',
          blurb: 'Enter the master password for this vault.',
          action: 'Unlock',
          onAction: _unlock,
          showConfirm: false,
        ),
      _Stage.open => _openShell(),
    };
  }

  Widget _lockedShell({
    required String title,
    required String blurb,
    required String action,
    required Future<void> Function() onAction,
    required bool showConfirm,
  }) {
    final theme = Theme.of(context);
    return ToolShell(
      title: 'Password vault',
      howTo: 'Passwords are encrypted on this device with a key derived from '
          'your master password. Nothing is sent anywhere.',
      children: <Widget>[
        ToolSection(
          title: title,
          icon: Icons.lock_outline,
          children: <Widget>[
            Text(blurb, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              onSubmitted: (_) => onAction(),
              decoration: const InputDecoration(
                labelText: 'Master password',
                border: OutlineInputBorder(),
              ),
            ),
            if (showConfirm) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: true,
                onSubmitted: (_) => onAction(),
                decoration: const InputDecoration(
                  labelText: 'Type it again',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_formError != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _formError!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : onAction,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(action),
              ),
            ),
            const ToolNote(
              'A forgotten master password cannot be recovered. Write it down '
              'and keep it somewhere physically safe, not in this vault.',
            ),
          ],
        ),
        const ToolSection(
          title: 'How it is protected',
          icon: Icons.shield_outlined,
          children: <Widget>[
            ToolNote(
              'AES-256-GCM encryption, with the key derived from your password '
              'using PBKDF2-HMAC-SHA256 and 210,000 rounds. A fresh random '
              'salt is created with the vault, and every save uses a new '
              'nonce.',
            ),
            ToolNote(
              'The vault is stored in this app\'s local settings. Someone who '
              'copies that data can guess passwords offline, so a long master '
              'password matters more than a complicated one.',
            ),
            ToolNote(
              'Copying a password puts it on the system clipboard, where other '
              'programs may read it. Clear the clipboard after pasting.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _openShell() {
    final theme = Theme.of(context);
    final visible = _visible;
    return ToolShell(
      title: 'Password vault',
      howTo: 'Tap an entry to edit it, or the key to copy its password. Lock the '
          'vault before you walk away.',
      actions: <Widget>[
        IconButton(
          tooltip: 'Lock the vault',
          onPressed: _lock,
          icon: const Icon(Icons.lock_outline),
        ),
        PopupMenuButton<String>(
          tooltip: 'Vault options',
          onSelected: (String value) {
            if (value == 'change') _changePassword();
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'change',
              child: Text('Change master password'),
            ),
          ],
        ),
      ],
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Search entries',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${_entries.length} ${_entries.length == 1 ? 'entry' : 'entries'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add entry'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  Icon(
                    _entries.isEmpty ? Icons.key_outlined : Icons.search_off,
                    size: 36,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _entries.isEmpty
                        ? 'The vault is empty.'
                        : 'No entry matches "${_search.text.trim()}".',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _entries.isEmpty
                        ? 'Press Add entry to store the first password.'
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
                  ListTile(
                    onTap: () => _edit(visible[index]),
                    leading: const Icon(Icons.key_outlined),
                    title: Text(
                      visible[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      visible[index].username.isEmpty
                          ? visible[index].url
                          : visible[index].username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Copy password',
                          icon: const Icon(Icons.key, size: 20),
                          onPressed: () => _copy(visible[index]),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _delete(visible[index]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        const ToolNote(
          'This vault protects stored passwords, not a compromised computer. If '
          'malware is already running, it can read what you copy or type.',
          warning: true,
        ),
      ],
    );
  }
}

class _OpenedVault {
  const _OpenedVault({
    required this.key,
    required this.salt,
    required this.entries,
  });

  final SecretKey key;
  final List<int> salt;
  final List<_VaultEntry> entries;
}

class _VaultEntry {
  const _VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.url,
    required this.notes,
    required this.updated,
  });

  final String id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final DateTime updated;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'updated': updated.millisecondsSinceEpoch,
      };

  static _VaultEntry fromJson(Map<String, dynamic> json) => _VaultEntry(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        username: '${json['username'] ?? ''}',
        password: '${json['password'] ?? ''}',
        url: '${json['url'] ?? ''}',
        notes: '${json['notes'] ?? ''}',
        updated: DateTime.fromMillisecondsSinceEpoch(
          json['updated'] is int
              ? json['updated'] as int
              : DateTime.now().millisecondsSinceEpoch,
        ),
      );
}

class _EntryEditor extends StatefulWidget {
  const _EntryEditor({this.entry});

  final _VaultEntry? entry;

  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.entry?.title ?? '');
  late final TextEditingController _username =
      TextEditingController(text: widget.entry?.username ?? '');
  late final TextEditingController _password =
      TextEditingController(text: widget.entry?.password ?? '');
  late final TextEditingController _url =
      TextEditingController(text: widget.entry?.url ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.entry?.notes ?? '');
  bool _visible = false;

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _generate() {
    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%^&*-_=+';
    final random = Random.secure();
    final value = List<String>.generate(
      20,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
    setState(() {
      _password.text = value;
      _visible = true;
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      _VaultEntry(
        id: widget.entry?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        username: _username.text.trim(),
        password: _password.text,
        url: _url.text.trim(),
        notes: _notes.text.trim(),
        updated: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'New entry' : 'Edit entry'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _title,
                autofocus: widget.entry == null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'What is it for?',
                  hintText: 'Bank, email, workshop wifi…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _username,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username or email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: !_visible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: _visible ? 'Hide' : 'Show',
                        icon: Icon(
                          _visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _visible = !_visible),
                      ),
                      IconButton(
                        tooltip: 'Generate a strong password',
                        icon: const Icon(Icons.casino_outlined, size: 20),
                        onPressed: _generate,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _url,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Website (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
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

class _PasswordChange {
  const _PasswordChange({required this.current, required this.next});

  final String current;
  final String next;
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    if (_next.text.length < 10) {
      setState(() => _error = 'Use at least 10 characters.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'The new passwords do not match.');
      return;
    }
    Navigator.of(context).pop(
      _PasswordChange(current: _current.text, next: _next.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Change master password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              obscureText: true,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'New password again',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
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
        FilledButton(
          onPressed: _save,
          child: const Text('Change password'),
        ),
      ],
    );
  }
}
