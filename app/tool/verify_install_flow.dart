// End-to-end check of the installer against a REAL published release zip.
// Run with: dart run tool/verify_install_flow.dart <zip> <installRoot>
import 'dart:io';

import 'package:max_tools/core/updates/install_layout.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: verify_install_flow.dart <package.zip> <exePath>');
    exit(2);
  }
  final package = File(args[0]);
  final layout = InstallLayout.detect(executablePath: args[1]);
  final installer = UpdateInstaller(layout);

  stdout.writeln('layout versioned : ${layout.isVersioned}');
  stdout.writeln('running version  : ${layout.runningVersion}');
  stdout.writeln('active version   : ${layout.activeVersion}');
  if (!layout.isVersioned) {
    stderr.writeln('NOT a versioned install - cannot test');
    exit(1);
  }

  final staged = await installer.stage(package: package, version: '0.9.9');
  stdout.writeln('stage 0.9.9      : ok=${staged.ok} ${staged.message ?? ''}');
  stdout.writeln('active now       : ${layout.activeVersion}');
  stdout.writeln(
    'exe present      : ${await layout.executableFor("0.9.9").exists()}',
  );
  stdout.writeln('installed list   : ${await installer.installedVersions()}');

  final rolled = await installer.rollbackTo('0.1.0');
  stdout.writeln('rollback to 0.1.0: ok=${rolled.ok} ${rolled.message ?? ''}');
  stdout.writeln('active now       : ${layout.activeVersion}');

  final removed = await installer.prune();
  stdout.writeln('pruned           : $removed version(s)');
  stdout.writeln('installed list   : ${await installer.installedVersions()}');

  final ok = staged.ok && rolled.ok && layout.activeVersion == '0.1.0';
  stdout.writeln(ok ? 'RESULT: PASS' : 'RESULT: FAIL');
  exit(ok ? 0 : 1);
}