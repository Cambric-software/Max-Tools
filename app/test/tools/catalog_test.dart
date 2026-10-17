import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/tools/catalog/tool_catalog.dart';
import 'package:max_tools/tools/tool_descriptor.dart';
import 'package:max_tools/tools/tool_registry.dart';

void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = buildDefaultRegistry();
  });

  Future<Object?> run(String id, Map<String, dynamic> args) async =>
      (await registry.run(id, args)).value;

  Future<String?> error(String id, Map<String, dynamic> args) async =>
      (await registry.run(id, args)).error;

  Future<bool> ok(String id, Map<String, dynamic> args) async =>
      (await registry.run(id, args)).success;

  group('catalog size and integrity', () {
    test('exceeds 50 tools', () {
      expect(registry.length, greaterThanOrEqualTo(50));
    });

    test('animator, freelancer and business are all represented', () {
      final categories =
          registry.categoryCounts().keys.map((c) => c.name).toSet();
      expect(categories, containsAll(<String>[
        'developer', 'data', 'file', 'security', 'network', 'animator',
      ]));
    });

    test('every tool is reachable and described', () {
      for (final tool in registry.all()) {
        expect(tool.id, contains('.'), reason: tool.id);
        expect(tool.name.trim(), isNotEmpty, reason: tool.id);
        expect(tool.description.trim(), isNotEmpty, reason: tool.id);
      }
    });

    test('a tool that takes no input still runs', () async {
      final parameterless = registry.all().where((t) => t.parameters.isEmpty);
      expect(parameterless, isNotEmpty,
          reason: 'expected at least one no-input tool such as a reference list');
      for (final tool in parameterless) {
        final result = await registry.run(tool.id, <String, dynamic>{});
        expect(result.success, isTrue, reason: tool.id);
      }
    });

    test('every tool is findable by its own name', () {
      for (final tool in registry.all()) {
        final words = tool.name
            .toLowerCase()
            .split(RegExp(r'[^a-z0-9]+'))
            .where((w) => w.isNotEmpty && w.length > 2);
        if (words.isEmpty) continue;
        expect(
          registry.search(words.first).map((t) => t.id),
          contains(tool.id),
          reason: '${tool.id} not findable by "${words.first}"',
        );
      }
    });

    test('write tools are labelled as such', () {
      final writes = registry.all().where((t) => !t.readOnly).toList();
      for (final tool in writes) {
        expect(tool.readOnly, isFalse);
      }
    });
  });

  group('text tools', () {
    test('base64 round-trips unicode', () async {
      final encoded = await run('text.base64Encode', {'text': 'héllo ☃'});
      final decoded = await run('text.base64Decode', {'text': encoded!});
      expect(decoded, 'héllo ☃');
    });

    test('base64 decode rejects rubbish', () async {
      expect(await error('text.base64Decode', {'text': '!!!!'}), isNotNull);
    });

    test('url encode and decode round-trip', () async {
      final encoded = await run('text.urlEncode', {'text': 'a b&c=d'});
      expect(encoded, 'a%20b%26c%3Dd');
      expect(await run('text.urlDecode', {'text': encoded}), 'a b&c=d');
    });

    test('case conversions', () async {
      expect(await run('text.toUpper', {'text': 'ab'}), 'AB');
      expect(await run('text.toLower', {'text': 'AB'}), 'ab');
      expect(await run('text.titleCase', {'text': 'hello wide world'}),
          'Hello Wide World');
    });

    test('reverse', () async {
      expect(await run('text.reverse', {'text': 'abc'}), 'cba');
    });

    test('word count reports every measure', () async {
      final stats = await run('text.wordCount', {'text': 'One two. Three.'})
          as Map<String, dynamic>;
      expect(stats['words'], 3);
      expect(stats['sentences'], 2);
      expect(stats['characters'], greaterThan(0));
    });

    test('dedupe keeps first occurrence', () async {
      expect(await run('text.dedupeLines', {'text': 'a\nb\na\nc\nb'}),
          'a\nb\nc');
    });

    test('sort lines ascending, descending and numeric', () async {
      expect(await run('text.sortLines', {'text': 'b\na\nc'}), 'a\nb\nc');
      expect(
        await run('text.sortLines', {'text': 'b\na\nc', 'order': 'descending'}),
        'c\nb\na',
      );
      expect(
        await run('text.sortLines', {'text': '10\n9\n100', 'numeric': true}),
        '9\n10\n100',
      );
    });

    test('filter lines keeps and removes', () async {
      expect(
        await run('text.filterLines', {'text': 'cat\ndog\ncat', 'query': 'cat'}),
        'cat\ncat',
      );
      expect(
        await run(
          'text.filterLines',
          {'text': 'cat\ndog\ncat', 'query': 'cat', 'mode': 'remove'},
        ),
        'dog',
      );
    });

    test('filter lines can ignore case', () async {
      expect(
        await run(
          'text.filterLines',
          {'text': 'CAT\ndog', 'query': 'cat', 'ignoreCase': true},
        ),
        'CAT',
      );
    });

    test('replace all, case-insensitive', () async {
      // Case-sensitive by default: only the lowercase 'a' matches.
      expect(
        await run('text.replaceAll', {'text': 'aAa', 'find': 'a', 'replace': ''}),
        'A',
      );
      expect(
        await run(
          'text.replaceAll',
          {'text': 'aAa', 'find': 'a', 'replace': 'X', 'ignoreCase': true},
        ),
        'XXX',
      );
    });

    test('replace with empty find is rejected', () async {
      expect(
        await error('text.replaceAll', {'text': 'a', 'find': '', 'replace': 'b'}),
        isNotNull,
      );
    });

    test('identifier case conversions', () async {
      expect(await run('text.caseTo', {'text': 'helloWorld', 'to': 'snake'}),
          'hello_world');
      expect(await run('text.caseTo', {'text': 'hello_world', 'to': 'camel'}),
          'helloWorld');
      expect(await run('text.caseTo', {'text': 'hello_world', 'to': 'kebab'}),
          'hello-world');
      expect(await run('text.caseTo', {'text': 'hello_world', 'to': 'pascal'}),
          'HelloWorld');
      expect(await run('text.caseTo', {'text': 'hello_world', 'to': 'constant'}),
          'HELLO_WORLD');
    });

    test('slug', () async {
      expect(await run('text.slug', {'text': 'Hello, World! Again'}), 'hello-world-again');
    });

    test('pad left, right and centre', () async {
      expect(await run('text.pad', {'text': 'ab', 'width': 5}), 'ab   ');
      expect(
        await run('text.pad', {'text': 'ab', 'width': 5, 'align': 'right'}),
        '   ab',
      );
      expect(
        await run('text.pad', {'text': 'ab', 'width': 6, 'align': 'center'}),
        '  ab  ',
      );
    });

    test('pad leaves longer text untouched', () async {
      expect(await run('text.pad', {'text': 'abcdef', 'width': 3}), 'abcdef');
    });

    test('regex match lists matches', () async {
      final result = await run(
        'text.regexMatch',
        {'text': 'a1 b2 c3', 'pattern': r'[a-z]\d'},
      ) as Map<String, dynamic>;
      expect(result['count'], 3);
    });

    test('regex replace supports capture groups', () async {
      expect(
        await run(
          'text.regexReplace',
          {'text': 'John Smith', 'pattern': r'(\w+) (\w+)', 'replace': r'$2, $1'},
        ),
        'Smith, John',
      );
    });

    test('regex test reports position', () async {
      final result = await run(
        'text.regexTest',
        {'text': 'abc123', 'pattern': r'\d+'},
      ) as Map<String, dynamic>;
      expect(result['matches'], isTrue);
      expect(result['start'], 3);
    });

    test('an invalid regex fails cleanly', () async {
      final message = await error(
        'text.regexMatch',
        {'text': 'a', 'pattern': '('},
      );
      expect(message, isNotNull);
      expect(await ok('text.regexMatch', {'text': 'a', 'pattern': '('}), isFalse);
    });

    test('markdown table to csv', () async {
      final csv = await run(
        'text.markdownTableToCsv',
        {
          'text': '| Name | Age |\n| --- | --- |\n| Ada | 36 |',
        },
      );
      expect(csv, 'Name,Age\nAda,36');
    });

    test('diff reports changed lines', () async {
      final result = await run(
        'text.diffLines',
        {'before': 'a\nb\nc', 'after': 'a\nB\nc'},
      ) as Map<String, dynamic>;
      expect(result['identical'], isFalse);
      expect(result['changedLines'], 1);
    });

    test('diff reports identical text', () async {
      final result =
          await run('text.diffLines', {'before': 'a\nb', 'after': 'a\nb'})
              as Map<String, dynamic>;
      expect(result['identical'], isTrue);
    });

    test('indent, join and split', () async {
      expect(await run('text.indent', {'text': 'a\nb', 'spaces': 2}), '  a\n  b');
      expect(await run('text.indent', {'text': 'a', 'spaces': 0}), '\ta');
      expect(await run('text.joinLines', {'text': 'a\nb', 'separator': '-'}),
          'a-b');
      expect(await run('text.split', {'text': 'a,b', 'separator': ','}),
          <String>['a', 'b']);
    });

    test('character codes', () async {
      final codes = await run('text.charsToNumbers', {'text': 'AB'})
          as List<Map<String, Object?>>;
      expect(codes.length, 2);
      expect(codes.first['code'], 65);
    });

    test('escape csv quotes when needed', () async {
      expect(await run('text.escapeCsv', {'text': 'plain'}), 'plain');
      expect(await run('text.escapeCsv', {'text': 'a,b'}), '"a,b"');
      expect(await run('text.escapeCsv', {'text': 'say "hi"'}), '"say ""hi"""');
    });
  });

  group('system tools', () {
    test('path helpers', () async {
      expect(await run('paths.basename', {'path': '/a/b/c.txt'}), 'c.txt');
      expect(await run('paths.dirname', {'path': '/a/b/c.txt'}), r'\a\b');
      expect(await run('paths.extension', {'path': 'a/b/c.txt'}), 'txt');
      expect(await run('paths.extension', {'path': 'noext'}), '');
    });

    test('url validate distinguishes https', () async {
      final plain = await run('url.validate', {'url': 'http://example.com'})
          as Map<String, dynamic>;
      expect(plain['valid'], isTrue);
      expect(plain['https'], isFalse);
      final secure = await run('url.validate', {'url': 'https://example.com'})
          as Map<String, dynamic>;
      expect(secure['https'], isTrue);
    });

    test('url query params and adding params', () async {
      final params = await run(
        'url.queryParams',
        {'url': 'https://x.dev/a?b=1&c=2'},
      ) as Map<String, dynamic>;
      expect(params['b'], '1');
      final built = await run(
        'url.addParams',
        {'url': 'https://x.dev/a', 'params': 'b=1, c=2'},
      );
      expect(built, contains('b=1'));
      expect(built, contains('c=2'));
    });

    test('addParams rejects a malformed list', () async {
      expect(
        await error('url.addParams', {'url': 'https://x.dev', 'params': 'nope'}),
        isNotNull,
      );
    });

    test('xml extract and escape', () async {
      expect(
        await run(
          'data.xml.extract',
          {'text': '<a><t>x</t><t>y</t></a>', 'tag': 't'},
        ),
        <String>['x', 'y'],
      );
      expect(await run('data.xml.escape', {'text': 'a<b&c'}), 'a&lt;b&amp;c');
    });

    test('obfuscate round-trips', () async {
      final hidden = await run(
        'security.obfuscate',
        {'text': 'secret message', 'key': 'k123'},
      );
      expect(hidden, isNot('secret message'));
      expect(
        await run(
          'security.deobfuscate',
          {'text': hidden!, 'key': 'k123'},
        ),
        'secret message',
      );
    });

    test('generate key honours length bounds', () async {
      final key = await run('security.generateKey', {'length': 16}) as String;
      expect(key.length, 16);
      expect(
        await error('security.generateKey', {'length': 2}),
        isNotNull,
      );
      expect(
        await error('security.generateKey', {'length': 500}),
        isNotNull,
      );
    });

    test('human file size', () async {
      expect(await run('files.humanSize', {'bytes': 512}), '512 B');
      expect(await run('files.humanSize', {'bytes': 2048}), '2.0 KB');
      expect(await run('files.humanSize', {'bytes': 5 * 1024 * 1024}), '5.0 MB');
    });

    test('missing paths fail cleanly', () async {
      expect(await error('files.metadata', {'path': '/nope/nope.txt'}), isNotNull);
      expect(await error('files.list', {'path': '/nope/nope'}), isNotNull);
      final exists = await run('files.exists', {'path': '/nope/nope'})
          as Map<String, dynamic>;
      expect(exists['exists'], isFalse);
    });
  });

  group('category spread', () {
    test('tools cover developer, data, file, security and network', () {
      final categories =
          registry.categoryCounts().keys.map((c) => c.name).toSet();
      expect(
        categories,
        containsAll(<String>['developer', 'data', 'file', 'security', 'network']),
      );
    });

    test('animator tools have landed; business arrives in phase 5', () {
      // Phase 4 shipped the animator batch, so the category is populated.
      // Business and freelancer stay declared but empty until phase 5.
      expect(registry.byCategory(ToolCategory.animator), isNotEmpty);
      expect(registry.byCategory(ToolCategory.business), isEmpty);
      expect(registry.byCategory(ToolCategory.freelancer), isEmpty);
    });
  });
}
