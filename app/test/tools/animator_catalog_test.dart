import 'package:flutter_test/flutter_test.dart';
import 'package:max_tools/tools/catalog/tool_catalog.dart';
import 'package:max_tools/tools/tool_registry.dart';

void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = buildDefaultRegistry();
  });

  Future<Map<String, dynamic>> run(String id, Map<String, dynamic> args) async {
    final result = await registry.run(id, args);
    expect(result.success, isTrue, reason: '${result.error}');
    return result.value as Map<String, dynamic>;
  }

  Future<String?> error(String id, Map<String, dynamic> args) async =>
      (await registry.run(id, args)).error;

  group('frames and duration', () {
    test('frames to duration at 24fps', () async {
      final out = await run(
        'anim.framesToDuration',
        <String, dynamic>{'frames': 48, 'fps': '24'},
      );
      expect(out['seconds'], 2.0);
      expect(out['timecode'], '00:00:02:00');
    });

    test('frames to duration handles partial seconds', () async {
      final out = await run(
        'anim.framesToDuration',
        <String, dynamic>{'frames': 1, 'fps': '24'},
      );
      expect(out['seconds'], closeTo(0.0417, 0.001));
    });

    test('fractional rates are understood', () async {
      final out = await run(
        'anim.framesToDuration',
        <String, dynamic>{'frames': 24000, 'fps': '23.976'},
      );
      expect(out['seconds'], closeTo(1001.0, 0.1));
    });

    test('a non-numeric frame rate fails with the valid list', () async {
      final message = await error(
        'anim.framesToDuration',
        <String, dynamic>{'frames': 10, 'fps': 'banana'},
      );
      expect(message, contains('23.976'));
    });

    test('an unusual numeric rate is still honoured', () async {
      // Non-standard rates do happen; refusing them would be unhelpful.
      final out = await run(
        'anim.framesToDuration',
        <String, dynamic>{'frames': 37, 'fps': '37'},
      );
      expect(out['seconds'], 1.0);
    });

    test('duration to frames rounds three ways', () async {
      final nearest = await run(
        'anim.durationToFrames',
        <String, dynamic>{'seconds': 2, 'fps': '24'},
      );
      expect(nearest['frames'], 48);

      final up = await run(
        'anim.durationToFrames',
        <String, dynamic>{'seconds': 2.01, 'fps': '24', 'rounding': 'up'},
      );
      expect(up['frames'], 49);

      final down = await run(
        'anim.durationToFrames',
        <String, dynamic>{'seconds': 2.01, 'fps': '24', 'rounding': 'down'},
      );
      expect(down['frames'], 48);
    });
  });

  group('timecode', () {
    test('frames to timecode', () async {
      final out = await run(
        'anim.timecodeToFrames',
        <String, dynamic>{'timecode': '00:00:02:00', 'fps': '24'},
      );
      expect(out['frames'], 48);
    });

    test('long timecode', () async {
      final out = await run(
        'anim.timecodeToFrames',
        <String, dynamic>{'timecode': '01:02:03:12', 'fps': '24'},
      );
      // 1h2m3s12f at 24fps
      expect(out['frames'], (3600 + 123) * 24 + 12);
    });

    test('millisecond timecode', () async {
      final out = await run(
        'anim.timecodeToFrames',
        <String, dynamic>{'timecode': '00:00:01.500', 'fps': '24'},
      );
      expect(out['frames'], 36);
    });

    test('round trip through timecode', () async {
      final forward = await run(
        'anim.framesToDuration',
        <String, dynamic>{'frames': 1234, 'fps': '24'},
      );
      final back = await run(
        'anim.timecodeToFrames',
        <String, dynamic>{'timecode': forward['timecode'], 'fps': '24'},
      );
      expect(back['frames'], 1234);
    });

    test('drop-frame rates skip frame numbers', () async {
      final out = await run(
        'anim.framesToDuration',
        <String, dynamic>{'frames': 1800, 'fps': '29.97'},
      );
      // 1800 frames of 29.97 is 60.06s, so timecode must not read 00:01:00:00.
      expect(out['timecode'], isNot('00:01:00:00'));
      expect(out['timecode'], startsWith('00:01:00'));
    });

    test('junk timecode is rejected', () async {
      expect(
        await error(
          'anim.timecodeToFrames',
          <String, dynamic>{'timecode': 'not a timecode', 'fps': '24'},
        ),
        isNotNull,
      );
    });
  });

  group('frame rates', () {
    test('comparing rates reports the frame difference', () async {
      final out = await run(
        'anim.fpsCompare',
        <String, dynamic>{'from': '24', 'to': '30', 'seconds': 10},
      );
      expect(out['fromFrames'], 240);
      expect(out['toFrames'], 300);
      expect(out['frameDifference'], 60);
    });

    test('converting 24 to 48 doubles frames', () async {
      final out = await run(
        'anim.fpsCompare',
        <String, dynamic>{'from': '24', 'to': '48', 'seconds': 60},
      );
      expect(out['toFrames'], 2880);
      expect(out['playbackSpeed'], 2.0);
    });

    test('frames in a second', () async {
      final out = await run(
        'anim.framesPerSecond',
        <String, dynamic>{'fps': '24', 'seconds': 3},
      );
      expect(out['frames'], 72);
    });

    test('the rate list marks drop-frame rates', () async {
      final result = await registry.run('anim.frameRates', <String, dynamic>{});
      final rates = result.value as List<Map<String, dynamic>>;
      expect(rates.length, greaterThan(5));
      final drop = rates.firstWhere((r) => r['fps'] == '29.97');
      expect(drop['dropFrame'], isTrue);
      final nonDrop = rates.firstWhere((r) => r['fps'] == '24');
      expect(nonDrop['dropFrame'], isFalse);
    });
  });

  group('render and delivery', () {
    test('render time scales with machines', () async {
      final single = await run(
        'anim.renderTime',
        <String, dynamic>{
          'frames': 100,
          'secondsPerFrame': 10,
          'machines': 1,
        },
      );
      expect(single['totalSeconds'], 1000);

      final ten = await run(
        'anim.renderTime',
        <String, dynamic>{
          'frames': 100,
          'secondsPerFrame': 10,
          'machines': 10,
        },
      );
      expect(ten['totalSeconds'], 100);
    });

    test('render time is human readable', () async {
      final out = await run(
        'anim.renderTime',
        <String, dynamic>{
          'frames': 7200,
          'secondsPerFrame': 5,
          'machines': 1,
        },
      );
      expect(out['humanReadable'], contains('h'));
    });

    test('render time rejects nonsense', () async {
      expect(
        await error(
          'anim.renderTime',
          <String, dynamic>{'frames': 10, 'secondsPerFrame': 1, 'machines': 0},
        ),
        isNotNull,
      );
      expect(
        await error(
          'anim.renderTime',
          <String, dynamic>{'frames': 10, 'secondsPerFrame': 0, 'machines': 1},
        ),
        isNotNull,
      );
    });

    test('asset size from bitrate', () async {
      final out = await run(
        'anim.assetSize',
        <String, dynamic>{'bitrateMbps': 10, 'seconds': 60},
      );
      expect(out['bytes'], 75000000);
      expect(out['humanReadable'], '75.0 MB');
    });

    test('bitrate for a target size inverts the maths', () async {
      final out = await run(
        'anim.bitrateForSize',
        <String, dynamic>{'targetMegabytes': 100, 'seconds': 100},
      );
      // 100 MB over 100 s is 8 Mbps.
      expect(out['bitrateMbps'], 8.0);
    });

    test('delivery check passes and fails honestly', () async {
      final good = await run(
        'anim.deliveryCheck',
        <String, dynamic>{
          'width': 1920,
          'height': 1080,
          'fps': '24',
          'bitrateMbps': 4,
          'maxMegabytes': 500,
          'durationSeconds': 60,
        },
      );
      expect(good['passes'], isTrue);
      expect(good['problems'], isEmpty);

      final bad = await run(
        'anim.deliveryCheck',
        <String, dynamic>{
          'width': 1920,
          'height': 1080,
          'fps': '24',
          'bitrateMbps': 50,
          'maxMegabytes': 100,
          'durationSeconds': 600,
        },
      );
      expect(bad['passes'], isFalse);
      expect(bad['problems'], isNotEmpty);
    });
  });

  group('resolution and motion', () {
    test('resolution facts', () async {
      final out = await run(
        'anim.resolutionInfo',
        <String, dynamic>{'width': 1920, 'height': 1080},
      );
      expect(out['megapixels'], 2.07);
      expect(out['aspectRatio'], '16:9');
      expect(out['name'], contains('1080'));
    });

    test('odd resolutions reduce to a clean ratio', () async {
      final out = await run(
        'anim.aspectRatio',
        <String, dynamic>{'width': 1000, 'height': 750},
      );
      expect(out['ratio'], '4:3');
    });

    test('invalid resolution is rejected', () async {
      expect(
        await error(
          'anim.resolutionInfo',
          <String, dynamic>{'width': 0, 'height': 100},
        ),
        isNotNull,
      );
    });

    test('slow motion doubles the frame count at half speed', () async {
      final out = await run(
        'anim.slowMotion',
        <String, dynamic>{
          'sourceFrames': 48,
          'speedPercent': 50,
          'fps': '24',
        },
      );
      expect(out['outputFrames'], 96);
      expect(out['extraFrames'], 48);
    });

    test('slow motion rejects impossible speeds', () async {
      expect(
        await error(
          'anim.slowMotion',
          <String, dynamic>{'sourceFrames': 10, 'speedPercent': 0},
        ),
        isNotNull,
      );
      expect(
        await error(
          'anim.slowMotion',
          <String, dynamic>{'sourceFrames': 10, 'speedPercent': 200},
        ),
        isNotNull,
      );
    });

    test('audio samples align to frames', () async {
      final out = await run(
        'anim.audioFrames',
        <String, dynamic>{
          'samples': 48000,
          'sampleRate': '48000',
          'fps': '24',
        },
      );
      expect(out['seconds'], 1.0);
      expect(out['frames'], 24);
      expect(out['samplesPerFrame'], 2000.0);
    });

    test('frame step lists every nth frame', () async {
      final out = await run(
        'anim.frameStep',
        <String, dynamic>{'totalFrames': 100, 'every': 25},
      );
      expect(out['count'], 4);
      expect(out['frames'], <int>[0, 25, 50, 75]);
    });

    test('frame step rejects a zero stride', () async {
      expect(
        await error(
          'anim.frameStep',
          <String, dynamic>{'totalFrames': 10, 'every': 0},
        ),
        isNotNull,
      );
    });

    test('stops convert to exposure multipliers', () async {
      final out = await run('anim.stopsToExposure', <String, dynamic>{'stops': 2});
      expect(out['multiplier'], 4.0);
      expect(out['inverse'], 0.25);
    });
  });
}
