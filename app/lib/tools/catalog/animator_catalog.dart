/// Animator and motion tools.
///
/// Frame maths, timecode, delivery maths and render estimation. Everything is
/// a pure calculation from values the artist supplies, so a result is always
/// reproducible and checkable by hand.
library;

import 'dart:math' as math;

import '../tool_descriptor.dart';
import '../tool_registry.dart';
import '../variable_store.dart';

/// Fractional frame rates studios actually use, and their drop-frame flag.
const Map<String, double> kFrameRates = <String, double>{
  '23.976': 24000 / 1001,
  '24': 24,
  '25': 25,
  '29.97': 30000 / 1001,
  '30': 30,
  '48': 48,
  '50': 50,
  '59.94': 60000 / 1001,
  '60': 60,
};

/// Drop-frame timecode skips two frame numbers per minute except every tenth
/// minute, keeping wall-clock time aligned with NTSC recording.
const Set<String> kDropFrameRates = <String>{'29.97', '59.94'};

ToolParameter _num(
  String name,
  String description, {
  bool required = false,
  Object? fallback,
}) =>
    ToolParameter(
      name: name,
      description: description,
      required: required,
      defaultValue: fallback,
      type: VariableType.number,
    );

ToolParameter _text(
  String name,
  String description, {
  bool required = false,
  Object? defaultValue,
}) =>
    ToolParameter(
      name: name,
      description: description,
      required: required,
      defaultValue: defaultValue,
    );

/// Animator and motion tools.
List<ToolDescriptor> animatorTools() => <ToolDescriptor>[
      ToolDescriptor(
        id: 'anim.framesToDuration',
        name: 'Frames to Duration',
        description: 'Convert a frame count into seconds and timecode.',
        category: ToolCategory.animator,
        tags: <String>['frames', 'duration', 'seconds', 'length'],
        synonyms: <String>['how long is this clip', 'frame to seconds'],
        parameters: <ToolParameter>[
          _num('frames', 'Number of frames.'),
          _text('fps', 'Frame rate, e.g. 24 or 23.976.', defaultValue: '24'),
        ],
        run: (args) async {
          final fps = _resolveFps(args['fps']);
          if (fps == null) {
            return ToolResult.failure(
              'Unknown frame rate "${args['fps']}". Try one of: '
              '${kFrameRates.keys.join(', ')}.',
            );
          }
          final frames = _int(args['frames'], 'frames');
          final seconds = frames / fps;
          return ToolResult.success(<String, dynamic>{
            'frames': frames,
            'fps': args['fps'],
            'seconds': _round(seconds, 3),
            'timecode': _timecodeFromFrames(frames, args['fps'] as String? ?? '24'),
            'minutes': _round(seconds / 60, 3),
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.durationToFrames',
        name: 'Duration to Frames',
        description: 'Convert a duration in seconds into whole frames.',
        category: ToolCategory.animator,
        tags: <String>['duration', 'frames', 'seconds'],
        synonyms: <String>['how many frames', 'seconds to frames'],
        parameters: <ToolParameter>[
          _num('seconds', 'Clip length in seconds.'),
          _text('fps', 'Frame rate.', defaultValue: '24'),
          _text('rounding', 'nearest, up or down.', defaultValue: 'nearest'),
        ],
        run: (args) async {
          final fps = _resolveFps(args['fps']);
          if (fps == null) {
            return ToolResult.failure('Unknown frame rate "${args['fps']}".');
          }
          final seconds = _number(args['seconds'], 'seconds');
          final exact = seconds * fps;
          final rounding = (args['rounding'] as String? ?? 'nearest').toLowerCase();
          final int frames = switch (rounding) {
            'up' || 'ceil' => exact.ceil(),
            'down' || 'floor' => exact.floor(),
            _ => exact.round(),
          };
          return ToolResult.success(<String, dynamic>{
            'frames': frames,
            'exactFrames': _round(exact, 3),
            'fps': args['fps'],
            'timecode': _timecodeFromFrames(frames, args['fps'] as String? ?? '24'),
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.timecodeToFrames',
        name: 'Timecode to Frames',
        description: 'Convert HH:MM:SS:FF or HH:MM:SS.mmm into frames.',
        category: ToolCategory.animator,
        tags: <String>['timecode', 'frames', 'convert'],
        synonyms: <String>['timecode to frames', 'convert timecode'],
        parameters: <ToolParameter>[
          _text('timecode', 'Timecode, e.g. 01:02:03:12.', required: true),
          _text('fps', 'Frame rate.', defaultValue: '24'),
        ],
        run: (args) async {
          final fps = _resolveFps(args['fps']);
          if (fps == null) {
            return ToolResult.failure('Unknown frame rate "${args['fps']}".');
          }
          final parsed = _parseTimecode(
            args['timecode'] as String,
            args['fps'] as String? ?? '24',
          );
          if (parsed == null) {
            return ToolResult.failure(
              'Could not read "${args['timecode']}" as timecode. Expected '
              'HH:MM:SS:FF or HH:MM:SS.mmm.',
            );
          }
          return ToolResult.success(<String, dynamic>{
            'frames': parsed,
            'timecode': _timecodeFromFrames(parsed, args['fps'] as String? ?? '24'),
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.fpsCompare',
        name: 'Compare Frame Rates',
        description: 'Compare frame rates and what dropping between them does '
            'to running time.',
        category: ToolCategory.animator,
        tags: <String>['fps', 'framerate', 'conversion', 'speed'],
        synonyms: <String>['fps difference', 'convert between frame rates'],
        parameters: <ToolParameter>[
          _text('from', 'Source frame rate.', required: true),
          _text('to', 'Target frame rate.', required: true),
          _num('seconds', 'Duration to convert.', fallback: 60),
        ],
        run: (args) async {
          final from = _resolveFps(args['from']);
          final to = _resolveFps(args['to']);
          if (from == null || to == null) {
            return ToolResult.failure(
              'Unknown frame rate. Known rates: ${kFrameRates.keys.join(', ')}.',
            );
          }
          final seconds = _number(args['seconds'], 'seconds');
          return ToolResult.success(<String, dynamic>{
            'fromFps': from,
            'toFps': to,
            'fromFrames': (seconds * from).round(),
            'toFrames': (seconds * to).round(),
            'frameDifference': (seconds * to).round() - (seconds * from).round(),
            'playbackSpeed': _round(to / from, 4),
            'note': 'Interpreted: playing ${args['to']} footage at '
                '${args['from']} speed is ${_round(to / from, 4)}x.',
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.renderTime',
        name: 'Estimate Render Time',
        description: 'Estimate render time from frames and per-frame cost.',
        category: ToolCategory.animator,
        tags: <String>['render', 'estimate', 'time', 'farm'],
        synonyms: <String>['how long will this render', 'render estimate'],
        parameters: <ToolParameter>[
          _num('frames', 'Frames to render.'),
          _num('secondsPerFrame', 'Rendered seconds per frame.', fallback: 2),
          _num('machines', 'Parallel machines.', fallback: 1),
        ],
        run: (args) async {
          final frames = _int(args['frames'], 'frames');
          final perFrame = _number(args['secondsPerFrame'], 'secondsPerFrame');
          final machines = _int(args['machines'], 'machines');
          if (machines < 1) {
            return const ToolResult.failure('machines must be at least 1.');
          }
          if (perFrame <= 0) {
            return const ToolResult.failure(
              'secondsPerFrame must be greater than 0.',
            );
          }
          final totalSeconds = frames * perFrame / machines;
          return ToolResult.success(<String, dynamic>{
            'totalSeconds': _round(totalSeconds, 1),
            'hours': _round(totalSeconds / 3600, 2),
            'humanReadable': _humanDuration(totalSeconds),
            'perFrameSeconds': perFrame,
            'machines': machines,
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.assetSize',
        name: 'Estimate Video Size',
        description: 'Estimate a video file size from bitrate and duration.',
        category: ToolCategory.animator,
        tags: <String>['size', 'bitrate', 'estimate', 'delivery'],
        synonyms: <String>['how big will this file be', 'file size estimate'],
        parameters: <ToolParameter>[
          _num('bitrateMbps', 'Bitrate in megabits per second.'),
          _num('seconds', 'Duration in seconds.'),
        ],
        run: (args) async {
          final mbps = _number(args['bitrateMbps'], 'bitrateMbps');
          final seconds = _number(args['seconds'], 'seconds');
          if (mbps <= 0 || seconds < 0) {
            return const ToolResult.failure(
              'bitrateMbps must be above 0 and seconds cannot be negative.',
            );
          }
          final bytes = mbps * 1000000 / 8 * seconds;
          return ToolResult.success(<String, dynamic>{
            'bytes': bytes.round(),
            'humanReadable': _humanDecimalBytes(bytes.round()),
            'note': 'Assumes constant bitrate (CBR). Megabytes are decimal '
                '(10^6), matching bitrate arithmetic.',
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.bitrateForSize',
        name: 'Bitrate for Target Size',
        description: 'Work out the bitrate needed to hit a target file size.',
        category: ToolCategory.animator,
        tags: <String>['bitrate', 'target', 'size', 'compression'],
        synonyms: <String>['what bitrate for 100mb', 'compress to size'],
        parameters: <ToolParameter>[
          _num('targetMegabytes', 'Target size in megabytes.'),
          _num('seconds', 'Duration in seconds.'),
        ],
        run: (args) async {
          final mb = _number(args['targetMegabytes'], 'targetMegabytes');
          final seconds = _number(args['seconds'], 'seconds');
          if (mb <= 0) {
            return const ToolResult.failure('targetMegabytes must be above 0.');
          }
          if (seconds <= 0) {
            return const ToolResult.failure('seconds must be above 0.');
          }
          final bits = mb * 8 * 1000000;
          final mbps = bits / seconds / 1000000;
          return ToolResult.success(<String, dynamic>{
            'bitrateMbps': _round(mbps, 3),
            'targetMegabytes': mb,
            'seconds': seconds,
            'note': 'Megabytes (10^6), matching how encoder UIs show size.',
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.resolutionInfo',
        name: 'Resolution Facts',
        description: 'Report pixel counts, aspect ratio and megapixels.',
        category: ToolCategory.animator,
        tags: <String>['resolution', 'aspect', 'pixels', '4k', 'hd'],
        synonyms: <String>['resolution info', 'aspect ratio calculator'],
        parameters: <ToolParameter>[
          _num('width', 'Width in pixels.', required: true),
          _num('height', 'Height in pixels.', required: true),
        ],
        run: (args) async {
          final width = _int(args['width'], 'width');
          final height = _int(args['height'], 'height');
          if (width <= 0 || height <= 0) {
            return const ToolResult.failure(
              'width and height must both be above 0.',
            );
          }
          final pixels = width * height;
          return ToolResult.success(<String, dynamic>{
            'width': width,
            'height': height,
            'pixels': pixels,
            'megapixels': _round(pixels / 1000000, 2),
            'aspectRatio': _simplifyRatio(width, height),
            'name': _resolutionName(width, height),
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.aspectRatio',
        name: 'Aspect Ratio',
        description: 'Reduce a resolution to its simplest aspect ratio.',
        category: ToolCategory.animator,
        tags: <String>['aspect', 'ratio', 'simplify'],
        synonyms: <String>['simplify aspect ratio'],
        parameters: <ToolParameter>[
          _num('width', 'Width in pixels.', required: true),
          _num('height', 'Height in pixels.', required: true),
        ],
        run: (args) async => ToolResult.success(<String, dynamic>{
              'ratio': _simplifyRatio(
                _int(args['width'], 'width'),
                _int(args['height'], 'height'),
              ),
            }),
      ),
      ToolDescriptor(
        id: 'anim.slowMotion',
        name: 'Slow Motion Factor',
        description: 'Frames needed for slow motion and the resulting speed.',
        category: ToolCategory.animator,
        tags: <String>['slow motion', 'speed', 'ramp', 'time stretch'],
        synonyms: <String>['slow motion frames', 'time stretch'],
        parameters: <ToolParameter>[
          _num('sourceFrames', 'Frames in the original take.', required: true),
          _num('speedPercent', 'Playback speed as a percentage.', fallback: 50),
          _text('fps', 'Timeline frame rate.', defaultValue: '24'),
        ],
        run: (args) async {
          final sourceFrames = _int(args['sourceFrames'], 'sourceFrames');
          final percent = _number(args['speedPercent'], 'speedPercent');
          final fps = _resolveFps(args['fps']) ?? 24;
          if (percent <= 0 || percent > 100) {
            return const ToolResult.failure(
              'speedPercent must be above 0 and at most 100.',
            );
          }
          final outputFrames = (sourceFrames / (percent / 100)).round();
          return ToolResult.success(<String, dynamic>{
            'outputFrames': outputFrames,
            'extraFrames': outputFrames - sourceFrames,
            'speed': '${_round(percent / 100, 3)}x',
            'outputSeconds': _round(outputFrames / fps, 3),
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.audioFrames',
        name: 'Audio Frame Alignment',
        description: 'Convert audio sample count to timeline frames.',
        category: ToolCategory.animator,
        tags: <String>['audio', 'samples', 'frames', 'sync'],
        synonyms: <String>['samples to frames', 'audio to frames'],
        parameters: <ToolParameter>[
          _num('samples', 'Audio samples.', required: true),
          _text('sampleRate', 'Sample rate in Hz.', defaultValue: '48000'),
          _text('fps', 'Timeline frame rate.', defaultValue: '24'),
        ],
        run: (args) async {
          final samples = _int(args['samples'], 'samples');
          final rate = _int(args['sampleRate'], 'sampleRate');
          final fps = _resolveFps(args['fps']);
          if (fps == null) {
            return ToolResult.failure('Unknown frame rate "${args['fps']}".');
          }
          if (rate <= 0) {
            return const ToolResult.failure('sampleRate must be above 0.');
          }
          final seconds = samples / rate;
          return ToolResult.success(<String, dynamic>{
            'seconds': _round(seconds, 4),
            'frames': (seconds * fps).round(),
            'samplesPerFrame': _round(rate / fps, 2),
            'fps': args['fps'],
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.framesPerSecond',
        name: 'Frames in a Second',
        description: 'How many frames pass in one second at a given rate.',
        category: ToolCategory.animator,
        tags: <String>['frames', 'second', 'fps', 'count'],
        synonyms: <String>['how many frames per second'],
        parameters: <ToolParameter>[
          _text('fps', 'Frame rate.', defaultValue: '24'),
          _num('seconds', 'How many seconds.', fallback: 1),
        ],
        run: (args) async {
          final fps = _resolveFps(args['fps']);
          if (fps == null) {
            return ToolResult.failure('Unknown frame rate "${args['fps']}".');
          }
          final seconds = _number(args['seconds'], 'seconds');
          return ToolResult.success(<String, dynamic>{
            'frames': (fps * seconds).round(),
            'fps': args['fps'],
            'seconds': seconds,
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.deliveryCheck',
        name: 'Delivery Spec Check',
        description: 'Check a render against a delivery specification.',
        category: ToolCategory.animator,
        tags: <String>['delivery', 'spec', 'check', 'compliance'],
        synonyms: <String>['does this meet spec', 'delivery check'],
        parameters: <ToolParameter>[
          _num('width', 'Rendered width.', required: true),
          _num('height', 'Rendered height.', required: true),
          _text('fps', 'Rendered frame rate.', required: true),
          _num('bitrateMbps', 'Rendered bitrate.', required: true),
          _num('maxMegabytes', 'Maximum allowed size in MB.', required: true),
          _num('durationSeconds', 'Rendered duration.', required: true),
        ],
        run: (args) async {
          final width = _int(args['width'], 'width');
          final height = _int(args['height'], 'height');
          final maxMb = _number(args['maxMegabytes'], 'maxMegabytes');
          final seconds = _number(args['durationSeconds'], 'durationSeconds');
          final bitrate = _number(args['bitrateMbps'], 'bitrateMbps');
          final fps = _resolveFps(args['fps']);

          final problems = <String>[];
          if (fps == null) {
            problems.add('Frame rate "${args['fps']}" is not a standard rate.');
          }
          if (bitrate <= 0) problems.add('Bitrate must be above 0.');
          final megabytes = bitrate * 1000000 / 8 * seconds / 1000000;
          if (megabytes > maxMb) {
            problems.add(
              'File is ${_round(megabytes, 1)} MB, over the '
              '${_round(maxMb, 1)} MB limit.',
            );
          }
          return ToolResult.success(<String, dynamic>{
            'passes': problems.isEmpty,
            'resolution': '${width}x$height',
            'estimatedMegabytes': _round(megabytes, 2),
            'maxMegabytes': maxMb,
            'problems': problems,
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.frameStep',
        name: 'Frame Step / Stride',
        description: 'Every nth frame in a range, for frame grabs.',
        category: ToolCategory.animator,
        tags: <String>['frame', 'step', 'stride', 'grab', 'every'],
        synonyms: <String>['every tenth frame', 'frame stride'],
        parameters: <ToolParameter>[
          _num('totalFrames', 'Frames in the clip.', required: true),
          _num('every', 'Take every Nth frame.', fallback: 10),
        ],
        run: (args) async {
          final total = _int(args['totalFrames'], 'totalFrames');
          final every = _int(args['every'], 'every');
          if (every < 1) {
            return const ToolResult.failure('every must be at least 1.');
          }
          final taken = <int>[];
          for (var frame = 0; frame < total; frame += every) {
            taken.add(frame);
          }
          return ToolResult.success(<String, dynamic>{
            'count': taken.length,
            'frames': taken,
            'every': every,
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.stopsToExposure',
        name: 'Stops to Exposure',
        description: 'Convert a stop difference into an exposure multiplier.',
        category: ToolCategory.animator,
        tags: <String>['stops', 'exposure', 'light', 'maths'],
        synonyms: <String>['how many stops', 'exposure maths'],
        parameters: <ToolParameter>[
          _num('stops', 'Difference in stops.', required: true),
        ],
        run: (args) async {
          final stops = _number(args['stops'], 'stops');
          return ToolResult.success(<String, dynamic>{
            'stops': stops,
            'multiplier': _round(_pow2(stops.toDouble()), 4),
            'inverse': _round(1 / _pow2(stops.toDouble()), 4),
          });
        },
      ),
      ToolDescriptor(
        id: 'anim.frameRates',
        name: 'Known Frame Rates',
        description: 'List standard frame rates and their drop-frame status.',
        category: ToolCategory.animator,
        tags: <String>['fps', 'rates', 'reference', 'list'],
        synonyms: <String>['what frame rates are there', 'list frame rates'],
        parameters: <ToolParameter>[],
        run: (args) async => ToolResult.success(<Map<String, dynamic>>[
              for (final entry in kFrameRates.entries)
                <String, dynamic>{
                  'fps': entry.key,
                  'exact': _round(entry.value, 3),
                  'dropFrame': kDropFrameRates.contains(entry.key),
                },
            ]),
      ),
    ];

// ── helpers ─────────────────────────────────────────────────────────────

double? _resolveFps(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim().toLowerCase();
  final known = kFrameRates[text];
  if (known != null) return known;
  return double.tryParse(text);
}

num _number(Object? value, String name) {
  if (value is num) return value;
  final parsed = num.tryParse('${value ?? ''}');
  if (parsed == null) {
    throw ToolArgumentError('"$name" must be a number, got "${value ?? ''}".');
  }
  return parsed;
}

int _int(Object? value, String name) => _number(value, name).round();

double _round(num value, int places) {
  final factor = _pow10(places);
  return (value * factor).round() / factor;
}

double _pow10(int places) => math.pow(10, places).toDouble();

double _pow2(double exponent) => math.pow(2, exponent).toDouble();

/// Frames per second used for timecode maths, rounded to a whole number.
int _fpsBase(Object? fps) {
  final resolved = _resolveFps(fps);
  if (resolved == null) return 24;
  return resolved.round();
}

String _timecodeFromFrames(int frames, String fpsLabel) {
  final base = _fpsBase(fpsLabel);
  final dropFrame = kDropFrameRates.contains(fpsLabel.toLowerCase());
  final total = frames < 0 ? 0 : frames;

  // Drop-frame rates renumber timecode so it stays aligned with wall-clock
  // recording: two frame numbers are skipped each minute except every tenth.
  final framesPer10Minutes = base * 60 * 10 - (dropFrame ? (18 * base / 15).round() : 0);
  final framesPerMinute = base * 60 - (dropFrame ? (2 * base / 15).round() : 0);

  final tenMinuteBlocks = total ~/ framesPer10Minutes;
  var remainder = total % framesPer10Minutes;

  var minutes = tenMinuteBlocks * 10;
  if (remainder >= framesPerMinute) {
    final extra = remainder ~/ framesPerMinute;
    minutes += extra;
    remainder %= framesPerMinute;
  }

  final seconds = remainder ~/ base;
  final frameNumber = remainder % base;
  final hours = minutes ~/ 60;
  final minutePart = minutes % 60;

  return '${_pad(hours, 2)}:${_pad(minutePart, 2)}:${_pad(seconds, 2)}:'
      '${_pad(frameNumber, 2)}';
}

int? _parseTimecode(String input, String fpsLabel) {
  final base = _fpsBase(fpsLabel);
  final parts = input.trim().split(':');
  if (parts.length == 4) {
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2]);
    final frames = int.tryParse(parts[3]);
    if (hours == null || minutes == null || seconds == null || frames == null) {
      return null;
    }
    return ((hours * 60 + minutes) * 60 + seconds) * base + frames;
  }
  if (parts.length == 3) {
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final secondsPart = parts[2];
    final dot = secondsPart.indexOf('.');
    if (dot < 0) return null;
    final seconds = int.tryParse(secondsPart.substring(0, dot));
    final fraction = double.tryParse(secondsPart.substring(dot));
    if (hours == null || minutes == null || seconds == null || fraction == null) {
      return null;
    }
    return ((hours * 60 + minutes) * 60 + seconds) * base +
        (fraction * base).round();
  }
  return null;
}

String _pad(int value, int width) =>
    value.toString().padLeft(width, '0');

/// Decimal sizes, matching how bitrate maths and encoder UIs count.
///
/// Video delivery uses 10^6 bytes per megabyte, so showing 71.5 MiB for what
/// the tool calculated as 75 MB would be quietly wrong.
String _humanDecimalBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000000) return '${_round(bytes / 1000, 1)} KB';
  if (bytes < 1000000000) return '${_round(bytes / 1000000, 1)} MB';
  return '${_round(bytes / 1000000000, 2)} GB';
}

String _humanDuration(double seconds) {
  if (seconds < 60) return '${_round(seconds, 1)}s';
  if (seconds < 3600) {
    final minutes = seconds ~/ 60;
    return '${minutes}m ${(seconds % 60).round()}s';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes}m';
}

String _simplifyRatio(int width, int height) {
  var a = width;
  var b = height;
  while (b != 0) {
    final t = b;
    b = a % b;
    a = t;
  }
  final divisor = a == 0 ? 1 : a;
  return '${width ~/ divisor}:${height ~/ divisor}';
}

String _resolutionName(int width, int height) {
  if (width >= 7680) return '8K';
  if (width >= 3840) return '4K UHD';
  if (width >= 2560) return '2.5K / QHD';
  if (width >= 1920) return '1080p / Full HD';
  if (width >= 1280) return '720p / HD';
  return 'SD';
}
