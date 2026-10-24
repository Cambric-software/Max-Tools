import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'tool_io.dart';
import 'tool_shell.dart';

/// Page sizes this tool offers.
enum PdfSize {
  a4('A4', PdfPageFormat.a4),
  letter('Letter', PdfPageFormat.letter);

  const PdfSize(this.label, this.format);

  final String label;
  final PdfPageFormat format;
}

/// Build a PDF from a title and body text.
///
/// The standard PDF fonts cover Latin text. Text in other scripts needs an
/// embedded font, which this build does not ship, so it is refused instead of
/// rendered as empty boxes.
Future<Uint8List> buildTextPdf({
  required String title,
  required String body,
  required PdfSize size,
  required double fontSize,
  required bool pageNumbers,
}) async {
  if (!_isLatin(body) || !_isLatin(title)) {
    throw const FormatException('This build can only set Latin text. Arabic, '
        'Chinese and other scripts need an embedded font, which is not '
        'included.');
  }

  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: size.format,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
      footer: pageNumbers
          ? (pw.Context context) => pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              )
          : null,
      build: (pw.Context context) => <pw.Widget>[
        if (title.trim().isNotEmpty) ...<pw.Widget>[
          pw.Header(
            level: 0,
            child: pw.Text(
              title.trim(),
              style: pw.TextStyle(
                fontSize: fontSize + 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
        ],
        pw.Paragraph(
          text: body,
          style: pw.TextStyle(fontSize: fontSize, lineSpacing: 3),
        ),
      ],
    ),
  );
  return document.save();
}

/// Build a PDF with one image per page.
Future<Uint8List> buildImagePdf({
  required List<Uint8List> images,
  required PdfSize size,
  required bool pageNumbers,
}) async {
  if (images.isEmpty) {
    throw const FormatException('Choose at least one image.');
  }
  final document = pw.Document();
  for (var index = 0; index < images.length; index++) {
    // Validate first: a corrupt image should name itself, not fail inside the
    // layout engine halfway through the document.
    if (img.decodeImage(images[index]) == null) {
      throw FormatException('Image ${index + 1} is not a format this tool can '
          'read.');
    }
    document.addPage(
      pw.Page(
        pageFormat: size.format,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Center(
                child: pw.Image(
                  pw.MemoryImage(images[index]),
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
            if (pageNumbers)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '${index + 1} of ${images.length}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
          ],
        ),
      ),
    );
  }
  return document.save();
}

bool _isLatin(String text) {
  for (final rune in text.runes) {
    if (rune < 0x250) continue;
    // Allow common punctuation and symbols above the basic Latin block.
    if (rune >= 0x2000 && rune <= 0x206f) continue;
    if (rune >= 0x20a0 && rune <= 0x20cf) continue;
    return false;
  }
  return true;
}

enum _Mode { text, images }

/// Creates PDFs from text and images.
///
/// It does not read, merge, split or edit existing PDFs. Saying so on the screen
/// matters more than a broader name would.
class PdfTool extends StatefulWidget {
  /// Create the tool.
  const PdfTool({super.key});

  @override
  State<PdfTool> createState() => _PdfToolState();
}

class _PdfToolState extends State<PdfTool> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _output = TextEditingController();
  final List<String> _images = <String>[];

  _Mode _mode = _Mode.text;
  PdfSize _size = PdfSize.a4;
  double _fontSize = 11;
  bool _pageNumbers = true;
  bool _busy = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _output.text = _defaultOutput();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _output.dispose();
    super.dispose();
  }

  String _defaultOutput() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '$homeDirectory${Platform.pathSeparator}document-$stamp.pdf';
  }

  Future<void> _addImage() async {
    final chosen = await pickFile(
      context,
      start: _images.isEmpty ? homeDirectory : File(_images.last).parent.path,
    );
    if (chosen == null) return;
    setState(() {
      _images.add(chosen);
      _result = null;
      _error = null;
    });
  }

  Future<void> _build() async {
    final path = _output.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Choose where to save the PDF.');
      return;
    }
    if (_mode == _Mode.text && _body.text.trim().isEmpty) {
      setState(() => _error = 'Write something in the body first.');
      return;
    }
    if (_mode == _Mode.images && _images.isEmpty) {
      setState(() => _error = 'Add at least one image.');
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
      _error = null;
    });

    try {
      final Uint8List bytes;
      if (_mode == _Mode.text) {
        bytes = await buildTextPdf(
          title: _title.text,
          body: _body.text,
          size: _size,
          fontSize: _fontSize,
          pageNumbers: _pageNumbers,
        );
      } else {
        final loaded = <Uint8List>[];
        for (final imagePath in _images) {
          loaded.add(await File(imagePath).readAsBytes());
        }
        bytes = await buildImagePdf(
          images: loaded,
          size: _size,
          pageNumbers: _pageNumbers,
        );
      }

      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'Wrote ${formatBytes(bytes.length)}'
            '${_mode == _Mode.images ? ' across ${_images.length} '
                '${_images.length == 1 ? 'page' : 'pages'}' : ''}.\n\n'
            '${file.path}';
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
        _error = 'The PDF could not be built: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ToolShell(
      title: 'PDF builder',
      howTo: 'Turn text or a set of images into a PDF. Choose the page size and '
          'where to save it, then press Build.',
      children: <Widget>[
        ToolSection(
          title: 'What is going in?',
          icon: Icons.picture_as_pdf_outlined,
          children: <Widget>[
            SegmentedButton<_Mode>(
              segments: const <ButtonSegment<_Mode>>[
                ButtonSegment<_Mode>(
                  value: _Mode.text,
                  label: Text('Text'),
                  icon: Icon(Icons.text_fields, size: 18),
                ),
                ButtonSegment<_Mode>(
                  value: _Mode.images,
                  label: Text('Images'),
                  icon: Icon(Icons.image_outlined, size: 18),
                ),
              ],
              selected: <_Mode>{_mode},
              onSelectionChanged: _busy
                  ? null
                  : (Set<_Mode> selection) => setState(() {
                        _mode = selection.first;
                        _result = null;
                        _error = null;
                      }),
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.text) ...<Widget>[
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                minLines: 8,
                maxLines: 18,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  hintText: 'Write or paste the text here. Paragraph breaks are '
                      'kept.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ] else ...<Widget>[
              if (_images.isEmpty)
                const ToolNote('No images added yet. Each image becomes one '
                    'page, in the order shown.')
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      for (var index = 0; index < _images.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.image_outlined),
                          title: Text(
                            _images[index].split(Platform.pathSeparator).last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Page ${index + 1}'),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _images.removeAt(index);
                                      _result = null;
                                    }),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _addImage,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Add image'),
              ),
            ],
          ],
        ),
        ToolSection(
          title: 'How it should look',
          icon: Icons.tune,
          children: <Widget>[
            DropdownButtonFormField<PdfSize>(
              initialValue: _size,
              decoration: const InputDecoration(
                labelText: 'Page size',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<PdfSize>>[
                for (final size in PdfSize.values)
                  DropdownMenuItem<PdfSize>(
                    value: size,
                    child: Text(size.label),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (PdfSize? value) {
                      if (value != null) setState(() => _size = value);
                    },
            ),
            if (_mode == _Mode.text) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Text size',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${_fontSize.toStringAsFixed(0)} pt',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _fontSize,
                min: 8,
                max: 18,
                divisions: 10,
                label: '${_fontSize.toStringAsFixed(0)} pt',
                onChanged: _busy
                    ? null
                    : (double value) => setState(() => _fontSize = value),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Page numbers'),
              value: _pageNumbers,
              onChanged: _busy
                  ? null
                  : (bool value) => setState(() => _pageNumbers = value),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _output,
              decoration: const InputDecoration(
                labelText: 'Save the PDF as',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _build,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(_busy ? 'Building…' : 'Build the PDF'),
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
          title: 'What this can and cannot do',
          icon: Icons.info_outline,
          children: <Widget>[
            ToolNote(
              'It creates PDFs. It does not open, merge, split, rotate or edit '
              'an existing PDF.',
              warning: true,
            ),
            ToolNote(
              'Text uses the standard PDF fonts, which cover Latin script. '
              'Arabic, Chinese and other scripts are refused rather than '
              'printed as empty boxes.',
            ),
            ToolNote(
              'Images are placed one per page, scaled to fit and never '
              'cropped. Very large photos make a very large PDF.',
            ),
            ToolNote(
              'The PDF is not encrypted or password-protected. Anyone who opens '
              'the file can read it.',
            ),
          ],
        ),
      ],
    );
  }
}
