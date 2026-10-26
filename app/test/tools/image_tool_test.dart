import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:max_tools/features/tools/apps/image_tool.dart';

/// Tests for the image pipeline, run against a generated image.
void main() {
  late Directory folder;
  late String path;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('max_tools_image_');
    final image = img.Image(width: 40, height: 20);
    img.fill(image, color: img.ColorRgb8(200, 30, 30));
    path = '${folder.path}${Platform.pathSeparator}sample.png';
    File(path).writeAsBytesSync(img.encodePng(image));
  });

  tearDown(() async {
    if (folder.existsSync()) await folder.delete(recursive: true);
  });

  test('resizes, keeps the aspect ratio, and converts to JPEG', () {
    final result = processImageFile(
      path,
      targetWidth: 20,
      format: 'jpg',
      quality: 80,
    );

    expect(result.width, 20);
    expect(result.height, 10);
    final decoded = img.decodeJpg(result.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 20);
  });

  test('keeps the size when no width is given', () {
    final result = processImageFile(
      path,
      format: 'png',
      quality: 80,
    );
    expect(result.width, 40);
    expect(result.height, 20);
    expect(img.decodePng(result.bytes)!.width, 40);
  });

  test('converts to WebP', () {
    final result = processImageFile(
      path,
      targetWidth: 10,
      format: 'webp',
      quality: 70,
    );
    expect(result.width, 10);
    expect(result.height, 5);
    expect(img.decodeWebP(result.bytes), isNotNull);
  });

  test('a foreign file is refused instead of guessed at', () {
    final text = File('${folder.path}${Platform.pathSeparator}not.txt');
    text.writeAsStringSync('this is not an image');
    expect(
      () => processImageFile(
        text.path,
        format: 'jpg',
        quality: 80,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('the screen refuses an empty path', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ImageTool()));
    await tester.pump();
    await tester.tap(find.text('Process the image'));
    await tester.pump();
    expect(find.textContaining('Choose an image first'), findsOneWidget);
  });

  testWidgets('PNG hides the quality slider and JPEG shows it', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ImageTool()));
    await tester.pump();
    expect(find.text('Quality'), findsOneWidget);

    await tester.tap(find.text('JPEG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PNG').last);
    await tester.pumpAndSettle();

    expect(find.text('Quality'), findsNothing);
    expect(find.textContaining('usually much larger for photos'),
        findsOneWidget);
  });
}
