import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The accent a person can choose for the app.
///
/// Each accent is a seed colour, not a hand-built palette. The base Cambric
/// design keeps its surfaces, borders and semantic danger colours; only the
/// primary, secondary and tertiary families are re-derived from the seed. That
/// is why a theme change is visible on every screen without a second design
/// system.
enum AppAccent {
  blue('blue', Color(0xFF3B82F6)),
  teal('teal', Color(0xFF0D9488)),
  purple('purple', Color(0xFF7C3AED)),
  green('green', Color(0xFF16A34A)),
  amber('amber', Color(0xFFD97706));

  const AppAccent(this.storageKey, this.seed);

  /// Value written to storage.
  final String storageKey;

  /// Seed colour used to derive the palette.
  final Color seed;

  /// Translation key for the accent name.
  String get labelKey => 'accent_$storageKey';

  /// Look up an accent, falling back to blue for an unknown stored value.
  static AppAccent fromStorage(String? value) {
    for (final AppAccent accent in AppAccent.values) {
      if (accent.storageKey == value) return accent;
    }
    return AppAccent.blue;
  }
}

/// One person's saved appearance.
///
/// The app is shared in a household, so the theme, text size and language are
/// stored per person rather than per device. [id] is stable; [name] is what the
/// person typed.
@immutable
class PersonProfile {
  /// Create a profile.
  const PersonProfile({
    required this.id,
    required this.name,
    this.themeMode = ThemeMode.system,
    this.accent = AppAccent.blue,
    this.textScale = 1.0,
    this.languageCode = 'en',
    this.highContrast = false,
  });

  /// Stable identifier used as the storage key.
  final String id;

  /// Name shown in the profile switcher.
  final String name;

  /// Light, dark or follow the system.
  final ThemeMode themeMode;

  /// Accent seed.
  final AppAccent accent;

  /// Multiplier applied on top of the operating system's text scale.
  final double textScale;

  /// `en` or `ar`.
  final String languageCode;

  /// Stronger borders and contrast.
  final bool highContrast;

  /// The same profile with selected fields replaced.
  PersonProfile copyWith({
    String? name,
    ThemeMode? themeMode,
    AppAccent? accent,
    double? textScale,
    String? languageCode,
    bool? highContrast,
  }) {
    return PersonProfile(
      id: id,
      name: name ?? this.name,
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      textScale: textScale ?? this.textScale,
      languageCode: languageCode ?? this.languageCode,
      highContrast: highContrast ?? this.highContrast,
    );
  }

  /// Serialise for storage.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'theme': AppSettings._themeToStorage(themeMode),
        'accent': accent.storageKey,
        'textScale': textScale,
        'language': languageCode,
        'highContrast': highContrast,
      };

  /// Read a stored profile, falling back to safe values for a damaged entry.
  static PersonProfile fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] ?? '').toString();
    final String name = (json['name'] ?? '').toString().trim();
    return PersonProfile(
      id: id.isEmpty ? 'default' : id,
      name: name.isEmpty ? 'Me' : name,
      themeMode: AppSettings._themeFromStorage(json['theme']?.toString()),
      accent: AppAccent.fromStorage(json['accent']?.toString()),
      textScale: AppSettings._clampScale(
        (json['textScale'] as num?)?.toDouble() ?? 1.0,
      ),
      languageCode: json['language'] == 'ar' ? 'ar' : 'en',
      highContrast: json['highContrast'] == true,
    );
  }

  /// Every profile starts from these values.
  static const PersonProfile defaults = PersonProfile(
    id: 'default',
    name: 'Me',
  );
}

/// Preferences the person using the app can actually change.
///
/// Every setting here has a visible effect the moment it is changed and
/// survives a restart. Appearance is stored per person: switching profiles
/// applies that person's theme, accent, text size, language and contrast in one
/// step, and the next change is written back to the profile that is active.
///
/// The old keys (`max_tools.theme_mode`, `max_tools.high_contrast`) are read
/// once when no profile store exists, so an existing install keeps the choice
/// it already had instead of silently reverting.
class AppSettings {
  AppSettings._();

  /// The single instance the application reads from.
  static final AppSettings instance = AppSettings._();

  static const String _profilesKey = 'max_tools.profiles';
  static const String _activeKey = 'max_tools.active_profile';
  static const String _legacyThemeKey = 'max_tools.theme_mode';
  static const String _legacyContrastKey = 'max_tools.high_contrast';

  /// Smallest text scale offered. Below this, labels start to clip.
  static const double minTextScale = 0.9;

  /// Largest text scale offered. Above this, the settings screen itself becomes
  /// unusable on a phone.
  static const double maxTextScale = 1.6;

  /// The active theme mode. Widgets listen to this to rebuild when it changes.
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// High-contrast mode for better readability.
  final ValueNotifier<bool> highContrast = ValueNotifier<bool>(false);

  /// Accent seed for the active profile.
  final ValueNotifier<AppAccent> accent =
      ValueNotifier<AppAccent>(AppAccent.blue);

  /// Text multiplier for the active profile.
  final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  /// Language code for the active profile.
  final ValueNotifier<String> languageCode = ValueNotifier<String>('en');

  /// Every profile, in the order they were created.
  final ValueNotifier<List<PersonProfile>> profiles =
      ValueNotifier<List<PersonProfile>>(<PersonProfile>[
    PersonProfile.defaults,
  ]);

  /// The id of the profile whose settings are active.
  final ValueNotifier<String> activeProfileId =
      ValueNotifier<String>(PersonProfile.defaults.id);

  bool _loaded = false;
  bool _applying = false;

  /// Whether [load] has run.
  bool get isLoaded => _loaded;

  /// The profile that is currently applied.
  PersonProfile get activeProfile {
    for (final PersonProfile profile in profiles.value) {
      if (profile.id == activeProfileId.value) return profile;
    }
    return profiles.value.isEmpty
        ? PersonProfile.defaults
        : profiles.value.first;
  }

  /// Reads stored preferences. Call once at startup, before `runApp`.
  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_profilesKey);
      if (raw == null || raw.isEmpty) {
        await _migrateLegacy(prefs);
      } else {
        final Object? decoded = jsonDecode(raw);
        final List<PersonProfile> parsed = <PersonProfile>[];
        if (decoded is List) {
          for (final Object? entry in decoded) {
            if (entry is Map<String, dynamic>) {
              parsed.add(PersonProfile.fromJson(entry));
            } else if (entry is Map) {
              parsed.add(
                PersonProfile.fromJson(entry.cast<String, dynamic>()),
              );
            }
          }
        }
        if (parsed.isEmpty) parsed.add(PersonProfile.defaults);
        profiles.value = _deduplicate(parsed);
        final String? storedActive = prefs.getString(_activeKey);
        activeProfileId.value = profiles.value.any(
          (PersonProfile p) => p.id == storedActive,
        )
            ? storedActive!
            : profiles.value.first.id;
      }
      _applyActive();
    } catch (_) {
      // Unreadable preferences fall back to the default rather than blocking
      // startup.
      profiles.value = <PersonProfile>[PersonProfile.defaults];
      activeProfileId.value = PersonProfile.defaults.id;
      _applyActive();
    }
    _loaded = true;
  }

  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final ThemeMode mode = _themeFromStorage(prefs.getString(_legacyThemeKey));
    final bool contrast = prefs.getBool(_legacyContrastKey) ?? false;
    final PersonProfile migrated = PersonProfile.defaults.copyWith(
      themeMode: mode,
      highContrast: contrast,
    );
    profiles.value = <PersonProfile>[migrated];
    activeProfileId.value = migrated.id;
    await _persist();
  }

  List<PersonProfile> _deduplicate(List<PersonProfile> input) {
    final Set<String> seen = <String>{};
    final List<PersonProfile> output = <PersonProfile>[];
    for (final PersonProfile profile in input) {
      if (seen.add(profile.id)) {
        output.add(profile);
      } else {
        output.add(
          profile.copyWith(name: '${profile.name} 2'),
        );
      }
    }
    return output;
  }

  /// Applies the active profile to the live notifiers.
  void _applyActive() {
    final PersonProfile profile = activeProfile;
    _applying = true;
    themeMode.value = profile.themeMode;
    accent.value = profile.accent;
    textScale.value = _clampScale(profile.textScale);
    languageCode.value = profile.languageCode == 'ar' ? 'ar' : 'en';
    highContrast.value = profile.highContrast;
    _applying = false;
  }

  /// Changes the theme and stores it on the active profile.
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _updateActive((PersonProfile p) => p.copyWith(themeMode: mode));
  }

  /// Changes the accent and stores it on the active profile.
  Future<void> setAccent(AppAccent value) async {
    accent.value = value;
    await _updateActive((PersonProfile p) => p.copyWith(accent: value));
  }

  /// Changes the text scale and stores it on the active profile.
  Future<void> setTextScale(double value) async {
    final double clamped = _clampScale(value);
    textScale.value = clamped;
    await _updateActive((PersonProfile p) => p.copyWith(textScale: clamped));
  }

  /// Changes the language and stores it on the active profile.
  Future<void> setLanguage(String code) async {
    final String safe = code == 'ar' ? 'ar' : 'en';
    languageCode.value = safe;
    await _updateActive((PersonProfile p) => p.copyWith(languageCode: safe));
  }

  /// Changes the contrast and stores it on the active profile.
  Future<void> setHighContrast(bool value) async {
    highContrast.value = value;
    await _updateActive((PersonProfile p) => p.copyWith(highContrast: value));
  }

  /// Switch to another profile and apply its settings.
  Future<void> selectProfile(String id) async {
    if (id == activeProfileId.value) return;
    if (!profiles.value.any((PersonProfile p) => p.id == id)) return;
    activeProfileId.value = id;
    _applyActive();
    await _persist();
  }

  /// Add a profile and switch to it.
  ///
  /// A new profile starts from the defaults rather than copying the current
  /// person's settings, so two people do not accidentally share a text size
  /// that only one of them needs.
  Future<PersonProfile> addProfile(String name) async {
    final String trimmed = name.trim();
    final PersonProfile created = PersonProfile(
      id: _newId(),
      name: trimmed.isEmpty ? 'Person ${profiles.value.length + 1}' : trimmed,
    );
    profiles.value = <PersonProfile>[...profiles.value, created];
    activeProfileId.value = created.id;
    _applyActive();
    await _persist();
    return created;
  }

  /// Rename a profile. The active person sees the new name immediately.
  Future<void> renameProfile(String id, String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;
    profiles.value = profiles.value
        .map((PersonProfile p) => p.id == id ? p.copyWith(name: trimmed) : p)
        .toList();
    await _persist();
  }

  /// Delete a profile. The last profile cannot be deleted.
  Future<bool> deleteProfile(String id) async {
    if (profiles.value.length <= 1) return false;
    final List<PersonProfile> next =
        profiles.value.where((PersonProfile p) => p.id != id).toList();
    if (next.isEmpty) return false;
    profiles.value = next;
    if (activeProfileId.value == id) {
      activeProfileId.value = next.first.id;
      _applyActive();
    }
    await _persist();
    return true;
  }

  /// Returns the active profile to its defaults.
  Future<void> restoreDefaults() async {
    final PersonProfile reset = PersonProfile(
      id: activeProfileId.value,
      name: activeProfile.name,
    );
    profiles.value = profiles.value
        .map((PersonProfile p) => p.id == reset.id ? reset : p)
        .toList();
    _applyActive();
    await _persist();
  }

  Future<void> _updateActive(
    PersonProfile Function(PersonProfile) update,
  ) async {
    if (_applying) return;
    profiles.value = profiles.value
        .map((PersonProfile p) => p.id == activeProfileId.value ? update(p) : p)
        .toList();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _profilesKey,
        jsonEncode(
          profiles.value.map((PersonProfile p) => p.toJson()).toList(),
        ),
      );
      await prefs.setString(_activeKey, activeProfileId.value);
    } catch (_) {
      // The change still applies for this session.
    }
  }

  static double _clampScale(double value) =>
      value.clamp(minTextScale, maxTextScale).toDouble();

  static ThemeMode _themeFromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String _newId() {
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    int suffix = 0;
    while (profiles.value.any((PersonProfile p) => p.id == 'p$stamp-$suffix')) {
      suffix++;
    }
    return 'p$stamp-$suffix';
  }
}
