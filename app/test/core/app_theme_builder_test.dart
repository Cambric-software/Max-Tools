import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/core/settings/app_settings.dart';
import 'package:max_tools/core/settings/app_theme_builder.dart';

void main() {
  group('buildAppTheme', () {
    test('an accent changes the primary colour', () {
      final ThemeData blue = buildAppTheme(
        brightness: Brightness.light,
        accent: AppAccent.blue,
        highContrast: false,
      );
      final ThemeData green = buildAppTheme(
        brightness: Brightness.light,
        accent: AppAccent.green,
        highContrast: false,
      );

      expect(blue.colorScheme.primary, isNot(green.colorScheme.primary));
    });

    test('an accent leaves surfaces and danger colours alone', () {
      final ThemeData blue = buildAppTheme(
        brightness: Brightness.light,
        accent: AppAccent.blue,
        highContrast: false,
      );
      final ThemeData amber = buildAppTheme(
        brightness: Brightness.light,
        accent: AppAccent.amber,
        highContrast: false,
      );

      expect(blue.colorScheme.surface, amber.colorScheme.surface);
      expect(blue.colorScheme.error, amber.colorScheme.error);
      expect(blue.colorScheme.onSurface, amber.colorScheme.onSurface);
    });

    test('high contrast widens the card border', () {
      final ThemeData normal = buildAppTheme(
        brightness: Brightness.dark,
        accent: AppAccent.teal,
        highContrast: false,
      );
      final ThemeData strong = buildAppTheme(
        brightness: Brightness.dark,
        accent: AppAccent.teal,
        highContrast: true,
      );

      final double normalWidth =
          (normal.cardTheme.shape! as RoundedRectangleBorder).side.width;
      final double strongWidth =
          (strong.cardTheme.shape! as RoundedRectangleBorder).side.width;

      expect(strongWidth, greaterThan(normalWidth));
    });

    test('light and dark both honour the chosen accent', () {
      final ThemeData light = buildAppTheme(
        brightness: Brightness.light,
        accent: AppAccent.purple,
        highContrast: false,
      );
      final ThemeData dark = buildAppTheme(
        brightness: Brightness.dark,
        accent: AppAccent.purple,
        highContrast: false,
      );

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
    });
  });

  group('effectiveTextScale', () {
    test('multiplies the system scale by the person setting', () {
      expect(effectiveTextScale(1.0, 1.3), closeTo(1.3, 0.001));
      expect(effectiveTextScale(1.5, 1.2), closeTo(1.8, 0.001));
    });

    test('clamps so the two scales cannot make a screen unusable', () {
      expect(effectiveTextScale(2.5, 1.6), 3.0);
      expect(effectiveTextScale(0.5, 0.9), 0.8);
    });

    test('a broken system scale falls back to 1.0', () {
      expect(effectiveTextScale(double.nan, 1.2), closeTo(1.2, 0.001));
      expect(effectiveTextScale(0, 1.2), closeTo(1.2, 0.001));
    });
  });
}
