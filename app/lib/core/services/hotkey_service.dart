import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores and dispatches global hotkeys for favourite tools.
class HotkeyService {
  HotkeyService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;
  final Map<String, String> _map = <String, String>{}; // keySpec -> toolId

  static const String _storageKey = 'cambric.hotkeys';

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          if (entry.value is String) _map[entry.key] = entry.value as String;
        }
      }
    } catch (_) {
      // Corrupt store: start empty.
    }
  }

  Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_storageKey, jsonEncode(_map));
  }

  Future<void> bind(String keySpec, String toolId) async {
    _map[keySpec.toLowerCase()] = toolId;
    await _save();
  }

  Future<void> unbind(String keySpec) async {
    _map.remove(keySpec.toLowerCase());
    await _save();
  }

  String? toolFor(String keySpec) => _map[keySpec.toLowerCase()];

  Map<String, String> get bindings => Map<String, String>.unmodifiable(_map);

  static String specFromEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final parts = <String>[];
    if (keyboard.isControlPressed) parts.add('ctrl');
    if (keyboard.isShiftPressed) parts.add('shift');
    if (keyboard.isAltPressed) parts.add('alt');
    if (keyboard.isMetaPressed) parts.add('meta');
    parts.add(event.logicalKey.keyLabel.toLowerCase());
    return parts.join('+');
  }
}