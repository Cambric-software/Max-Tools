import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'tool_io.dart';
import 'tool_shell.dart';

/// The most pixels this tool will decode. A 50-megapixel photo needs roughly
/// 200 MB once decoded, so the limit is about memory, not file size.
const int maxImagePixels = 50 * 1000 * 1000;

/// The largest input file, in bytes.
const int maxImageBytes = 64 * 1024 * 1024;

/// An image that was processed, with its new dimensions.
typedef ProcessedImage = ({Uint8List bytes, int width, int height});

/// Read the width and height without keeping the decoded image.
({int width, int height})? imageSizeFromPath(String path) {
  final image = img.decodeImage(File(path).readAsBytesSync());
  if (image == null) return null;
  return (width: image.width, height: image.height);
}

/// Decode, optionally resize, and re-encode one image file.
///
/// [targetWidth] keeps the aspect ratio; pass null to leave the size alone.
/// PNG ignores [quality], because PNG is lossless.
ProcessedImage processImageFile(
  String path, {
  int? targetWidth,
  required String format,
  required int quality,
}) {
  final input = File(path).readAsBytesSync();
  var image = img.decodeImage(input);
  if (image == null) {
    throw const FormatException('This file is not an image this tool can read.');
  }
  if (image.width * image.height > maxImagePixels) {
    throw const FormatException('That image has too many pixels to process in '
        'memory. Resize it with a photo editor first.');
  }

  // Phone photos often carry an orientation flag instead of rotated pixels.
  image = img.bakeOrientation(image);

  if (targetWidth != null &&
      targetWidth > 0 &&
      targetWidth != image.width) {
    image = img.copyResize(
      image,
      width: targetWidth,
      interpolation: img.Interpolation.average,
    );
  }

  final Uint8List output = switch (format) {
    'jpg' => img.encodeJpg(image, quality: quality.clamp(1, 100)),
    'png' => img.encodePng(image),
    'webp' => img.encodeWebP(image, quality: quality.clamp(1, 100)),
    _ => throw FormatException('Unknown output format "$format".'),
  };

  return (bytes: output, width: image.width, height: image.height);
}

enum _Format {
  jpeg('jpg', 'JPEG', 'jpg', 'Smallest for photos. Slight quality loss.'),
  png('png', 'PNG', 'png', 'Lossless, but usually much larger for photos.'),
  webp('webp', 'WebP', 'webp', 'Small like JPEG, supported by modern browsers.');

  const _Format(this.id, this.label, this.extension, this.description);

  final String id;
  final String label;
  final String extension;
  final String description;

  bool get usesQuality => this != _Format.png;
}

/// Resizes, converts and re-encodes one image.
class ImageTool extends StatefulWidget {
  /// Create the tool.
  const ImageTool({super.key});

  @override
  State<ImageTool> createState() => _ImageToolState();
}

class _ImageToolState extends State<ImageTool> {
  final TextEditingController _path = TextEditingController();
  final TextEditingController _width = TextEditingController();

  _Format _format = _Format.jpeg;
  int _quality = 82;
  int? _originalWidth;
  int? _originalHeight;
  int? _originalBytes;

  bool _busy = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _path.dispose();
    _width.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final chosen = await pickFile(context, start: _path.text.trim());
    if (chosen == null) return;
    _path.text = chosen;
    await _inspect(chosen);
  }

  Future<void> _inspect(String path) async {
    setState(() {
      _result = null;
      _error = null;
      _originalWidth = null;
      _originalHeight = null;
      _originalBytes = null;
    });
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final size = file.lengthSync();
      if (size > maxImageBytes) {
        setState(() => _error = 'That file is ${formatBytes(size)}. The limit '
            'is ${formatBytes(maxImageBytes)}.');
        return;
      }
      final dimensions = await Isolate.run(() => imageSizeFromPath(path));
      if (!mounted) return;
      if (dimensions == null) {
        setState(() => _error = 'This file is not an image this tool can read.');
        return;
      }
      setState(() {
        _originalWidth = dimensions.width;
        _originalHeight = dimensions.height;
        _originalBytes = size;
        _width.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'The image could not be read: $error');
    }
  }

  Future<void> _run() async {
    final path = _path.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Choose an image first.');
      return;
    }
    if (!File(path).existsSync()) {
      setState(() => _error = 'That file does not exist.');
      return;
    }
    final widthText = _width.text.trim();
    final int? targetWidth;
    if (widthText.isEmpty) {
      targetWidth = null;
    } else {
      targetWidth = int.tryParse(widthText);
      if (targetWidth == null || targetWidth < 16) {
        setState(() => _error = 'Enter a width of at least 16 pixels, or leave '
            'it empty to keep the current width.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });

    try {
      final format = _format.id;
      final quality = _quality;
      final processed = await Isolate.run(
        () => processImageFile(
          path,
          targetWidth: targetWidth,
          format: format,
          quality: quality,
        ),
      );
      final destination = _uniqueOutput(path);
      final temporary = File('$destination.part');
      await temporary.writeAsBytes(processed.bytes, flush: true);
      await temporary.rename(destination);

      final before = _originalBytes ?? 0;
      final after = processed.bytes.length;
      final saved = before - after;
      final percent = before == 0 ? 0.0 : saved / before * 100;
      final comparison = before == 0
          ? formatBytes(after)
          : saved >= 0
              ? '${formatBytes(before)} → ${formatBytes(after)} '
                  '(${percent.toStringAsFixed(0)}% smaller)'
              : '${formatBytes(before)} → ${formatBytes(after)} '
                  '(${(-percent).toStringAsFixed(0)}% larger)';

      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = '$comparison\n'
            '${_originalWidth ?? '?'}×${_originalHeight ?? '?'} → '
            '${processed.width}×${processed.height}\n\n'
            '$destination';
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The file could not be written: ${error.message}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong: $error';
      });
    }
  }

  String _uniqueOutput(String input) {
    final dot = input.lastIndexOf('.');
    final slash = input.lastIndexOf(Platform.pathSeparator);
    final base = dot > slash ? input.substring(0, dot) : input;
    final candidate = '$base-max.${_format.extension}';
    if (!File(candidate).existsSync()) return candidate;
    for (var attempt = 2; attempt < 1000; attempt++) {
      final next = '$base-max ($attempt).${_format.extension}';
      if (!File(next).existsSync()) return next;
    }
    return '$base-max-${DateTime.now().millisecondsSinceEpoch}.'
        '${_format.extension}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = _path.text.trim();
    final hasImage = _originalWidth != null && File(path).existsSync();

    return ToolShell(
      title: 'Image resize & convert',
      howTo: 'Choose a photo, set a new width if you want one, pick a format, '
          'then process. The result is written beside the original and the '
          'original is left alone.',
      children: <Widget>[
        ToolSection(
          title: 'Which image?',
          icon: Icons.image_outlined,
          children: <Widget>[
            TextField(
              controller: _path,
              onChanged: (String value) {
                if (value.trim() != path) {
                  setState(() {
                    _originalWidth = null;
                    _originalHeight = null;
                    _originalBytes = null;
                    _result = null;
                    _error = null;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Image path',
                hintText: 'Choose a file, or paste its full path.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Choose image'),
            ),
            if (hasImage) ...<Widget>[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          'Preview unavailable, but the file can still be '
                          'processed.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_originalWidth ?? '?'}×${_originalHeight ?? '?'} pixels · '
                '${formatBytes(_originalBytes ?? 0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        ToolSection(
          title: 'What should happen?',
          icon: Icons.tune,
          children: <Widget>[
            TextField(
              controller: _width,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New width in pixels (optional)',
                hintText: _originalWidth == null
                    ? 'Leave empty to keep the size'
                    : 'Currently ${_originalWidth!} px',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final fraction in <double>[0.75, 0.5, 0.25])
                  ActionChip(
                    label: Text('${(fraction * 100).round()}% width'),
                    onPressed: _originalWidth == null || _busy
                        ? null
                        : () => setState(() {
                              _width.text =
                                  (_originalWidth! * fraction).round().toString();
                            }),
                  ),
                ActionChip(
                  label: const Text('Keep width'),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _width.clear()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_Format>(
              initialValue: _format,
              decoration: const InputDecoration(
                labelText: 'Output format',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<_Format>>[
                for (final format in _Format.values)
                  DropdownMenuItem<_Format>(
                    value: format,
                    child: Text(format.label),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (_Format? value) {
                      if (value != null) setState(() => _format = value);
                    },
            ),
            const SizedBox(height: 6),
            Text(
              _format.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_format.usesQuality) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Quality',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '$_quality',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _quality.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '$_quality',
                onChanged: _busy
                    ? null
                    : (double value) =>
                        setState(() => _quality = value.round()),
              ),
              Text(
                'Below about 75, blocky patches start to show in photos. 82 '
                'is a good default.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _run,
                icon: const Icon(Icons.photo_size_select_large, size: 18),
                label: Text(_busy ? 'Processing…' : 'Process the image'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.check_circle_outline,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _result!,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const ToolSection(
          title: 'Honest advice',
          icon: Icons.info_outline,
          children: <Widget>[
            ToolNote(
              'Resizing is what makes a photo smaller. Re-encoding a photo as '
              'PNG usually makes it several times larger, because PNG is '
              'lossless. Use JPEG or WebP for photographs and PNG for '
              'screenshots, logos and images with flat colour.',
            ),
            ToolNote(
              'Quality is a trade, not a free win. Comparing the result at '
              '100% is the only reliable check.',
            ),
            ToolNote(
              'The original file is untouched. Delete it yourself once you are '
              'happy with the result.',
            ),
            ToolNote(
              'Images are decoded in memory. The limit is 50 megapixels, which '
              'is far above most phone cameras.',
            ),
            ToolNote(
              'Metadata such as location is not copied: the image is re-encoded '
              'from its pixels. That is usually good for privacy, and it also '
              'drops colour profiles, so colours may shift slightly.',
            ),
          ],
        ),
      ],
    );
  }
}
