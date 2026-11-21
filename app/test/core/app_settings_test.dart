import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AppSettings settings = AppSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await settings.load();
  });

  test('starts with one profile and safe defaults', () {
    expect(settings.profiles.value, hasLength(1));
    expect(settings.activeProfile.name, PersonProfile.defaults.name);
    expect(settings.themeMode.value, ThemeMode.system);
    expect(settings.accent.value, AppAccent.blue);
    expect(settings.textScale.value, 1.0);
    expect(settings.languageCode.value, 'en');
    expect(settings.highContrast.value, isFalse);
  });

  test('clamps text scale to the offered range', () async {
    await settings.setTextScale(4);
    expect(settings.textScale.value, AppSettings.maxTextScale);

    await settings.setTextScale(0.1);
    expect(settings.textScale.value, AppSettings.minTextScale);
  });

  test('persists appearance across a reload', () async {
    await settings.setThemeMode(ThemeMode.dark);
    await settings.setAccent(AppAccent.teal);
    await settings.setTextScale(1.25);
    await settings.setLanguage('ar');
    await settings.setHighContrast(true);

    await settings.load();

    expect(settings.themeMode.value, ThemeMode.dark);
    expect(settings.accent.value, AppAccent.teal);
    expect(settings.textScale.value, 1.25);
    expect(settings.languageCode.value, 'ar');
    expect(settings.highContrast.value, isTrue);
  });

  test('a new person starts from defaults, and switching restores each', () async {
    await settings.setTextScale(1.5);
    await settings.setAccent(AppAccent.purple);

    final PersonProfile second = await settings.addProfile('Sara');

    expect(second.name, 'Sara');
    expect(settings.activeProfileId.value, second.id);
    expect(settings.textScale.value, 1.0);
    expect(settings.accent.value, AppAccent.blue);
    expect(settings.languageCode.value, 'en');

    await settings.setLanguage('ar');
    await settings.selectProfile(PersonProfile.defaults.id);

    expect(settings.languageCode.value, 'en');
    expect(settings.textScale.value, 1.5);
    expect(settings.accent.value, AppAccent.purple);
  });

  test('the last profile cannot be deleted', () async {
    final bool removed =
        await settings.deleteProfile(settings.activeProfileId.value);

    expect(removed, isFalse);
    expect(settings.profiles.value, hasLength(1));
  });

  test('restoring defaults only affects the active person', () async {
    final PersonProfile second = await settings.addProfile('Omar');
    await settings.setThemeMode(ThemeMode.dark);

    await settings.selectProfile(PersonProfile.defaults.id);
    await settings.setThemeMode(ThemeMode.light);
    await settings.restoreDefaults();

    expect(settings.themeMode.value, ThemeMode.system);

    await settings.selectProfile(second.id);
    expect(settings.themeMode.value, ThemeMode.dark);
  });

  test('migrates the legacy theme and contrast keys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'max_tools.theme_mode': 'dark',
      'max_tools.high_contrast': true,
    });

    await settings.load();

    expect(settings.themeMode.value, ThemeMode.dark);
    expect(settings.highContrast.value, isTrue);
    expect(settings.profiles.value, hasLength(1));
  });

  test('unknown stored values fall back instead of throwing', () {
    final PersonProfile profile = PersonProfile.fromJson(<String, dynamic>{
      'id': 'x',
      'name': '  ',
      'theme': 'sepia',
      'accent': 'chartreuse',
      'textScale': 99,
      'language': 'fr',
      'highContrast': 'yes',
    });

    expect(profile.name, 'Me');
    expect(profile.themeMode, ThemeMode.system);
    expect(profile.accent, AppAccent.blue);
    expect(profile.textScale, AppSettings.maxTextScale);
    expect(profile.languageCode, 'en');
    expect(profile.highContrast, isFalse);
  });
}
