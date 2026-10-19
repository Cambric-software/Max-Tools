import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/tools/catalog/tool_catalog.dart';
import 'package:max_tools/tools/tool_descriptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the catalog the product actually ships.
///
/// These are deliberately strict about shape rather than count: a tool that
/// has no screen, no icon or no explanation is not finished, and shipping it
/// would be the same mistake as the old hundred descriptors.
void main() {
  // Built once so the render loop below can enumerate the tools.
  final catalog = buildDefaultRegistry();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('catalog shape', () {
    test('the tools the product promises are present', () {
      for (final id in <String>[
        'security.scan',
        'money.wealth',
        'developer.toolkit',
        'file.checksum',
        'everyday.units',
        'documents.text',
        'media.colour',
      ]) {
        expect(catalog.contains(id), isTrue, reason: '$id is missing');
      }
    });

    test('ids are dotted and unique', () {
      final ids = catalog.all().map((ToolDescriptor tool) => tool.id).toList();
      for (final id in ids) {
        expect(id, contains('.'), reason: id);
      }
      expect(ids.toSet().length, ids.length);
    });

    test('every tool is an application, not a form', () {
      for (final tool in catalog.all()) {
        expect(tool.screen, isNotNull, reason: '${tool.id} has no screen');
        expect(tool.icon, isNotNull, reason: '${tool.id} has no icon');
        expect(tool.howTo, isNotNull, reason: '${tool.id} has no explanation');
        expect(
          (tool.howTo ?? '').trim().length,
          greaterThan(40),
          reason: '${tool.id} explains itself in too few words',
        );
        expect(tool.name.trim(), isNotEmpty, reason: '${tool.id} has no name');
        expect(
          tool.description.trim(),
          isNotEmpty,
          reason: '${tool.id} has no description',
        );
      }
    });

    test('every tool is findable by its own name', () {
      for (final tool in catalog.all()) {
        expect(
          catalog.search(tool.name).map((ToolDescriptor t) => t.id),
          contains(tool.id),
          reason: '${tool.id} cannot be found by searching "${tool.name}"',
        );
      }
    });

    test('every advertised category has at least one tool', () {
      final used = catalog.categoryCounts().keys.toSet();
      expect(
        used,
        containsAll(<ToolCategory>[
          ToolCategory.security,
          ToolCategory.money,
          ToolCategory.developer,
          ToolCategory.file,
          ToolCategory.everyday,
          ToolCategory.documents,
          ToolCategory.media,
        ]),
      );
      expect(
        catalog.categoryCounts().values.every((int count) => count > 0),
        isTrue,
        reason: 'a category is listed with no tools in it',
      );
    });
  });

  group('every tool screen renders', () {
    for (final tool in catalog.all()) {
      for (final size in <Size>[const Size(390, 844), const Size(1440, 900)]) {
        testWidgets(
          '${tool.id} at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
            SharedPreferences.setMockInitialValues(<String, Object>{});
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              MaterialApp(home: Builder(builder: tool.screen!)),
            );
            // Two pumps rather than pumpAndSettle: the tools have no repeating
            // animation to wait for, and settling would hang on the loading
            // spinner of any tool that reads storage.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 120));

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
