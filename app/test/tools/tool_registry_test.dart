import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/tools/catalog/tool_catalog.dart';
import 'package:max_tools/tools/tool_descriptor.dart';
import 'package:max_tools/tools/tool_registry.dart';

void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = buildDefaultRegistry();
  });

  group('registration', () {
    test('default registry exposes the developer catalog', () {
      expect(registry.length, greaterThan(0));
      expect(registry.contains('data.csv.parse'), isTrue);
      expect(registry.contains('security.hash'), isTrue);
    });

    test('every tool has a dotted id, name and description', () {
      for (final tool in registry.all()) {
        expect(tool.id, contains('.'), reason: '${tool.id} should be dotted');
        expect(tool.name.trim(), isNotEmpty, reason: '${tool.id} needs a name');
        expect(tool.description.trim(), isNotEmpty,
            reason: '${tool.id} needs a description');
      }
    });

    test('tools are ordered by id for stable output', () {
      final ids = registry.all().map((t) => t.id).toList();
      final sorted = <String>[...ids]..sort();
      expect(ids, sorted);
    });

    test('ids are unique', () {
      final ids = registry.all().map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('rejects a tool with an empty id', () {
      expect(
        () => registry.register(ToolDescriptor(
          id: '',
          name: 'x',
          description: 'y',
          category: ToolCategory.developer,
          run: (_) async => const ToolResult.success(null),
        )),
        throwsA(isA<ToolArgumentError>()),
      );
    });

    test('rejects duplicate parameter names', () {
      expect(
        () => registry.register(ToolDescriptor(
          id: 'bad.tool',
          name: 'Bad',
          description: 'duplicate params',
          category: ToolCategory.developer,
          parameters: const <ToolParameter>[
            ToolParameter(name: 'a', description: 'first'),
            ToolParameter(name: 'a', description: 'again'),
          ],
          run: (_) async => const ToolResult.success(null),
        )),
        throwsA(isA<ToolArgumentError>()),
      );
    });

    test('unregister removes a tool', () {
      expect(registry.unregister('data.csv.parse'), isTrue);
      expect(registry.contains('data.csv.parse'), isFalse);
      expect(registry.unregister('data.csv.parse'), isFalse);
    });
  });

  group('lookup and search', () {
    test('find returns the tool or null', () {
      expect(registry.find('security.hash'), isNotNull);
      expect(registry.find('nope.nope'), isNull);
    });

    test('search matches name, id and tags', () {
      expect(registry.search('csv').map((t) => t.id), contains('data.csv.parse'));
      expect(registry.search('sha256').map((t) => t.id), contains('security.hash'));
    });

    test('search is case-insensitive and word-based', () {
      expect(
        registry.search('CSV').map((t) => t.id),
        contains('data.csv.parse'),
      );
    });

    test('search with no match returns nothing', () {
      expect(registry.search('zzzznotatool'), isEmpty);
    });

    test('empty search returns everything', () {
      expect(registry.search('').length, registry.length);
      expect(registry.search('   ').length, registry.length);
    });

    test('category counts add up to the registry length', () {
      final total = registry.categoryCounts().values
          .fold<int>(0, (sum, count) => sum + count);
      expect(total, registry.length);
    });

    test('byCategory only returns that category', () {
      final security = registry.byCategory(ToolCategory.security);
      expect(security, isNotEmpty);
      expect(security.every((t) => t.category == ToolCategory.security), isTrue);
    });

    test('category parses from label and name', () {
      expect(ToolCategory.tryParse('security'), ToolCategory.security);
      expect(ToolCategory.tryParse('Security'), ToolCategory.security);
      expect(ToolCategory.tryParse('nonsense'), isNull);
    });
  });

  group('argument validation', () {
    test('fills defaults for omitted optional parameters', () {
      final resolved = registry.validateArgs(
        registry.find('data.json.format')!,
        <String, dynamic>{'text': '{"a":1}'},
      );
      expect(resolved['pretty'], isTrue);
    });

    test('throws on unknown parameter', () {
      expect(
        () => registry.validateArgs(
          registry.find('security.hash')!,
          <String, dynamic>{'text': 'a', 'bogus': 1},
        ),
        throwsA(isA<ToolArgumentError>()),
      );
    });

    test('throws on missing required parameter', () {
      expect(
        () => registry.validateArgs(
          registry.find('security.hash')!,
          <String, dynamic>{},
        ),
        throwsA(isA<ToolArgumentError>()),
      );
    });

    test('unknown-parameter error lists the accepted names', () {
      try {
        registry.validateArgs(
          registry.find('security.hash')!,
          <String, dynamic>{'nope': 1},
        );
        fail('expected a ToolArgumentError');
      } on ToolArgumentError catch (error) {
        expect(error.message, contains('text'));
      }
    });
  });

  group('running tools', () {
    test('unknown id returns a failure, not an exception', () async {
      final result = await registry.run('ghost.tool', <String, dynamic>{});
      expect(result.success, isFalse);
      expect(result.error, contains('ghost.tool'));
    });

    test('bad arguments return a failure, not an exception', () async {
      final result = await registry.run('security.hash', <String, dynamic>{});
      expect(result.success, isFalse);
      expect(result.error, contains('required'));
    });

    test('a throwing implementation becomes a failure result', () async {
      registry.register(ToolDescriptor(
        id: 'test.throws',
        name: 'Throws',
        description: 'always fails',
        category: ToolCategory.developer,
        run: (_) async => throw StateError('boom'),
      ));
      final result = await registry.run('test.throws', <String, dynamic>{});
      expect(result.success, isFalse);
      expect(result.error, contains('boom'));
    });

    test('csv parse returns rows', () async {
      final result = await registry.run(
        'data.csv.parse',
        <String, dynamic>{'text': 'a,b\n1,2'},
      );
      expect(result.success, isTrue);
      expect(result.value, <List<String>>[
        <String>['a', 'b'],
        <String>['1', '2'],
      ]);
    });

    test('csv parse with headers returns maps', () async {
      final result = await registry.run(
        'data.csv.parse',
        <String, dynamic>{'text': 'name,age\nAda,36', 'useHeaders': true},
      );
      expect(result.success, isTrue);
      final rows = result.value as List<Map<String, String>>;
      expect(rows.single['name'], 'Ada');
    });

    test('csv encode round-trips through parse', () async {
      final encoded = await registry.run(
        'data.csv.encode',
        <String, dynamic>{
          'rows': <List<String>>[
            <String>['name', 'note'],
            <String>['Ada', 'likes, commas'],
          ],
        },
      );
      expect(encoded.success, isTrue);
      final parsed = await registry.run(
        'data.csv.parse',
        <String, dynamic>{'text': encoded.value},
      );
      expect((parsed.value as List<List<String>>).last.last, 'likes, commas');
    });

    test('json format pretty-prints and minifies', () async {
      final pretty = await registry.run(
        'data.json.format',
        <String, dynamic>{'text': '{"a":1}'},
      );
      expect((pretty.value as String), contains('\n'));
      final minified = await registry.run(
        'data.json.format',
        <String, dynamic>{'text': '{"a":1}', 'pretty': false},
      );
      expect((minified.value as String), '{"a":1}');
    });

    test('invalid json fails cleanly', () async {
      final result = await registry.run(
        'data.json.format',
        <String, dynamic>{'text': '{not json'},
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Invalid JSON'));
    });

    test('json inspect reports keys and length', () async {
      final result = await registry.run(
        'data.json.inspect',
        <String, dynamic>{'text': '{"a":1,"b":2}'},
      );
      final summary = result.value as Map<String, dynamic>;
      expect(summary['keys'], <String>['a', 'b']);
      expect(summary['length'], 2);
    });

    test('hash defaults to sha256', () async {
      final result =
          await registry.run('security.hash', <String, dynamic>{'text': 'hello'});
      expect(result.success, isTrue);
      expect((result.value as String).length, 64);
    });

    test('hash md5 is 32 characters', () async {
      final result = await registry.run(
        'security.hash',
        <String, dynamic>{'text': 'hello', 'algorithm': 'md5'},
      );
      expect((result.value as String).length, 32);
    });

    test('hmac without a secret fails with a clear message', () async {
      final result = await registry.run(
        'security.hash',
        <String, dynamic>{'text': 'hello', 'algorithm': 'hmacSha256'},
      );
      expect(result.success, isFalse);
      expect(result.error, contains('secret'));
    });

    test('unknown algorithm fails with the valid options', () async {
      final result = await registry.run(
        'security.hash',
        <String, dynamic>{'text': 'hello', 'algorithm': 'crc32'},
      );
      expect(result.success, isFalse);
      expect(result.error, contains('sha256'));
    });

    test('verifyTextHash reports a match', () async {
      final sha = await registry.run(
        'security.hash',
        <String, dynamic>{'text': 'hello'},
      );
      final verified = await registry.run(
        'security.verifyTextHash',
        <String, dynamic>{'text': 'hello', 'expected': sha.value},
      );
      expect((verified.value as Map<String, bool>)['matches'], isTrue);
    });

    test('verifyTextHash reports a mismatch', () async {
      final verified = await registry.run(
        'security.verifyTextHash',
        <String, dynamic>{'text': 'hello', 'expected': 'deadbeef'},
      );
      expect((verified.value as Map<String, bool>)['matches'], isFalse);
    });
  });

  group('file tools', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('max_tools_test');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('file checksum matches verify', () async {
      final file = File('${temp.path}/a.txt');
      await file.writeAsString('payload');
      final sum = await registry.run(
        'files.checksum',
        <String, dynamic>{'path': file.path},
      );
      expect(sum.success, isTrue);
      final verified = await registry.run(
        'files.verifyChecksum',
        <String, dynamic>{'path': file.path, 'expected': sum.value},
      );
      expect((verified.value as Map<String, bool>)['matches'], isTrue);
    });

    test('missing file fails without throwing', () async {
      final result = await registry.run(
        'files.checksum',
        <String, dynamic>{'path': '${temp.path}/nope.txt'},
      );
      expect(result.success, isFalse);
      expect(result.error, contains('not found'));
    });
  });
}
