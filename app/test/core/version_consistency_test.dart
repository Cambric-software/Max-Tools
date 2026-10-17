import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/core/config/cambric_config.dart';

/// Guards the version numbers that have to agree across the project.
///
/// The update system compares the running version against the published git
/// tag, so a mismatch here is not cosmetic: an app that reports 1.0.0 while
/// the newest tag is v0.1.0 would conclude it is already up to date and never
/// offer an update again.
void main() {
  late Map<String, dynamic> shippedConfig;
  late Map<String, dynamic> appManifest;
  late String pubspecVersion;

  setUpAll(() {
    shippedConfig = jsonDecode(
      File('lib/core/config/cambric_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    appManifest = jsonDecode(
      File('cambric.manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final pubspec = File('pubspec.yaml').readAsStringSync();
    pubspecVersion = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1)!;
  });

  test('pubspec carries the release version', () {
    // "0.1.0+1": the part before the build number is the release version.
    expect(pubspecVersion, startsWith('0.1.0'));
  });

  test('the shipped config reports the release version, not the template one',
      () {
    final product = shippedConfig['product'] as Map<String, dynamic>;
    expect(product['version'], pubspecVersion.split('+').first);
    // templateVersion is a separate concern and legitimately stays at 1.0.0.
    expect(product['templateVersion'], isNot(product['version']));
  });

  test('the app manifest reports the same version', () {
    expect(appManifest['version'], pubspecVersion.split('+').first);
  });

  test('the app manifest carries the Max Tools identity', () {
    expect(appManifest['productId'], 'max-tools-product');
    expect(appManifest['name'], 'Max Tools');
  });

  test('the release repository is configured so updates can be found', () {
    final release = shippedConfig['release'] as Map<String, dynamic>;
    expect(release['repository'], 'Cambric-software/Max-Tools');
    expect(release['provider'], 'github');
  });

  test('loading the shipped config produces those same values', () async {
    final config = await CambricConfig.load('lib/core/config/cambric_config.json');
    expect(config.version, pubspecVersion.split('+').first);
    expect(config.productName, 'Max Tools');
    expect(config.repository, 'Cambric-software/Max-Tools');
    expect(config.updatesEnabled, isTrue);
  });

  test('the config falls back to the product name rather than the template',
      () {
    // The fallback matters: it is what shows if the config file cannot load.
    final source = File('lib/core/config/cambric_config.dart').readAsStringSync();
    expect(source.contains("'Cambric App Product'"), isFalse);
    expect(source.contains("'Max Tools'"), isTrue);
  });
}