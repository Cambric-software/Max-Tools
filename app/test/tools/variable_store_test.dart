import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/features/tools/variable_store.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('max_tools_vars');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  VariableStore storeInMemory() => VariableStore();

  group('naming and typing', () {
    test('valid names', () {
      expect(Variable.isValidName('a'), isTrue);
      expect(Variable.isValidName('_x9'), isTrue);
      expect(Variable.isValidName('9x'), isFalse);
      expect(Variable.isValidName('has space'), isFalse);
      expect(Variable.isValidName(''), isFalse);
    });

    test('rejects an invalid name with a helpful message', () {
      expect(
        () => storeInMemory().set('9bad', value: 1, type: VariableType.number),
        throwsA(isA<VariableError>()),
      );
    });

    test('names are case-insensitive', () {
      final store = storeInMemory();
      store.set('Count', value: 3, type: VariableType.number);
      expect(store.has('count'), isTrue);
      expect(store.get('COUNT')?.value, 3);
      expect(store.names(), <String>['count']);
    });

    test('type inference covers the common values', () {
      expect(VariableType.infer(1), VariableType.number);
      expect(VariableType.infer(true), VariableType.boolean);
      expect(VariableType.infer('x'), VariableType.text);
      expect(VariableType.infer(<int>[]), VariableType.list);
      expect(VariableType.infer(<String, int>{}), VariableType.map);
    });

    test('wire names round-trip', () {
      for (final type in VariableType.values) {
        expect(VariableType.fromWire(type.wireName), type);
      }
      expect(VariableType.fromWire('nonsense'), VariableType.text);
    });
  });

  group('rendering', () {
    test('renders each type as text', () {
      expect(VariableType.render('a'), 'a');
      expect(VariableType.render(42), '42');
      expect(VariableType.render(true), 'true');
      expect(VariableType.render(<int>[1, 2]), '1, 2');
      expect(VariableType.render(null), '');
    });
  });

  group('interpolation', () {
    test('text without a dollar is returned untouched', () {
      expect(storeInMemory().interpolate('plain text'), 'plain text');
    });

    test('substitutes a bare reference', () {
      final store = storeInMemory();
      store.set('name', value: 'Ada', type: VariableType.text);
      expect(store.interpolate(r'hello $name'), 'hello Ada');
    });

    test('substitutes a braced reference', () {
      final store = storeInMemory();
      store.set('name', value: 'Ada', type: VariableType.text);
      expect(store.interpolate(r'hello ${name}!'), 'hello Ada!');
    });

    test('substitutes inside a path', () {
      final store = storeInMemory();
      store.set('dir', value: 'out', type: VariableType.path);
      expect(store.interpolate(r'$dir/todo.csv'), 'out/todo.csv');
    });

    test('numbers interpolate as digits', () {
      final store = storeInMemory();
      store.set('n', value: 42, type: VariableType.number);
      expect(store.interpolate(r'value: $n'), 'value: 42');
    });

    test('unknown variable throws rather than substituting empty text', () {
      final store = storeInMemory();
      expect(() => store.interpolate(r'$ghost'), throwsA(isA<VariableError>()));
    });

    test('escaped dollar is emitted literally', () {
      final store = storeInMemory();
      store.set('n', value: 1, type: VariableType.number);
      expect(store.interpolate(r'\$n'), r'$n');
    });

    test('a lone dollar is preserved', () {
      expect(storeInMemory().interpolate(r'cost: $5'), r'cost: $5');
    });

    test('multiple references in one string', () {
      final store = storeInMemory();
      store.set('a', value: '1', type: VariableType.text);
      store.set('b', value: '2', type: VariableType.text);
      expect(store.interpolate(r'$a-$b'), '1-2');
    });
  });

  group('argument interpolation', () {
    test('a whole-value reference keeps the original type', () {
      final store = storeInMemory();
      store.set('count', value: 7, type: VariableType.number);
      final args = store.interpolateArgs(<String, dynamic>{'width': r'$count'});
      expect(args['width'], 7);
      expect(args['width'], isA<int>());
    });

    test('embedded references become text', () {
      final store = storeInMemory();
      store.set('dir', value: 'out', type: VariableType.path);
      final args = store.interpolateArgs(<String, dynamic>{'path': r'$dir/a.txt'});
      expect(args['path'], 'out/a.txt');
    });

    test('non-string values pass through untouched', () {
      final store = storeInMemory();
      store.set('n', value: 1, type: VariableType.number);
      final args = store.interpolateArgs(<String, dynamic>{
        'list': <int>[1, 2],
        'flag': true,
      });
      expect(args['list'], <int>[1, 2]);
      expect(args['flag'], isTrue);
    });

    test('unknown variable in arguments throws', () {
      expect(
        () => storeInMemory().interpolateArgs(<String, dynamic>{'p': r'$ghost'}),
        throwsA(isA<VariableError>()),
      );
    });

    test('braced whole reference also keeps its type', () {
      final store = storeInMemory();
      store.set('n', value: 5, type: VariableType.number);
      final args = store.interpolateArgs(<String, dynamic>{'p': r'${n}'});
      expect(args['p'], 5);
    });
  });

  group('housekeeping', () {
    test('remove and clear', () {
      final store = storeInMemory();
      store.set('a', value: 1, type: VariableType.number);
      store.set('b', value: 2, type: VariableType.number);
      expect(store.remove('A'), isTrue);
      expect(store.remove('A'), isFalse);
      expect(store.names(), <String>['b']);
      store.clear();
      expect(store.names(), isEmpty);
    });

    test('all() is newest first', () async {
      final store = storeInMemory();
      store.set('old', value: 1, type: VariableType.number);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      store.set('new', value: 2, type: VariableType.number);
      expect(store.all().first.name, 'new');
    });
  });

  group('persistence', () {
    test('variables survive a new store', () {
      final file = File('${temp.path}/vars.json');
      final first = VariableStore(file: file);
      first.set('name', value: 'Ada', type: VariableType.text);
      first.set('count', value: 12, type: VariableType.number);

      final second = VariableStore(file: file);
      second.load();
      expect(second.get('name')?.value, 'Ada');
      expect(second.get('count')?.value, 12);
    });

    test('interpolation works after a reload', () {
      final file = File('${temp.path}/vars.json');
      VariableStore(file: file).set('dir', value: 'out', type: VariableType.path);
      final reloaded = VariableStore(file: file)..load();
      expect(reloaded.interpolate(r'$dir/a.txt'), 'out/a.txt');
    });

    test('a corrupt store starts empty instead of throwing', () {
      final file = File('${temp.path}/vars.json');
      file.writeAsStringSync('{not json');
      final store = VariableStore(file: file)..load();
      expect(store.names(), isEmpty);
    });

    test('malformed entries are skipped', () {
      final file = File('${temp.path}/vars.json');
      file.writeAsStringSync(
        jsonEncode(<Object>[
          'a string',
          <String, dynamic>{'name': 'ok', 'value': 1, 'type': 'number'},
          <String, dynamic>{'name': '9bad', 'value': 2, 'type': 'number'},
        ]),
      );
      final store = VariableStore(file: file)..load();
      expect(store.names(), <String>['ok']);
    });

    test('load is idempotent', () {
      final file = File('${temp.path}/vars.json');
      VariableStore(file: file).set('a', value: 1, type: VariableType.number);
      final store = VariableStore(file: file)..load();
      store.load();
      expect(store.names(), <String>['a']);
    });

    test('metadata round-trips', () {
      final file = File('${temp.path}/vars.json');
      final store = VariableStore(file: file);
      store.set(
        'out',
        value: 'x',
        type: VariableType.path,
        description: 'output folder',
        fromTool: 'files.createFolder',
      );
      final reloaded = VariableStore(file: file)..load();
      final variable = reloaded.get('out')!;
      expect(variable.description, 'output folder');
      expect(variable.fromTool, 'files.createFolder');
    });
  });
}
