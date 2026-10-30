import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences the person using the app can actually change.
///
/// Kept deliberately small. Each setting here has a visible effect the moment
/// it is changed, and survives a restart. Anything that could not be honoured
/// is not offered — the previous settings screen listed cards of template text
/// that did nothing, which is worse than an empty screen.
class AppSettings {
  AppSettings._();

  /// The single instance the application reads from.
  static final AppSettings instance = AppSettings._();

  static const String _themeKey = 'max_tools.theme_mode';
  static const String _highContrastKey = 'max_tools.high_contrast';

  /// The active theme mode. Widgets listen to this to rebuild when it changes.
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  /// High-contrast mode for better readability.
  final ValueNotifier<bool> highContrast = ValueNotifier<bool>(false);

  /// Reads stored preferences. Call once at startup, before `runApp`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      themeMode.value = _decodeTheme(prefs.getString(_themeKey));
      highContrast.value = prefs.getBool(_highContrastKey) ?? false;
    } catch (_) {
      // Unreadable preferences fall back to the default rather than blocking
      // startup.
      themeMode.value = ThemeMode.system;
      highContrast.value = false;
    }
  }

  /// Changes the theme and stores the choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _encodeTheme(mode));
    } catch (_) {
      // The change still applies for this session.
    }
  }

  /// Changes the theme and stores the choice.
  Future<void> setHighContrast(bool value) async {
    highContrast.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_highContrastKey, value);
    } catch (_) {
      // The change still applies for this session.
    }
  }

  /// Returns every setting to its default.
  Future<void> restoreDefaults() async {
    await setThemeMode(ThemeMode.system);
    await setHighContrast(false);
  }

  ThemeMode _decodeTheme(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _encodeTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
