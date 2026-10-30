import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-tool appearance overrides: accent colour and density.
///
/// Stored per tool id so a dense data tool can stay compact while a reading
/// tool stays comfortable, without changing the global theme.
class ToolThemeService {
  ToolThemeService._();
  static final ToolThemeService instance = ToolThemeService._();

  SharedPreferences? _prefs;
  final Map<String, int> _accent = <String, int>{}; // toolId -> accent index
  final Map<String, String> _density = <String, String>{}; // toolId -> density

  static const String _storageKey = 'cambric.tooltheme';

  static const List<Color> accents = <Color>[
    Color(0xFF3B6FE0),
    Color(0xFF12A594),
    Color(0xFFB26A00),
    Color(0xFFC63A34),
    Color(0xFF7C5BFF),
  ];

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final parts = raw.split(';');
      for (final part in parts) {
        final kv = part.split('=');
        if (kv.length == 3) {
          _accent[kv[0]] = int.tryParse(kv[1]) ?? 0;
          _density[kv[0]] = kv[2];
        }
      }
    } catch (_) {
      // Corrupt store: start empty.
    }
  }

  Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();
    final buf = StringBuffer();
    var first = true;
    for (final id in _accent.keys) {
      if (!first) buf.write(';');
      first = false;
      buf.write('$id=${_accent[id]}=${_density[id] ?? 'comfortable'}');
    }
    await _prefs!.setString(_storageKey, buf.toString());
  }

  Color accentFor(String toolId) {
    final idx = _accent[toolId];
    if (idx == null || idx < 0 || idx >= accents.length) return accents.first;
    return accents[idx];
  }

  String densityFor(String toolId) => _density[toolId] ?? 'comfortable';

  Future<void> setAccent(String toolId, int index) async {
    _accent[toolId] = index;
    await _save();
  }

  Future<void> setDensity(String toolId, String density) async {
    _density[toolId] = density;
    await _save();
  }
}