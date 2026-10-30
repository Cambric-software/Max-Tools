import 'dart:convert';
import 'dart:io';

/// Caches the last successful result of each tool so the app keeps working
/// when the network is unavailable and results survive a restart.
class ToolResultCache {
  ToolResultCache({this.file});

  /// Backing file. When null the cache is in-memory only.
  final File? file;

  final Map<String, String> _memory = <String, String>{};
  bool _loaded = false;

  /// Read the persisted cache. Safe to call repeatedly.
  void load() {
    if (_loaded) return;
    _loaded = true;
    final f = file;
    if (f == null || !f.existsSync()) return;
    try {
      final decoded = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        if (entry.value is String) _memory[entry.key] = entry.value as String;
      }
    } catch (_) {
      // Corrupt cache: start empty.
    }
  }

  /// Last cached result for [id], or null.
  String? get(String id) => _memory[id];

  /// Store [value] for [id] and persist.
  void put(String id, String value) {
    _memory[id] = value;
    _persist();
  }

  /// Remove the cached result for [id].
  void remove(String id) {
    _memory.remove(id);
    _persist();
  }

  void _persist() {
    final f = file;
    if (f == null) return;
    try {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode(_memory));
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}