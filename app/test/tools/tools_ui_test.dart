import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/features/screens/tools/tool_runner_screen.dart';
import 'package:max_tools/features/screens/tools/tools_screen.dart';
import 'package:max_tools/features/tools/tool_descriptor.dart';
import 'package:max_tools/features/tools/tool_registry.dart';
import 'package:max_tools/features/tools/tools_scope.dart';

import '../support/fixture_registry.dart';

/// Browser and runner behaviour, exercised against the fixture catalog.
void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = buildFixtureRegistry();
  });

  Future<void> pumpTools(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ToolsScope(
          registry: registry,
          child: const ToolsScreen(),
        ),
      ),
    );
  }

  group('ToolsScope', () {
    testWidgets('provides the registry to descendants', (tester) async {
      ToolRegistry? seen;
      await tester.pumpWidget(
        ToolsScope(
          registry: registry,
          child: Builder(
            builder: (context) {
              seen = ToolsScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, same(registry));
    });

    testWidgets('throws a readable error without a scope', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            ToolsScope.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(tester.takeException(), isFlutterError);
    });
  });

  group('ToolsScreen', () {
    testWidgets('lists every registered tool', (tester) async {
      await pumpTools(tester);
      expect(find.text('Tools (${registry.length})'), findsOneWidget);
      expect(find.text(registry.all().first.name), findsOneWidget);
    });

    testWidgets('search reaches tools below the fold', (tester) async {
      await pumpTools(tester);
      final last = registry.all().last;
      await tester.enterText(find.byType(TextField).first, last.name);
      await tester.pumpAndSettle();
      // FindsWidgets: the typed query itself also matches by text.
      expect(find.text(last.name), findsWidgets);
      expect(find.text(registry.all().first.name), findsNothing);
    });

    testWidgets('search filters the list', (tester) async {
      await pumpTools(tester);
      await tester.enterText(find.byType(TextField).first, 'csv');
      await tester.pumpAndSettle();
      expect(find.text('Parse CSV'), findsOneWidget);
      expect(find.text('Format JSON'), findsNothing);
    });

    testWidgets('search with no matches shows an empty message',
        (tester) async {
      await pumpTools(tester);
      await tester.enterText(find.byType(TextField).first, 'zzzznothing');
      await tester.pumpAndSettle();
      expect(find.text('No tools match that search.'), findsOneWidget);
    });

    testWidgets('category filter narrows to one category', (tester) async {
      await pumpTools(tester);
      final securityCount = registry.byCategory(ToolCategory.security).length;
      await tester.tap(
        find.widgetWithText(FilterChip, 'Security ($securityCount)'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hash Text'), findsOneWidget);
      expect(find.text('Parse CSV'), findsNothing);
    });

    testWidgets('a tool with its own screen opens that screen', (tester) async {
      registry.register(
        ToolDescriptor(
          id: 'test.screenTool',
          name: 'Screen Tool',
          description: 'has its own screen',
          category: ToolCategory.everyday,
          run: (_) async => const ToolResult.success('unused'),
          screen: (_) => const Scaffold(body: Text('Screened')),
        ),
      );
      await pumpTools(tester);
      await tester.enterText(find.byType(TextField).first, 'Screen Tool');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Screen Tool'));
      await tester.pumpAndSettle();
      expect(find.text('Screened'), findsOneWidget);
      expect(find.byType(ToolRunnerScreen), findsNothing);
    });
  });

  group('ToolRunnerScreen', () {
    Future<void> pumpRunner(WidgetTester tester, String toolId) async {
      final tool = registry.find(toolId)!;
      await tester.pumpWidget(
        MaterialApp(
          home: ToolsScope(
            registry: registry,
            child: ToolRunnerScreen(tool: tool, registry: registry),
          ),
        ),
      );
    }

    testWidgets('shows the tool name, id and description', (tester) async {
      await pumpRunner(tester, 'data.csv.parse');
      expect(find.text('Parse CSV'), findsOneWidget);
      expect(find.text('data.csv.parse'), findsOneWidget);
    });

    testWidgets('builds one field per declared parameter', (tester) async {
      await pumpRunner(tester, 'data.json.format');
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('running a tool shows its result', (tester) async {
      await pumpRunner(tester, 'security.hash');
      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      expect(find.text('Result'), findsOneWidget);
    });

    testWidgets('a failing tool shows the failure, not a crash',
        (tester) async {
      registry.register(
        ToolDescriptor(
          id: 'test.fails',
          name: 'Always fails',
          description: 'returns a failure result',
          category: ToolCategory.developer,
          run: (_) async => const ToolResult.failure('nope'),
        ),
      );
      await pumpRunner(tester, 'test.fails');
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('nope'), findsOneWidget);
    });

    testWidgets('missing required input surfaces the registry error',
        (tester) async {
      await pumpRunner(tester, 'security.hash');
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      expect(find.text('Failed'), findsOneWidget);
      // The registry's message is surfaced verbatim, not reworded by the UI.
      expect(find.textContaining('required parameter'), findsOneWidget);
    });

    testWidgets('a write tool is flagged as changing data', (tester) async {
      registry.register(
        ToolDescriptor(
          id: 'test.writes',
          name: 'Writes',
          description: 'modifies state',
          category: ToolCategory.file,
          readOnly: false,
          run: (_) async => const ToolResult.success('done'),
        ),
      );
      await pumpRunner(tester, 'test.writes');
      expect(find.text('This tool changes data.'), findsOneWidget);
    });
  });
}
