import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tool_shell.dart';

/// Colour work: read a colour in every notation, check that text on it is
/// readable, and derive a small palette from it.
///
/// The contrast check is the WCAG 2.1 formula and reports the same AA and AAA
/// pass or fail a browser audit would, so the verdict here matches the one an
/// accessibility checker gives.
class ColourToolkitTool extends StatefulWidget {
  /// Create the tool.
  const ColourToolkitTool({super.key});

  @override
  State<ColourToolkitTool> createState() => _ColourToolkitToolState();
}

class _ColourToolkitToolState extends State<ColourToolkitTool> {
  final TextEditingController _primary =
      TextEditingController(text: '#1B5E20');
  final TextEditingController _secondary =
      TextEditingController(text: '#FFFFFF');

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  Color? _parse(String text) {
    var value = text.trim().replaceAll('#', '');
    if (value.isEmpty) return null;
    if (value.length == 3) {
      value = value.split('').map((String c) => '$c$c').join();
    }
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static String _hex(Color colour) {
    final value = colour.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static String _rgb(Color colour) {
    final r = (colour.r * 255).round();
    final g = (colour.g * 255).round();
    final b = (colour.b * 255).round();
    return 'rgb($r, $g, $b)';
  }

  static String _hsl(Color colour) {
    final hsl = HSLColor.fromColor(colour);
    return 'hsl(${hsl.hue.round()}, ${(hsl.saturation * 100).round()}%, '
        '${(hsl.lightness * 100).round()}%)';
  }

  /// WCAG relative luminance.
  static double _luminance(Color colour) {
    double channel(double value) {
      return value <= 0.03928
          ? value / 12.92
          : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(colour.r) +
        0.7152 * channel(colour.g) +
        0.0722 * channel(colour.b);
  }

  static double _contrast(Color a, Color b) {
    final light = math.max(_luminance(a), _luminance(b));
    final dark = math.min(_luminance(a), _luminance(b));
    return (light + 0.05) / (dark + 0.05);
  }

  static List<Color> _harmony(Color base) {
    final hsl = HSLColor.fromColor(base);
    Color at(double degrees, double lightness) => hsl
        .withHue((hsl.hue + degrees) % 360)
        .withLightness(lightness.clamp(0.0, 1.0))
        .withSaturation(
          (hsl.saturation * (degrees == 0 ? 1 : 0.82)).clamp(0.0, 1.0),
        )
        .toColor();

    return <Color>[
      at(0, hsl.lightness * 0.72),
      at(0, hsl.lightness * 0.86),
      at(0, hsl.lightness),
      at(0, (hsl.lightness * 1.14).clamp(0.0, 1.0)),
      at(180, hsl.lightness),
      at(120, hsl.lightness),
      at(240, hsl.lightness),
      at(30, hsl.lightness),
      at(-30, hsl.lightness),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = _parse(_primary.text);
    final secondary = _parse(_secondary.text);
    final ratio =
        primary == null || secondary == null ? null : _contrast(primary, secondary);

    return ToolShell(
      title: 'Colour & design',
      howTo: 'Type a colour as #1B5E20 or 1B5E20 and see it in every notation. '
          'Put a text colour in the second box to check that it is readable on '
          'the first. The swatches below show tints, shades and harmonies '
          'derived from the first colour.',
      maxWidth: 980,
      children: <Widget>[
        ToolSection(
          title: 'Your colour',
          icon: Icons.palette_outlined,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _primary,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Colour (hex)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _Swatch(colour: primary),
              ],
            ),
            if (primary != null) ...<Widget>[
              const SizedBox(height: 14),
              _NotationRow(label: 'HEX', value: _hex(primary)),
              _NotationRow(label: 'RGB', value: _rgb(primary)),
              _NotationRow(label: 'HSL', value: _hsl(primary)),
            ] else
              const ToolNote(
                'A colour needs three or six hexadecimal digits, such as '
                '#1B5E20 or #1B5E20FF to include transparency.',
                warning: true,
              ),
          ],
        ),
        const SizedBox(height: 16),
        ToolSection(
          title: 'Readability (WCAG 2.1 contrast)',
          icon: Icons.visibility_outlined,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _secondary,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Text colour (hex)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _Swatch(colour: secondary),
              ],
            ),
            if (ratio != null) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Sample text at 16 pt — the quick brown fox',
                  style: TextStyle(color: secondary, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Contrast ratio: ${ratio.toStringAsFixed(2)} : 1',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _ContrastResult(
                label: 'Normal text (AA) — needs 4.5',
                pass: ratio >= 4.5,
              ),
              _ContrastResult(
                label: 'Large text (AA) — needs 3.0',
                pass: ratio >= 3.0,
              ),
              _ContrastResult(
                label: 'Normal text (AAA) — needs 7.0',
                pass: ratio >= 7.0,
              ),
              const ToolNote(
                'Ratio is (lighter + 0.05) ÷ (darker + 0.05) using WCAG '
                'relative luminance. Large text means 18 pt, or 14 pt bold.',
              ),
            ] else
              const ToolNote(
                'Enter a second valid colour to measure contrast.',
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (primary != null)
          ToolSection(
            title: 'Palette from your colour',
            icon: Icons.gradient_outlined,
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final colour in _harmony(primary))
                    _PaletteChip(colour: colour),
                ],
              ),
              const ToolNote(
                'The first four are tints and shades of the same hue. The rest '
                'are the complement, the two triadic hues and the two '
                'neighbouring hues.',
              ),
            ],
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colour});

  final Color? colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colour ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: colour == null
          ? const Icon(Icons.close, size: 18)
          : null,
    );
  }
}

class _NotationRow extends StatelessWidget {
  const _NotationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_outlined, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContrastResult extends StatelessWidget {
  const _ContrastResult({required this.label, required this.pass});

  final String label;
  final bool pass;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(
            pass ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18,
            color: pass ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            pass ? 'Pass' : 'Fail',
            style: TextStyle(
              color: pass ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    final hex = _ColourToolkitToolState._hex(colour);
    final onColour =
        _ColourToolkitToolState._luminance(colour) > 0.5
            ? Colors.black
            : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Clipboard.setData(ClipboardData(text: hex));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$hex copied.'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        width: 104,
        height: 66,
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          hex,
          style: TextStyle(
            color: onColour,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
