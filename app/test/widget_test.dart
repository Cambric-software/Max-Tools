import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:max_tools/main.dart';
import 'package:max_tools/core/config/cambric_config.dart';
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
      CambricTemplateApp(
        config: config,
        existingProducts: const <Map<String, dynamic>>[],
        variables: VariableStore(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('App renders with config', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('Test App'), findsOneWidget);
  });

  testWidgets('opens on the home screen, not a wizard', (WidgetTester tester) async {
    await pumpApp(tester);
    // The template's blocking setup button is gone: the product opens on the
    // home screen, with setup available as a card.
    expect(find.text('Open Cambric Setup'), findsNothing);
    // "Max Tools" appears in the app bar and the hero card.
    expect(find.text('Max Tools'), findsWidgets);
  });

  testWidgets('home screen exposes the main entry points',
      (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Command Palette'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Cambric Setup'), findsOneWidget);
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
}
