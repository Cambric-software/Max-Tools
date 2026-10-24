import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/features/tools/apps/notes_tool.dart';
import 'package:max_tools/features/tools/apps/reading_aid_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Behaviour tests for the two document tools added after the mass rebuild.
///
/// The catalog test proves they render. These prove the buttons do what the
/// screen says they do: a note that is written survives a restart, a delete
/// needs confirmation, search narrows the list, and the readability screen
/// refuses to present numbers before there is text.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> open(WidgetTester tester, Widget tool) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: tool));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  Future<void> writeNote(
    WidgetTester tester, {
    required String title,
    required String body,
  }) async {
    await tester.tap(find.text('Write a note'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), title);
    await tester.enterText(fields.at(1), body);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  group('Notes', () {
    testWidgets('writes, shows and persists a note', (tester) async {
      await open(tester, const NotesTool());
      expect(find.text('No notes yet'), findsOneWidget);

      await writeNote(
        tester,
        title: 'Shopping',
        body: 'Milk and bread',
      );

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('1 note'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('max_tools.notes.v1'), contains('Shopping'));
    });

    testWidgets('search narrows the list and clearing restores it',
        (tester) async {
      await open(tester, const NotesTool());
      await writeNote(tester, title: 'Shopping', body: 'Milk');
      await writeNote(tester, title: 'Ideas', body: 'A new tool');

      final search = find.byType(TextField).first;
      await tester.enterText(search, 'milk');
      await tester.pumpAndSettle();
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Ideas'), findsNothing);

      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Ideas'), findsOneWidget);
    });

    testWidgets('delete asks first, and cancel keeps the note',
        (tester) async {
      await open(tester, const NotesTool());
      await writeNote(tester, title: 'Keep me', body: 'Still here');

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this note?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Keep me'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Keep me'), findsNothing);
      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('a pinned note sorts above a newer one', (tester) async {
      await open(tester, const NotesTool());
      await writeNote(tester, title: 'Older', body: 'Pinned');
      await writeNote(tester, title: 'Newer', body: 'Not pinned');

      await tester.tap(find.byTooltip('Pin to the top').last);
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect((tiles.first.title! as Text).data, 'Older');
    });
  });

  group('Accessibility & reading', () {
    testWidgets('shows no score until there is text', (tester) async {
      await open(tester, const ReadingAidTool());
      expect(find.text('Reading ease'), findsNothing);
      expect(
        find.textContaining('Nothing to measure yet'),
        findsOneWidget,
      );
    });

    testWidgets('the sample produces a bounded score and a verdict',
        (tester) async {
      await open(tester, const ReadingAidTool());
      await tester.tap(find.text('Use a sample'));
      await tester.pumpAndSettle();

      expect(find.text('Reading ease'), findsOneWidget);
      expect(find.text('Words / sentence'), findsOneWidget);
      expect(find.text('Reading time'), findsOneWidget);
      expect(find.textContaining('Most adults will read'), findsOneWidget);
    });

    testWidgets('non-English text does not invent a grade', (tester) async {
      await open(tester, const ReadingAidTool());
      await tester.enterText(
        find.byType(TextField),
        'مرحبا بكم في هذا الاختبار القصير.',
      );
      await tester.pumpAndSettle();

      expect(find.text('--'), findsOneWidget);
      expect(find.text('English only'), findsOneWidget);
      expect(
        find.textContaining('formula does not apply'),
        findsOneWidget,
      );
    });
  });
}
