import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:max_tools/core/config/cambric_config.dart';
import 'package:max_tools/main.dart';
import 'package:max_tools/tools/variable_store.dart';

void main() {
  const config = CambricConfig(
    productId: 'test-product',
    productName: 'Test App',
    version: '1.0.0',
    templateVersion: '1.0.0',
  );

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaxToolsApp(
        config: config,
        existingProducts: const <Map<String, dynamic>>[],
        variables: VariableStore(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('App renders with config', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('Test App'), findsWidgets);
  });

  testWidgets('opens on the home screen, not a wizard',
      (WidgetTester tester) async {
    await pumpApp(tester);
    // The template's blocking setup button is gone: the product opens on the
    // home screen, with everything setup used to collect on the Cambric screen.
    expect(find.text('Open Cambric Setup'), findsNothing);
    expect(find.text('Test App'), findsWidgets);
  });

  testWidgets('home screen exposes only entry points that do something',
      (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Command Palette'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Cambric'), findsOneWidget);
    // The dead template card is gone.
    expect(find.text('Cambric Setup'), findsNothing);
  });

  testWidgets('the command palette opens from the app bar',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.bolt_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('What do you want to do?'), findsOneWidget);
  });

  testWidgets('the tools screen opens', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Tools'));
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Tools ('), findsOneWidget);
  });

  testWidgets('the updates screen opens', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    expect(find.text('Installed version'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
  });

  testWidgets('the Cambric card opens a real screen, not a wizard dialog',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Cambric'));
    await tester.tap(find.text('Cambric'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // It is a route, with its own app bar and content.
    expect(find.text('This installation'), findsOneWidget);
    expect(find.text('test-product'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.textContaining('Copyright © 2026 Cambric Software'),
        findsWidgets);
  });

  testWidgets('settings describes the product, not a template',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Cambric application template'), findsNothing);
    expect(find.textContaining('Copyright © 2026 Cambric Software'),
        findsWidgets);
  });

  testWidgets('the theme choice applies immediately',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
