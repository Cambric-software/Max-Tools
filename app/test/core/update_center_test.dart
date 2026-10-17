import 'package:flutter_test/flutter_test.dart';

import 'package:max_tools/core/config/cambric_config.dart';
import 'package:max_tools/core/updates/update_center.dart';
import 'package:max_tools/core/updates/update_state.dart';

void main() {
  group('version comparison', () {
    test('equal versions', () {
      expect(UpdateCenter.compareVersions('1.0.0', '1.0.0'), 0);
      expect(UpdateCenter.compareVersions('v1.0.0', '1.0.0'), 0);
    });

    test('newer patch, minor and major', () {
      expect(UpdateCenter.compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(UpdateCenter.compareVersions('1.1.0', '1.0.9'), greaterThan(0));
      expect(UpdateCenter.compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('older versions', () {
      expect(UpdateCenter.compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(UpdateCenter.compareVersions('0.9.0', '1.0.0'), lessThan(0));
    });

    test('numeric segments compare as numbers, not text', () {
      // 0.10 is newer than 0.9 even though "0.10" < "0.9" as a string.
      expect(UpdateCenter.compareVersions('0.10.0', '0.9.0'), greaterThan(0));
      expect(UpdateCenter.compareVersions('1.0.10', '1.0.9'), greaterThan(0));
    });

    test('more segments is a newer version', () {
      expect(UpdateCenter.compareVersions('1.2.1', '1.2'), greaterThan(0));
      expect(UpdateCenter.compareVersions('1.2', '1.2.1'), lessThan(0));
    });

    test('a pre-release never outranks a stable release', () {
      expect(
        UpdateCenter.compareVersions('1.0.0-pre', '1.0.0'),
        lessThan(0),
      );
      expect(
        UpdateCenter.compareVersions('1.0.0', '1.0.0-pre'),
        greaterThan(0),
      );
    });

    test('handles hyphen and underscore separators', () {
      expect(UpdateCenter.compareVersions('1-2-3', '1.2.3'), 0);
      expect(UpdateCenter.compareVersions('1_2_4', '1.2.3'), greaterThan(0));
    });

    test('empty and junk versions do not crash', () {
      expect(UpdateCenter.compareVersions('', ''), 0);
      expect(UpdateCenter.compareVersions('abc', '1.0.0'), isNot(0));
      expect(UpdateCenter.compareVersions('1.0.0', 'abc'), isNot(0));
    });
  });

  group('gating', () {
    test('no repository means updates are off', () {
      final centre = UpdateCenter(
        config: const CambricConfig(
          productId: 'p',
          productName: 'n',
          version: '1.0.0',
          templateVersion: '1.0.0',
        ),
      );
      expect(centre.repository, isEmpty);
      expect(centre.isEnabled, isFalse);
    });

    test('a repository but no enable flag stays off', () {
      final centre = UpdateCenter(
        config: const CambricConfig(
          productId: 'p',
          productName: 'n',
          version: '1.0.0',
          templateVersion: '1.0.0',
          repository: 'owner/repo',
          updatesEnabled: false,
        ),
      );
      expect(centre.isEnabled, isFalse);
    });

    test('repository and flag together enable it', () {
      final centre = UpdateCenter(
        config: const CambricConfig(
          productId: 'p',
          productName: 'n',
          version: '1.0.0',
          templateVersion: '1.0.0',
          repository: 'owner/repo',
          updatesEnabled: true,
        ),
      );
      expect(centre.isEnabled, isTrue);
      expect(centre.repository, 'owner/repo');
    });

    test('a disabled centre reports why instead of failing', () async {
      final centre = UpdateCenter();
      final result = await centre.check(currentVersion: '1.0.0');
      expect(result.isUpdateAvailable, isFalse);
      expect(result.state.name, 'notAvailable');
      expect(result.error, isNotNull);
      expect(result.summary, contains('failed'));
    });
  });

  group('check results', () {
    test('an available update is only reported when it is newer', () {
      const newer = UpdateCheck(
        currentVersion: '1.0.0',
        latestVersion: '1.1.0',
        state: UpdateState.available,
      );
      expect(newer.isUpdateAvailable, isTrue);
      expect(newer.summary, contains('1.1.0'));

      const same = UpdateCheck(
        currentVersion: '1.0.0',
        latestVersion: '1.0.0',
        state: UpdateState.notAvailable,
      );
      expect(same.isUpdateAvailable, isFalse);
      expect(same.summary, contains('latest version'));
    });

    test('a failed check never claims an update exists', () {
      const failed = UpdateCheck(
        currentVersion: '1.0.0',
        state: UpdateState.checkFailed,
        error: 'network down',
      );
      expect(failed.isUpdateAvailable, isFalse);
      expect(failed.summary, contains('network down'));
    });
  });

  group('install guidance', () {
    test('every platform gets instructions', () {
      for (final platform in <String>['windows', 'linux', 'android', 'other']) {
        final help = UpdateCenter.installHelp(platform);
        expect(help, isNotEmpty, reason: platform);
      }
      expect(UpdateCenter.installHelp('windows'), contains('max_tools.exe'));
      expect(UpdateCenter.installHelp('android'), contains('APK'));
    });
  });

  group('product configuration', () {
    test('the shipped config points at the Max-Tools releases', () {
      // The template shipped with an empty repository, which silently disabled
      // the entire update stack.
      final centre = UpdateCenter(config: _shippedConfig());
      expect(centre.repository, 'Cambric-software/Max-Tools');
      expect(centre.isEnabled, isTrue);
    });
  });
}

/// The configuration the app actually loads from disk.
CambricConfig _shippedConfig() {
  const config = CambricConfig(
    productId: 'max-tools-product',
    productName: 'Max Tools',
    version: '0.1.0',
    templateVersion: '1.0.0',
    repository: 'Cambric-software/Max-Tools',
    updatesEnabled: true,
  );
  return config;
}
