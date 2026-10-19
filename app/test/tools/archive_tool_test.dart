import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/tools/apps/archive_tool.dart';

/// Tests for zipping and extracting against real temporary directories.
void main() {
  late Directory base;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('max_tools_zip_');
  });

  tearDown(() async {
    if (base.existsSync()) await base.delete(recursive: true);
  });

  test('zips a folder and extracts it back with its structure', () async {
    final folder = Directory('${base.path}${Platform.pathSeparator}notes')
      ..createSync();
    File('${folder.path}${Platform.pathSeparator}one.txt')
        .writeAsStringSync('first');
    Directory('${folder.path}${Platform.pathSeparator}inside').createSync();
    File(
      '${folder.path}${Platform.pathSeparator}inside'
      '${Platform.pathSeparator}two.txt',
    ).writeAsStringSync('second');

    final files = folder
        .listSync(recursive: true)
        .whereType<File>()
        .map((File file) => file.path)
        .toList();
    final zipped = await zipPaths(files, base.path);

    final archive = ZipDecoder().decodeBytes(zipped);
    final names = archive.files.map((ArchiveFile file) => file.name).toSet();
    expect(names, contains('notes/one.txt'));
    expect(names, contains('notes/inside/two.txt'));

    final destination = Directory('${base.path}${Platform.pathSeparator}out');
    final summary = await extractZip(zipped, destination.path);
    expect(summary.files, 2);
    expect(summary.skipped, 0);
    expect(
      File('${destination.path}${Platform.pathSeparator}notes'
              '${Platform.pathSeparator}one.txt')
          .readAsStringSync(),
      'first',
    );
    expect(
      File('${destination.path}${Platform.pathSeparator}notes'
              '${Platform.pathSeparator}inside'
              '${Platform.pathSeparator}two.txt')
          .readAsStringSync(),
      'second',
    );
  });

  test('refuses a name that tries to leave the destination', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          '../escaped.txt',
          utf8.encode('should not be written'),
        ),
      );
    final zipped = ZipEncoder().encodeBytes(archive);

    final destination = Directory('${base.path}${Platform.pathSeparator}out');
    final summary = await extractZip(zipped, destination.path);

    expect(summary.files, 0);
    expect(summary.skipped, 1);
    expect(summary.refused, contains('../escaped.txt'));
    expect(File('${base.path}${Platform.pathSeparator}escaped.txt').existsSync(),
        isFalse);
  });

  test('an absolute path is refused too', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          Platform.isWindows ? 'C:\\Windows\\evil.txt' : '/etc/evil.txt',
          Uint8List.fromList(<int>[1, 2, 3]),
        ),
      );
    final summary = await extractZip(
      ZipEncoder().encodeBytes(archive),
      '${base.path}${Platform.pathSeparator}out',
    );
    expect(summary.files, 0);
    expect(summary.skipped, 1);
  });

  testWidgets('the screen asks for a source first', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ArchiveTool()));
    await tester.pump();

    await tester.tap(find.text('Create the zip'));
    await tester.pump();
    expect(find.textContaining('Choose a file or folder'), findsOneWidget);

    // Switching to Extract reveals the destination controls.
    await tester.tap(find.text('Extract'));
    await tester.pumpAndSettle();
    expect(find.text('Extract into (optional)'), findsOneWidget);
    await tester.tap(find.text('Extract the zip'));
    await tester.pump();
    expect(find.textContaining('Choose a .zip file'), findsOneWidget);
  });
}
