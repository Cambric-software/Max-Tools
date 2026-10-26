import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/core/updates/install_layout.dart';

void main() {
  late Directory temp;
  late Directory root;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('maxtools_install_test');
    root = Directory('${temp.path}${Platform.pathSeparator}MaxTools');
    await Directory(
      '${root.path}${Platform.pathSeparator}versions${Platform.pathSeparator}0.1.0',
    ).create(recursive: true);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  /// Build a fake installed version containing a runnable executable.
  Future<File> makeVersion(String version, {bool withExe = true}) async {
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}versions${Platform.pathSeparator}$version',
    );
    await dir.create(recursive: true);
    File exe;
    if (withExe) {
      exe = File(
        '${dir.path}${Platform.pathSeparator}${InstallLayout.executableName}',
      );
      await exe.writeAsString('binary');
    } else {
      exe = File('${dir.path}${Platform.pathSeparator}nothing.txt');
      await exe.writeAsString('x');
    }
    final data = Directory('${dir.path}${Platform.pathSeparator}data');
    await data.create();
    await File('${data.path}${Platform.pathSeparator}app.dat').writeAsString('{}');
    return exe;
  }

  /// Package shaped like a real release zip: the executable at the root.
  Future<File> makePackage({String name = 'release.zip', bool withExe = true}) async {
    final staging = Directory('${temp.path}${Platform.pathSeparator}staging_$name');
    await staging.create(recursive: true);
    if (withExe) {
      await File(
        '${staging.path}${Platform.pathSeparator}${InstallLayout.executableName}',
      ).writeAsString('binary');
    }
    final pkg = File('${temp.path}${Platform.pathSeparator}$name');
    if (await pkg.exists()) await pkg.delete();
    final result = await Process.run(
      'tar',
      <String>['-a', '-cf', pkg.path, '-C', staging.path, '.'],
    );
    expect(result.exitCode, 0, reason: 'tar failed: ${result.stderr}');
    return pkg;
  }

  InstallLayout layout() => InstallLayout.detect(
        executablePath:
            '${root.path}${Platform.pathSeparator}versions'
            '${Platform.pathSeparator}0.1.0'
            '${Platform.pathSeparator}${InstallLayout.executableName}',
      );

  group('layout detection', () {
    test('recognises a versioned install', () {
      final detected = layout();
      expect(detected.isVersioned, isTrue);
      expect(detected.runningVersion, '0.1.0');
      expect(
        detected.versionsDirectory.path,
        endsWith('${Platform.pathSeparator}versions'),
      );
    });

    test('a flat layout is reported as unversioned, not as an error', () {
      final flat = InstallLayout.detect(
        executablePath:
            '${temp.path}${Platform.pathSeparator}loose${Platform.pathSeparator}max_tools.exe',
      );
      expect(flat.isVersioned, isFalse);
    });

    test('activeVersion is null before anything is activated', () {
      expect(layout().activeVersion, isNull);
    });
  });

  group('staging an update', () {
    test('extracts a package and makes it the active version', () async {
      final installer = UpdateInstaller(layout());
      final package = await makePackage();

      final outcome = await installer.stage(package: package, version: '0.2.0');

      expect(outcome.ok, isTrue, reason: outcome.message);
      expect(outcome.version, '0.2.0');
      expect(layout().activeVersion, '0.2.0');
      expect(
        await layout().executableFor('0.2.0').exists(),
        isTrue,
        reason: 'the new version must contain a runnable executable',
      );
    });

    test('the previous version is reported so rollback stays possible',
        () async {
      final installer = UpdateInstaller(layout());
      await makeVersion('0.1.0');
      await installer.activateVersion('0.1.0');
      final package = await makePackage();

      final outcome = await installer.stage(package: package, version: '0.2.0');

      expect(outcome.previousVersion, '0.1.0');
      // The old version is still on disk, untouched.
      expect(await layout().executableFor('0.1.0').exists(), isTrue);
    });

    test('an update never touches the version that is running', () async {
      final runningExe = await makeVersion('0.1.0');
      await makeVersion('0.1.0');
      final before = await runningExe.readAsString();
      final installer = UpdateInstaller(layout());
      await installer.activateVersion('0.1.0');

      await installer.stage(package: await makePackage(), version: '0.2.0');

      // The file Windows has locked open is byte-for-byte unchanged.
      expect(await runningExe.readAsString(), before);
      expect(await runningExe.exists(), isTrue);
    });

    test('a package without the executable is rejected and changes nothing',
        () async {
      final installer = UpdateInstaller(layout());
      await makeVersion('0.1.0');
      await installer.activateVersion('0.1.0');

      final outcome = await installer.stage(
        package: await makePackage(withExe: false),
        version: '0.2.0',
      );

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains(InstallLayout.executableName));
      // The pointer must not have moved to a broken version.
      expect(layout().activeVersion, '0.1.0');
      expect(await layout().versionDirectory('0.2.0').exists(), isFalse);
    });

    test('a corrupt package leaves the pointer alone', () async {
      final installer = UpdateInstaller(layout());
      await makeVersion('0.1.0');
      await installer.activateVersion('0.1.0');
      final junk = File('${temp.path}${Platform.pathSeparator}junk.zip');
      await junk.writeAsString('this is not a zip file');

      final outcome = await installer.stage(package: junk, version: '0.2.0');

      expect(outcome.ok, isFalse);
      expect(layout().activeVersion, '0.1.0');
    });

    test('a missing package fails cleanly', () async {
      final installer = UpdateInstaller(layout());
      final outcome = await installer.stage(
        package: File('${temp.path}${Platform.pathSeparator}ghost.zip'),
        version: '0.2.0',
      );
      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('missing'));
    });

    test('an empty version string is rejected', () async {
      final installer = UpdateInstaller(layout());
      final outcome = await installer.stage(
        package: await makePackage(),
        version: '  ',
      );
      expect(outcome.ok, isFalse);
    });

    test('staging without activating leaves the pointer where it was',
        () async {
      final installer = UpdateInstaller(layout());
      await makeVersion('0.1.0');
      await installer.activateVersion('0.1.0');

      final outcome = await installer.stage(
        package: await makePackage(),
        version: '0.2.0',
        activate: false,
      );

      expect(outcome.ok, isTrue);
      expect(layout().activeVersion, '0.1.0');
      expect(await layout().executableFor('0.2.0').exists(), isTrue);
    });

    test('re-staging over a broken previous attempt succeeds', () async {
      final installer = UpdateInstaller(layout());
      final broken = layout().versionDirectory('0.2.0');
      await broken.create(recursive: true);
      await File('${broken.path}${Platform.pathSeparator}junk.txt')
          .writeAsString('leftover');

      final outcome = await installer.stage(
        package: await makePackage(),
        version: '0.2.0',
      );

      expect(outcome.ok, isTrue, reason: outcome.message);
      expect(await File('${broken.path}${Platform.pathSeparator}junk.txt').exists(),
          isFalse);
    });

    test('a flat install refuses to self-update instead of corrupting itself',
        () async {
      final flat = InstallLayout.detect(
        executablePath:
            '${temp.path}${Platform.pathSeparator}loose${Platform.pathSeparator}max_tools.exe',
      );
      final installer = UpdateInstaller(flat);
      final outcome = await installer.stage(
        package: await makePackage(),
        version: '0.2.0',
      );
      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('versioned install'));
    });
  });

  group('rollback', () {
    test('pointing back at the old version restores it', () async {
      await makeVersion('0.1.0');
      final installer = UpdateInstaller(layout());
      await installer.activateVersion('0.1.0');
      await installer.stage(package: await makePackage(), version: '0.2.0');
      expect(layout().activeVersion, '0.2.0');

      final outcome = await installer.rollbackTo('0.1.0');

      expect(outcome.ok, isTrue);
      expect(layout().activeVersion, '0.1.0');
    });

    test('rolling back to a version that is not installed fails safely',
        () async {
      final installer = UpdateInstaller(layout());
      await makeVersion('0.1.0');
      await installer.activateVersion('0.1.0');

      final outcome = await installer.rollbackTo('9.9.9');

      expect(outcome.ok, isFalse);
      expect(layout().activeVersion, '0.1.0', reason: 'pointer must not move');
    });

    test('rolling back to the current version is a no-op success', () async {
      await makeVersion('0.1.0');
      final installer = UpdateInstaller(layout());
      await installer.activateVersion('0.1.0');
      final outcome = await installer.rollbackTo('0.1.0');
      expect(outcome.ok, isTrue);
    });
  });

  group('pruning', () {
    test('keeps the active version and one other for rollback', () async {
      for (final v in ['0.1.0', '0.2.0', '0.3.0', '0.4.0']) {
        await makeVersion(v);
      }
      final installer = UpdateInstaller(layout());
      await installer.activateVersion('0.4.0');

      final removed = await installer.prune();

      expect(removed, 2);
      final left = await installer.installedVersions();
      expect(left, containsAll(<String>['0.4.0', '0.3.0']));
      expect(left, isNot(contains('0.1.0')));
      expect(left, isNot(contains('0.2.0')));
    });

    test('never prunes the version being kept', () async {
      await makeVersion('0.1.0');
      await makeVersion('0.2.0');
      final installer = UpdateInstaller(layout());
      await installer.prune(keep: '0.1.0');
      expect(await layout().executableFor('0.1.0').exists(), isTrue);
    });

    test('pruning a flat install does nothing', () async {
      final flat = InstallLayout.detect(
        executablePath:
            '${temp.path}${Platform.pathSeparator}loose${Platform.pathSeparator}max_tools.exe',
      );
      expect(await UpdateInstaller(flat).prune(), 0);
    });
  });

  group('listing', () {
    test('lists only versions that contain an executable', () async {
      await makeVersion('0.1.0');
      await makeVersion('0.2.0');
      // A directory with no executable is a failed attempt, not a version.
      await Directory(
        '${root.path}${Platform.pathSeparator}versions${Platform.pathSeparator}0.9.0',
      ).create(recursive: true);

      final versions = await UpdateInstaller(layout()).installedVersions();

      expect(versions, containsAll(<String>['0.1.0', '0.2.0']));
      expect(versions, isNot(contains('0.9.0')));
    });
  });

  group('pending update breadcrumb', () {
    test('round-trips and clears', () async {
      final dir = Directory('${temp.path}${Platform.pathSeparator}state');
      await dir.create();

      expect(await readPendingUpdate(dir), isNull);

      await writePendingUpdate(dir, '0.2.0');
      final pending = await readPendingUpdate(dir);
      expect(pending?['version'], '0.2.0');

      await clearPendingUpdate(dir);
      expect(await readPendingUpdate(dir), isNull);
    });

    test('a corrupt breadcrumb does not throw', () async {
      final dir = Directory('${temp.path}${Platform.pathSeparator}state2');
      await dir.create();
      await File('${dir.path}${Platform.pathSeparator}pending_update.json')
          .writeAsString('{not json');
      expect(await readPendingUpdate(dir), isNull);
    });
  });

  group('handoff', () {
    test('does nothing when the pointer matches the running version',
        () async {
      await makeVersion('0.1.0');
      final installer = UpdateInstaller(layout());
      await installer.activateVersion('0.1.0');

      expect(await handoff(layout: layout()), HandoffAction.none);
    });

    test('does nothing when there is no pointer yet', () async {
      expect(await handoff(layout: layout()), HandoffAction.none);
    });

    test('does nothing for a flat install', () async {
      final flat = InstallLayout.detect(
        executablePath:
            '${temp.path}${Platform.pathSeparator}loose${Platform.pathSeparator}max_tools.exe',
      );
      expect(await handoff(layout: flat), HandoffAction.none);
    });

    test('does nothing when the pointer names a version that is not installed',
        () async {
      await makeVersion('0.1.0');
      final installer = UpdateInstaller(layout());
      await installer.activateVersion('0.1.0');
      await installer.activateVersion('0.2.0'); // pointer moves, no such dir

      expect(await handoff(layout: layout()), HandoffAction.none);
    });
  });
}