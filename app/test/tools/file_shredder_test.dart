import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/tools/apps/file_shredder_tool.dart';

/// Behaviour tests for the file shredder.
///
/// These use real temporary files, because the whole point of the tool is what
/// happens to a real file. Every test cleans up its own directory.
void main() {
  late Directory temp;
  late File file;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('max_tools_shred_');
    file = File('${temp.path}${Platform.pathSeparator}secret.txt');
    await file.writeAsString('sensitive contents');
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FileShredderTool()));
    await tester.pump();
  }

  /// Lets a real file-system read finish. Widget tests run in a fake async
  /// zone, so `File.length()` does not complete until the real loop is given a
  /// turn.
  Future<void> settleIo(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('refuses to run with no file chosen', (tester) async {
    await open(tester);
    await tester.tap(find.text('Shred the file'));
    await tester.pump();
    expect(find.text('Choose a file first.'), findsOneWidget);
    expect(find.text('Shred this file?'), findsNothing);
  });

  testWidgets('needs the typed word before it will confirm', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, file.path);
    await tester.tap(find.text('Shred the file'));
    await settleIo(tester);

    expect(find.text('Shred this file?'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Shred file');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'delete',
    );
    await tester.pump();
    // Lower case is accepted, because the check is about intent, not typing.
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(file.existsSync(), isTrue);
  });

  test('overwrites and deletes a real file', () async {
    // The file is longer than the 64KB write chunk, so the loop is exercised.
    final bytes = List<int>.generate(200000, (int index) => index % 251);
    await file.writeAsBytes(bytes);

    final passes = <int>[];
    await shredFile(
      file,
      passes: 2,
      onPass: (int pass, int total) => passes.add(pass),
    );

    expect(file.existsSync(), isFalse);
    expect(temp.listSync(), isEmpty);
    expect(passes, <int>[1, 2]);
  });

  testWidgets('refuses a folder rather than pretending', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, temp.path);
    await tester.tap(find.text('Shred the file'));
    await tester.pump();

    expect(find.textContaining('That is a folder'), findsOneWidget);
    expect(find.text('Shred this file?'), findsNothing);
  });
}
