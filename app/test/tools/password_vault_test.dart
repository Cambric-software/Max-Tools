import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/features/tools/apps/password_vault_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Behaviour tests for the encrypted vault.
///
/// PBKDF2 deliberately costs real time, so each step that derives a key is
/// given a real-time turn with `runAsync` instead of being driven by the fake
/// clock.
void main() {
  const password = 'correct horse battery staple';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    // PBKDF2 pauses for one millisecond every 2,000 rounds to let the event
    // loop breathe. Advancing the fake clock runs those pauses without making
    // the test wait in real time.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PasswordVaultTool()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> createVault(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), password);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.tap(find.text('Create vault'));
    await settle(tester);
  }

  testWidgets('creates a vault, stores an entry encrypted, locks and unlocks',
      (tester) async {
    await open(tester);
    expect(find.text('Create your vault'), findsOneWidget);

    await createVault(tester);
    expect(find.text('Add entry'), findsOneWidget);

    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Workshop wifi');
    await tester.enterText(fields.at(1), 'asser');
    await tester.enterText(fields.at(2), 'hunter2-but-longer');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('Workshop wifi'), findsOneWidget);

    // The stored blob must not contain the plaintext.
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('max_tools.vault.v1') ?? '';
    expect(stored, isNotEmpty);
    expect(stored, isNot(contains('Workshop wifi')));
    expect(stored, isNot(contains('hunter2')));

    // Lock, fail once, then unlock.
    await tester.tap(find.byTooltip('Lock the vault'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Unlock'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'wrong password');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await settle(tester);
    expect(find.textContaining('did not unlock'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await settle(tester);
    expect(find.text('Workshop wifi'), findsOneWidget);
  });

  testWidgets('a new instance asks for the password and reads the entries',
      (tester) async {
    await open(tester);
    await createVault(tester);

    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Bank');
    await tester.enterText(fields.at(2), 'secret');
    await tester.tap(find.text('Save'));
    await settle(tester);

    // Replace the whole widget, as a restart would.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: PasswordVaultTool()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.widgetWithText(FilledButton, 'Unlock'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await settle(tester);

    expect(find.text('Bank'), findsOneWidget);
  });

  testWidgets('refuses a short or mismatched master password', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField).at(0), 'short');
    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.tap(find.text('Create vault'));
    await tester.pump();
    expect(find.textContaining('at least 10 characters'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), password);
    await tester.enterText(find.byType(TextField).at(1), 'something else');
    await tester.tap(find.text('Create vault'));
    await tester.pump();
    expect(find.textContaining('do not match'), findsOneWidget);
    expect(find.text('Create your vault'), findsOneWidget);
  });
}
