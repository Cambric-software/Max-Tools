import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/features/tools/apps/file_encryption_tool.dart';

/// Tests for the encryption format, not just the screen.
///
/// The low iteration count keeps the tests quick; the shipped default is
/// 210,000 and is asserted separately.
void main() {
  const password = 'a long enough password';
  final clear = Uint8List.fromList(utf8.encode('the secret plans'));

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  test('round-trips a file', () async {
    final sealed = await encryptFileBytes(clear, password, iterations: 1000);
    expect(sealed, isNot(equals(clear)));
    expect(sealed.length, greaterThan(clear.length));
    // The ciphertext must not accidentally contain the plaintext.
    expect(
      String.fromCharCodes(sealed).contains('the secret plans'),
      isFalse,
    );

    final opened = await decryptFileBytes(sealed, password);
    expect(opened, equals(clear));
  });

  test('a wrong password is refused', () async {
    final sealed = await encryptFileBytes(clear, password, iterations: 1000);
    await expectLater(
      decryptFileBytes(sealed, 'a different password'),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('tampering is refused rather than silently accepted', () async {
    final sealed = await encryptFileBytes(clear, password, iterations: 1000);
    sealed[sealed.length - 1] ^= 0x01;
    await expectLater(
      decryptFileBytes(sealed, password),
      throwsA(isA<WrongPasswordException>()),
    );
  });

  test('a foreign file is reported, not guessed at', () async {
    await expectLater(
      decryptFileBytes(Uint8List.fromList(<int>[1, 2, 3, 4, 5]), password),
      throwsA(isA<FormatException>()),
    );
    final notMine = Uint8List.fromList(<int>[...List<int>.filled(64, 7)]);
    await expectLater(
      decryptFileBytes(notMine, password),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('the screen refuses an empty path', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: FileEncryptionTool()));
    await tester.pump();
    await tapButton(tester, 'Encrypt the file');
    expect(find.textContaining('Choose a file first'), findsOneWidget);
  });

  testWidgets('encryption requires a confirmed password of real length',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: FileEncryptionTool()));
    await tester.pump();

    // Validation happens before the file is touched, so a placeholder path is
    // enough to test the password rules.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'C:\\not-a-real-file.txt');
    await tester.enterText(fields.at(1), 'short');
    await tester.enterText(fields.at(2), 'short');
    await tapButton(tester, 'Encrypt the file');
    expect(find.textContaining('at least 10 characters'), findsOneWidget);

    await tester.enterText(fields.at(1), password);
    await tester.enterText(fields.at(2), 'not the same');
    await tapButton(tester, 'Encrypt the file');
    expect(find.textContaining('do not match'), findsOneWidget);
  });
}
