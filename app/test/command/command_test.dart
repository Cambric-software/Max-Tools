import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/command/corrector.dart';
import 'package:max_tools/command/intent_parser.dart';
import 'package:max_tools/command/text_distance.dart';
import 'package:max_tools/tools/catalog/tool_catalog.dart';
import 'package:max_tools/tools/tool_registry.dart';
import 'package:max_tools/tools/variable_store.dart';

void main() {
  late ToolRegistry registry;
  late IntentParser parser;

  setUp(() {
    registry = buildDefaultRegistry();
    parser = IntentParser(registry);
  });

  group('edit distance', () {
    test('identical and empty', () {
      expect(levenshtein('abc', 'abc'), 0);
      expect(levenshtein('', ''), 0);
      expect(levenshtein('', 'abc'), 3);
      expect(levenshtein('abc', ''), 3);
    });

    test('single edits', () {
      expect(levenshtein('cat', 'cart'), 1);
      expect(levenshtein('cart', 'cat'), 1);
      expect(levenshtein('cat', 'cut'), 1);
    });

    test('transposition costs one with damerau', () {
      expect(damerauLevenshtein('teh', 'the'), 1);
      expect(levenshtein('teh', 'the'), 2);
      expect(editDistance('teh', 'the'), 1);
    });

    test('similarity bounds', () {
      expect(similarity('abc', 'abc'), 1.0);
      expect(similarity('abc', 'xyz'), lessThan(0.5));
      expect(similarity('', ''), 1.0);
    });

    test('typo tolerance scales with length', () {
      expect(isTypoOf('teh', 'the'), isTrue);        // short, 1 edit
      expect(isTypoOf('csv', 'cvs'), isTrue);        // transposition
      expect(isTypoOf('checksum', 'checksu'), isTrue);
      expect(isTypoOf('cat', 'cathedral'), isFalse); // too different
    });
  });

  group('corrector', () {
    test('corrects a transposed word', () {
      final fix = parser.corrector.correct('teh');
      expect(fix, isNotNull);
      expect(fix!.corrected, 'the');
      expect(fix.distance, 1);
    });

    test('corrects a misspelled tool word', () {
      final fix = parser.corrector.correct('checksumm');
      expect(fix?.corrected, 'checksum');
    });

    test('leaves known words alone', () {
      expect(parser.corrector.correct('csv'), isNull);
      expect(parser.corrector.isKnown('hash'), isTrue);
    });

    test('leaves unrelated words alone', () {
      expect(parser.corrector.correct('zzzzqqq'), isNull);
    });

    test('phrase correction reports what changed', () {
      final result = parser.corrector.correctPhrase('parse teh csv');
      expect(result.changed, isTrue);
      expect(result.corrected, contains('the'));
      expect(result.suggestion, isNotNull);
    });

    test('phrase correction preserves an already-correct phrase', () {
      final result = parser.corrector.correctPhrase('parse csv text');
      expect(result.changed, isFalse);
      expect(result.suggestion, isNull);
    });

    test('phrase correction does not touch paths', () {
      final result =
          parser.corrector.correctPhrase('read file from /home/adam/data');
      expect(result.corrected, contains('/home/adam/data'));
    });

    test('phrase correction preserves capitalisation style', () {
      final result = parser.corrector.correctPhrase('Parse Cvs');
      expect(result.corrected, contains('Csv'));
    });

    test('suggestions are ordered and bounded', () {
      final suggestions = parser.corrector.suggestions('chec');
      expect(suggestions, isNotEmpty);
      expect(suggestions.length, lessThanOrEqualTo(5));
    });

    test('toolsFor maps a word back to tool ids', () {
      expect(parser.corrector.toolsFor('csv'), isNotEmpty);
      expect(parser.corrector.toolsFor('zzzz'), isEmpty);
    });
  });

  group('intent: tool matching', () {
    test('an exact tool name is matched', () {
      final intent = parser.parse('parse csv');
      expect(intent.best?.tool.id, 'data.csv.parse');
      expect(intent.isConfident, isTrue);
    });

    test('a synonym is matched', () {
      final intent = parser.parse('pretty print json');
      expect(intent.best?.tool.id, 'data.json.format');
    });

    test('a tag is matched', () {
      final intent = parser.parse('md5');
      expect(intent.best?.tool.id, 'security.hash');
    });

    test('a direct id is matched with top confidence', () {
      final intent = parser.parse('files.humanSize please');
      expect(intent.best?.kind, MatchKind.id);
      expect(intent.isConfident, isTrue);
    });

    test('a typo still finds the tool', () {
      final intent = parser.parse('parse cvs');
      expect(intent.candidates, isNotEmpty);
      expect(intent.wasCorrected, isTrue);
      expect(intent.best?.tool.id, 'data.csv.parse');
    });

    test('an unrelated sentence matches nothing', () {
      final intent = parser.parse('qwertyuiop asdfghjkl');
      expect(intent.isEmpty, isTrue);
    });

    test('an empty sentence matches nothing', () {
      expect(parser.parse('').isEmpty, isTrue);
      expect(parser.parse('   ').isEmpty, isTrue);
    });

    test('candidates are ranked best first and bounded', () {
      final intent = parser.parse('convert this text');
      final scores = intent.candidates.map((c) => c.score).toList();
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i - 1], greaterThanOrEqualTo(scores[i]));
      }
      expect(intent.candidates.length, lessThanOrEqualTo(6));
    });
  });

  group('intent: argument extraction', () {
    test('a number fills a numeric parameter', () {
      final intent = parser.parse('pad text width 12');
      expect(intent.arguments['width'], 12);
      expect(intent.arguments['width'], isA<int>());
    });

    test('a decimal stays a double', () {
      final intent = parser.parse('pad text width 12.5');
      expect(intent.arguments['width'], 12.5);
    });

    test('a path fills a path parameter', () {
      final intent = parser.parse('checksum file in C:/tmp/data.bin');
      expect(intent.arguments.containsKey('path'), isTrue);
      expect('${intent.arguments['path']}', contains('data.bin'));
    });

    test('a boolean is read from yes/no', () {
      final intent = parser.parse('parse csv useHeaders yes');
      expect(intent.arguments['useHeaders'], isTrue);
    });

    test('leftover text feeds the required text parameter', () {
      final intent = parser.parse('hash my secret password');
      expect(intent.arguments.containsKey('text'), isTrue);
      expect('${intent.arguments['text']}', contains('secret'));
    });

    test('missing required parameters are reported', () {
      final intent = parser.parse('hash');
      expect(intent.best, isNotNull);
      // 'hash' alone gives no text, so the palette must ask.
      expect(intent.missingParameters.map((p) => p.name), contains('text'));
    });

    test('a satisfied tool reports nothing missing', () {
      final intent = parser.parse('hash my secret password');
      expect(intent.missingParameters, isEmpty);
    });

    test('a tool with no parameters gets an empty map', () {
      final intent = parser.parse('list files');
      expect(intent.arguments, isEmpty);
    });

    test('numbers are not duplicated across parameters', () {
      final intent = parser.parse('sort lines numeric true order descending');
      expect(intent.arguments['order'], 'descending');
    });
  });

  group('intent: variables', () {
    test('a variable reference is interpolated', () {
      final variables = VariableStore()
        ..set('payload', value: 'from-variable', type: VariableType.text);
      final intent = parser.parse(r'hash $payload', variables: variables);
      expect(intent.arguments['text'], contains('from-variable'));
    });

    test('an unknown variable does not hide the parsed intent', () {
      final intent =
          parser.parse(r'hash $ghost', variables: VariableStore());
      expect(intent.best, isNotNull);
    });
  });

  group('unit-aware helpers', () {
    test('parses byte sizes with units', () {
      expect(IntentParser.parseSize('2gb'), 2 * 1024 * 1024 * 1024);
      expect(IntentParser.parseSize('512 KB'), 512 * 1024);
      expect(IntentParser.parseSize('nothing'), isNull);
    });

    test('parses frame rates including decimals', () {
      expect(IntentParser.parseFrameRate('24 fps'), 24);
      expect(IntentParser.parseFrameRate('23.976 fps'), closeTo(23.976, 0.001));
      expect(IntentParser.parseFrameRate('no rate'), isNull);
    });
  });

  group('honesty', () {
    test('an ambiguous sentence is not treated as confident', () {
      final intent = parser.parse('convert');
      expect(intent.isConfident, isFalse);
    });

    test('a match still exposes alternatives', () {
      final intent = parser.parse('json');
      expect(intent.candidates.length, greaterThan(1));
    });

    test('the palette never invents a tool id', () {
      for (final sentence in <String>[
        'delete everything',
        'send an email',
        'format cvs teh',
        'hash \$nothing',
      ]) {
        final intent = parser.parse(sentence);
        for (final candidate in intent.candidates) {
          expect(registry.contains(candidate.tool.id), isTrue,
              reason: '${sentence} produced unknown ${candidate.tool.id}');
        }
      }
    });
  });
}
