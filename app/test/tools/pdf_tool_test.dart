import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:max_tools/tools/apps/pdf_tool.dart';

/// Tests that the PDF builder produces real PDF bytes.
void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('max_tools_pdf_');
  });

  tearDown(() async {
    if (folder.existsSync()) await folder.delete(recursive: true);
  });

  test('text becomes a PDF file', () async {
    final bytes = await buildTextPdf(
      title: 'Quarterly note',
      body: 'The first line.\n\nThe second paragraph, a little longer so the '
          'layout has something to wrap.',
      size: PdfSize.a4,
      fontSize: 11,
      pageNumbers: true,
    );

    expect(bytes.length, greaterThan(500));
    // Every PDF starts with this signature.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    final file = File('${folder.path}${Platform.pathSeparator}out.pdf');
    await file.writeAsBytes(bytes);
    expect(file.lengthSync(), bytes.length);
  });

  test('images become a PDF with one page each', () async {
    final first = img.Image(width: 40, height: 30);
    img.fill(first, color: img.ColorRgb8(10, 20, 30));
    final second = img.Image(width: 30, height: 40);
    img.fill(second, color: img.ColorRgb8(200, 100, 50));

    final bytes = await buildImagePdf(
      images: <Uint8List>[
        img.encodePng(first),
        img.encodePng(second),
      ],
      size: PdfSize.letter,
      pageNumbers: true,
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('non-Latin text is refused, not printed as boxes', () async {
    expect(
      () => buildTextPdf(
        title: '',
        body: 'مرحبا بالعالم',
        size: PdfSize.a4,
        fontSize: 11,
        pageNumbers: false,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('an empty image list is refused', () async {
    expect(
      () => buildImagePdf(
        images: const <Uint8List>[],
        size: PdfSize.a4,
        pageNumbers: false,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('the screen asks for a body first', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PdfTool()));
    await tester.pump();

    await tester.ensureVisible(find.text('Build the PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build the PDF'));
    await tester.pump();
    expect(find.textContaining('Write something in the body'), findsOneWidget);
  });

  testWidgets('the image mode asks for an image', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PdfTool()));
    await tester.pump();

    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Build the PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build the PDF'));
    await tester.pump();
    expect(find.textContaining('Add at least one image'), findsOneWidget);
  });
}
