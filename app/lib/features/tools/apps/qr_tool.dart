import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import 'tool_io.dart';
import 'tool_shell.dart';

/// Decode the first QR code found in the image at [path].
///
/// Returns null when the image is readable but contains no QR code. Throws
/// [FormatException] when the file is not an image at all.
String? decodeQrFromPath(String path) {
  final image = img.decodeImage(File(path).readAsBytesSync());
  if (image == null) {
    throw const FormatException('This file is not an image this tool can read.');
  }

  final source = RGBLuminanceSource(
    image.width,
    image.height,
    image
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.abgr)
        .buffer
        .asInt32List(),
  );
  final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
  try {
    return QRCodeReader().decode(bitmap).text;
  } on NotFoundException {
    return null;
  } on FormatException {
    return null;
  } on ChecksumException {
    return null;
  }
}

enum _Format {
  qr('QR code', true),
  code128('Code 128', false),
  ean13('EAN-13', false),
  code39('Code 39', false);

  const _Format(this.label, this.square);

  final String label;
  final bool square;

  Barcode get barcode => switch (this) {
        _Format.qr => Barcode.qrCode(
            errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
          ),
        _Format.code128 => Barcode.code128(),
        _Format.ean13 => Barcode.ean13(),
        _Format.code39 => Barcode.code39(),
      };

  String get hint => switch (this) {
        _Format.qr => 'A link, text, wifi details — anything readable by a '
            'phone camera.',
        _Format.code128 => 'Letters and digits. Used on labels and parcels.',
        _Format.ean13 => 'Exactly 12 or 13 digits. The last digit is the check '
            'digit, and is calculated if you give 12.',
        _Format.code39 => 'Capital letters, digits and a few symbols. Older '
            'industrial labels.',
      };
}

/// Generates QR codes and barcodes, saves them as PNG, and reads QR codes from
/// an image.
class QrTool extends StatefulWidget {
  /// Create the tool.
  const QrTool({super.key});

  @override
  State<QrTool> createState() => _QrToolState();
}

class _QrToolState extends State<QrTool> {
  final TextEditingController _data = TextEditingController();
  final TextEditingController _output = TextEditingController();
  final TextEditingController _decodePath = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();

  _Format _format = _Format.qr;
  bool _saving = false;
  bool _decoding = false;
  String? _saveResult;
  String? _error;
  String? _decoded;
  String? _decodeError;

  @override
  void initState() {
    super.initState();
    _output.text = _defaultOutput();
  }

  @override
  void dispose() {
    _data.dispose();
    _output.dispose();
    _decodePath.dispose();
    super.dispose();
  }

  String _defaultOutput() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '$homeDirectory${Platform.pathSeparator}barcode-$stamp.png';
  }

  String get _text => _data.text.trim();

  bool get _valid =>
      _text.isNotEmpty && _format.barcode.isValid(_text);

  Future<void> _save() async {
    if (!_valid) {
      setState(() => _error = 'Enter something to encode first.');
      return;
    }
    final path = _output.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Choose where to save the PNG.');
      return;
    }
    final boundary =
        _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      setState(() => _error = 'The preview is not ready yet. Try again.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _saveResult = null;
    });
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        setState(() {
          _saving = false;
          _error = 'The PNG could not be produced.';
        });
        return;
      }
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveResult = 'Saved ${formatBytes(file.lengthSync())}.\n\n${file.path}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The PNG could not be saved: $error';
      });
    }
  }

  Future<void> _pickDecode() async {
    final chosen = await pickFile(context, start: _decodePath.text.trim());
    if (chosen == null) return;
    setState(() {
      _decodePath.text = chosen;
      _decoded = null;
      _decodeError = null;
    });
  }

  Future<void> _decode() async {
    final path = _decodePath.text.trim();
    if (path.isEmpty) {
      setState(() => _decodeError = 'Choose an image containing a QR code.');
      return;
    }
    if (!File(path).existsSync()) {
      setState(() => _decodeError = 'That file does not exist.');
      return;
    }
    setState(() {
      _decoding = true;
      _decoded = null;
      _decodeError = null;
    });
    try {
      final text = await Isolate.run(() => decodeQrFromPath(path));
      if (!mounted) return;
      setState(() {
        _decoding = false;
        if (text == null) {
          _decodeError = 'No QR code was found in that image. Cropping to the '
              'code and trying again often helps.';
        } else {
          _decoded = text;
        }
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _decoding = false;
        _decodeError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _decoding = false;
        _decodeError = 'The image could not be read: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewHeight = _format.square ? 260.0 : 130.0;

    return ToolShell(
      title: 'QR & barcode',
      howTo: 'Type the content, pick a format, then save the PNG. To read a QR '
          'code, choose a screenshot or photo of it below.',
      children: <Widget>[
        ToolSection(
          title: 'Create',
          icon: Icons.qr_code_2,
          children: <Widget>[
            TextField(
              controller: _data,
              minLines: 2,
              maxLines: 5,
              onChanged: (_) => setState(() {
                _error = null;
                _saveResult = null;
              }),
              decoration: InputDecoration(
                labelText: 'What should it say?',
                hintText: _format.hint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_Format>(
              initialValue: _format,
              decoration: const InputDecoration(
                labelText: 'Format',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<_Format>>[
                for (final format in _Format.values)
                  DropdownMenuItem<_Format>(
                    value: format,
                    child: Text(format.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _format = value;
                  _error = null;
                  _saveResult = null;
                });
              },
            ),
            const SizedBox(height: 14),
            if (_text.isEmpty)
              const ToolNote(
                'The preview appears here as soon as there is something to '
                'encode.',
              )
            else
              Center(
                child: RepaintBoundary(
                  key: _previewKey,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: BarcodeWidget(
                      barcode: _format.barcode,
                      data: _text,
                      width: _format.square ? 228 : 320,
                      height: previewHeight,
                      drawText: !_format.square,
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      errorBuilder: (_, String error) => SizedBox(
                        width: 260,
                        child: Text(
                          'This content does not fit ${_format.label}: $error',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _output,
              decoration: const InputDecoration(
                labelText: 'Save the PNG as',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final folder = await pickDirectory(
                            context,
                            start: File(_output.text.trim()).parent.path,
                          );
                          if (folder == null) return;
                          final name = _output.text
                              .split(Platform.pathSeparator)
                              .last;
                          setState(() {
                            _output.text =
                                '$folder${Platform.pathSeparator}$name';
                          });
                        },
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Choose folder'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Save PNG'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (_saveResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _saveResult!,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
          ],
        ),
        ToolSection(
          title: 'Read a QR code',
          icon: Icons.qr_code_scanner,
          children: <Widget>[
            TextField(
              controller: _decodePath,
              onChanged: (_) => setState(() {
                _decoded = null;
                _decodeError = null;
              }),
              decoration: const InputDecoration(
                labelText: 'Image of the code',
                hintText: 'Choose a PNG or JPEG, or paste its full path.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _decoding ? null : _pickDecode,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Choose image'),
                ),
                FilledButton.icon(
                  onPressed: _decoding ? null : _decode,
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(_decoding ? 'Reading…' : 'Read the code'),
                ),
              ],
            ),
            if (_decodeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _decodeError!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (_decoded != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SelectableText(
                  _decoded!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
          ],
        ),
        const ToolSection(
          title: 'Limits',
          icon: Icons.info_outline,
          children: <Widget>[
            ToolNote(
              'The generated image is saved as PNG at three times the preview '
              'size, which is sharp enough to print and large enough for a '
              'phone camera.',
            ),
            ToolNote(
              'Reading supports QR codes only. Linear barcodes such as EAN-13 '
              'and Code 128 are generated but not decoded.',
            ),
            ToolNote(
              'The content is not sent anywhere. Everything is encoded and '
              'decoded on this device.',
            ),
            ToolNote(
              'A QR code is not encrypted. Anyone who scans it sees the text, '
              'so do not put a password in a code you would not write on a '
              'postcard.',
              warning: true,
            ),
          ],
        ),
      ],
    );
  }
}
