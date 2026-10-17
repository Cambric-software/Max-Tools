import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/screens/palette/command_palette_screen.dart';
import 'package:max_tools/tools/catalog/tool_catalog.dart';
import 'package:max_tools/tools/tools_scope.dart';
import 'package:max_tools/tools/variable_store.dart';

void main() {
  late VariableStore variables;

  setUp(() {
    variables = VariableStore();
  });

  Future<void> pumpPalette(WidgetTester tester) async {
    final registry = buildDefaultRegistry();
    await tester.pumpWidget(
      MaterialApp(
        home: ToolsScope(
          registry: registry,
          variables: variables,
          child: const Scaffold(body: CommandPaletteDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pumpAndSettle();
  }

  group('empty state', () {
    testWidgets('shows guidance before anything is typed', (tester) async {
      await pumpPalette(tester);
      expect(find.textContaining('Type a request in plain English'),
          findsOneWidget);
      expect(find.textContaining('hash my password'), findsOneWidget);
    });

    testWidgets('lists existing variables as chips', (tester) async {
      variables.set('total', value: 42, type: VariableType.number);
      await pumpPalette(tester);
      expect(find.text(r'$total'), findsOneWidget);
    });

    testWidgets('a variable chip can be deleted', (tester) async {
      variables.set('total', value: 42, type: VariableType.number);
      await pumpPalette(tester);
      await tester.tap(find.byIcon(Icons.cancel));
      await tester.pumpAndSettle();
      expect(variables.has('total'), isFalse);
    });
  });

  group('understanding', () {
    testWidgets('shows the best match with its confidence', (tester) async {
      await pumpPalette(tester);
      await type(tester, 'hash my password');
      expect(find.text('Hash Text'), findsOneWidget);
      expect(find.textContaining('security.hash'), findsOneWidget);
      expect(find.textContaining('matched on'), findsOneWidget);
    });

    testWidgets('offers alternatives when more than one tool matches',
        (tester) async {
      await pumpPalette(tester);
      await type(tester, 'json');
      expect(find.text('Other matches'), findsOneWidget);
    });

    testWidgets('flags an ambiguous sentence instead of claiming certainty',
        (tester) async {
      await pumpPalette(tester);
      await type(tester, 'convert');
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('shows a did-you-mean note for a typo', (tester) async {
      await pumpPalette(tester);
      await type(tester, 'parse cvs teh');
      expect(find.textContaining('Did you mean'), findsOneWidget);
    });

    testWidgets('asks for missing required input', (tester) async {
      await pumpPalette(tester);
      await type(tester, 'list files');
      // 'path' has no value, so the palette must prompt rather than run.
      expect(find.widgetWithText(TextField, 'path'), findsOneWidget);
    });
  });

  group('running', () {
    testWidgets('runs a tool and shows the result', (tester) async {
      await pumpPalette(tester);
      await type(tester, 'hash abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      expect(find.text('Result'), findsOneWidget);
      expect(find.textContaining('ba7816bf'), findsOneWidget);
    });

    testWidgets('shows a failure without crashing', (tester) async {
      await pumpPalette(tester);
      await type(tester, 'checksum file in /definitely/not/here.txt');
      // The tool touches the real filesystem, which does not complete under
      // the test binding's fake clock, so the run is awaited for real.
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Run'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text('Failed'), findsOneWidget);
      expect(find.textContaining('File not found'), findsOneWidget);
    });

    testWidgets('a result can be saved as a variable', (tester) async {
      await pumpPalette(tester);
      await type(tester, 'hash abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save as variable'));
      await tester.pumpAndSettle();
      expect(variables.names(), isNotEmpty);
      expect(variables.get('result')?.value, isNotNull);
    });

    testWidgets('a saved variable is listed for reuse', (tester) async {
      await pumpPalette(tester);
      await type(tester, 'hash abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save as variable'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      expect(find.text(r'$result'), findsOneWidget);
    });
  });

  group('history', () {
    testWidgets('a run is remembered and can be replayed', (tester) async {
      await pumpPalette(tester);
      await type(tester, 'hash abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('hash abc'), findsOneWidget);
    });
  });
}
