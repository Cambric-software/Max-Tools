import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Accessibility and reading aid.
///
/// Two jobs in one screen:
///
/// 1. Measure how hard a piece of text is to read, using the Flesch formulas
///    that are standard in plain-language work. The formulas are estimates,
///    not measurements, and the tool says so.
/// 2. Let the reader reshape the page — size, line spacing, letter spacing and
///    line length — and see the effect immediately. The settings are what the
///    person copies into their browser, e-reader or operating system.
class ReadingAidTool extends StatefulWidget {
  /// Create the tool.
  const ReadingAidTool({super.key});

  @override
  State<ReadingAidTool> createState() => _ReadingAidToolState();
}

class _ReadingAidToolState extends State<ReadingAidTool> {
  static const String _sample =
      'A good page is not a page that looks clever. It is a page that a tired '
      'person can finish. Short sentences help. So does space between the '
      'lines, and a line short enough that the eye can find the next one '
      'without hunting.';

  final TextEditingController _text = TextEditingController();

  double _size = 18;
  double _lineHeight = 1.6;
  double _letterSpacing = 0;
  double _lineLength = 62;
  bool _leftAligned = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _previewText {
    final typed = _text.text.trim();
    return typed.isEmpty ? _sample : typed;
  }

  _Readability? get _readability => _Readability.measure(_text.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readability = _readability;

    return ToolShell(
      title: 'Accessibility & reading',
      howTo: 'Paste something you have written to see how hard it is to read, '
          'then adjust the preview until the text is comfortable. The numbers '
          'are guides, not marks out of ten.',
      children: <Widget>[
        ToolSection(
          title: 'How readable is this text?',
          icon: Icons.article_outlined,
          children: <Widget>[
            TextField(
              controller: _text,
              minLines: 4,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Your text',
                hintText: 'Paste an email, a letter, a page or a caption.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () {
                      _text.text = _sample;
                      setState(() {});
                    },
                    icon: const Icon(Icons.text_snippet_outlined, size: 18),
                    label: const Text('Use a sample'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _text.text.isEmpty
                        ? null
                        : () {
                            _text.clear();
                            setState(() {});
                          },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            if (readability == null)
              const ToolNote(
                'Nothing to measure yet. Paste text above, or use the sample '
                'to see what the result looks like.',
              )
            else ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _Metric(
                    label: 'Reading ease',
                    value: readability.ease.toStringAsFixed(0),
                    hint: readability.easeBand,
                  ),
                  _Metric(
                    label: 'Grade level',
                    value: readability.gradeLabel,
                    hint: 'US school years',
                  ),
                  _Metric(
                    label: 'Words / sentence',
                    value: readability.wordsPerSentence.toStringAsFixed(1),
                    hint: 'Shorter is usually easier',
                  ),
                  _Metric(
                    label: 'Reading time',
                    value: readability.readingTime,
                    hint: 'At 200 words a minute',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Verdict(readability: readability),
              const ToolNote(
                'Reading ease and grade are the Flesch formulas. They count '
                'syllables with an English spelling rule, so they are an '
                'estimate and only meaningful for English text. Word, '
                'sentence and time counts work for any language.',
              ),
            ],
          ],
        ),
        ToolSection(
          title: 'Preview with your settings',
          icon: Icons.format_size,
          children: <Widget>[
            _SliderRow(
              label: 'Text size',
              value: '${_size.toStringAsFixed(0)} pt',
              sliderValue: _size,
              min: 12,
              max: 32,
              divisions: 20,
              onChanged: (double value) => setState(() => _size = value),
            ),
            _SliderRow(
              label: 'Line spacing',
              value: '${_lineHeight.toStringAsFixed(1)}×',
              sliderValue: _lineHeight,
              min: 1,
              max: 2.2,
              divisions: 12,
              onChanged: (double value) => setState(() => _lineHeight = value),
            ),
            _SliderRow(
              label: 'Letter spacing',
              value: '${_letterSpacing.toStringAsFixed(1)} pt',
              sliderValue: _letterSpacing,
              min: 0,
              max: 3,
              divisions: 12,
              onChanged: (double value) =>
                  setState(() => _letterSpacing = value),
            ),
            _SliderRow(
              label: 'Line length',
              value: '${_lineLength.toStringAsFixed(0)} characters',
              sliderValue: _lineLength,
              min: 30,
              max: 100,
              divisions: 14,
              onChanged: (double value) => setState(() => _lineLength = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Left-align the text'),
              subtitle: const Text(
                'Ragged right edges are easier to follow than justified text '
                'for many readers.',
              ),
              value: _leftAligned,
              onChanged: (bool value) => setState(() => _leftAligned = value),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _lineLength * _size * 0.52,
                  ),
                  child: Text(
                    _previewText,
                    textAlign:
                        _leftAligned ? TextAlign.left : TextAlign.justify,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: _size,
                      height: _lineHeight,
                      letterSpacing: _letterSpacing,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _size = 18;
                  _lineHeight = 1.6;
                  _letterSpacing = 0;
                  _lineLength = 62;
                  _leftAligned = false;
                }),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset the preview'),
              ),
            ),
            const ToolNote(
              'These are preview settings, not a change to other apps. Copy the '
              'values into your browser, e-reader or system accessibility '
              'settings.',
            ),
          ],
        ),
        const ToolSection(
          title: 'What the numbers mean',
          icon: Icons.school_outlined,
          children: <Widget>[
            _Explainer(
              term: 'Reading ease',
              text: 'A score from 0 to 100. Higher is easier. Around 60 is '
                  'plain English; below 30 is hard work for most readers.',
            ),
            _Explainer(
              term: 'Grade level',
              text: 'The US school year the text roughly matches. Grade 8 '
                  'means a 13–14 year old can follow it. It is a readability '
                  'formula, not a judgement of the reader.',
            ),
            _Explainer(
              term: 'Words per sentence',
              text: 'The strongest single lever. Splitting a 30-word sentence '
                  'into two 15-word sentences usually raises the score more '
                  'than changing any word.',
            ),
            ToolNote(
              'Short words are not always clearer, and a long word that the '
              'reader already knows is fine. Use the score to find sentences '
              'to split, not to simplify away meaning.',
            ),
          ],
        ),
      ],
    );
  }
}

class _Readability {
  const _Readability({
    required this.words,
    required this.sentences,
    required this.syllables,
    required this.characters,
    required this.englishShare,
  });

  final int words;
  final int sentences;
  final int syllables;
  final int characters;
  final double englishShare;

  static _Readability? measure(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final tokens = text
        .split(RegExp(r'\s+'))
        .map((String token) => token.replaceAll(
              RegExp(
                r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
                unicode: true,
              ),
              '',
            ))
        .where((String token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

    final letter = RegExp(r'\p{L}', unicode: true);
    final latin = RegExp(r'[A-Za-z]');
    var latinLetters = 0;
    var allLetters = 0;
    var syllables = 0;
    for (final token in tokens) {
      for (final rune in token.runes) {
        final character = String.fromCharCode(rune);
        if (letter.hasMatch(character)) {
          allLetters++;
          if (latin.hasMatch(character)) latinLetters++;
        }
      }
      syllables += _syllables(token);
    }

    final ends = RegExp(r'[.!?]+').allMatches(text).length;
    final sentences = ends == 0 ? 1 : ends;
    final englishShare = allLetters == 0 ? 0.0 : latinLetters / allLetters;

    return _Readability(
      words: tokens.length,
      sentences: sentences,
      syllables: math.max(syllables, tokens.length),
      characters: text.runes.length,
      englishShare: englishShare,
    );
  }

  /// The usual English syllable estimate: vowel groups, minus a silent final
  /// e, with y treated as a vowel. Good enough for a readability score, and
  /// explicitly not a dictionary lookup.
  static int _syllables(String word) {
    var cleaned = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleaned.isEmpty) return 0;
    if (cleaned.length <= 3) return 1;
    cleaned = cleaned
        .replaceAll(RegExp(r'(?:[^laeiouy]es|ed|[^laeiouy]e)$'), '')
        .replaceAll(RegExp(r'^y'), '');
    final groups = RegExp(r'[aeiouy]{1,2}').allMatches(cleaned).length;
    return groups == 0 ? 1 : groups;
  }

  bool get hasEnglish => englishShare >= 0.6;

  double get wordsPerSentence => words / sentences;

  double get syllablesPerWord => syllables / words;

  double get ease {
    final value = 206.835 - 1.015 * wordsPerSentence - 84.6 * syllablesPerWord;
    return value.clamp(0, 100).toDouble();
  }

  double get grade {
    final value = 0.39 * wordsPerSentence + 11.8 * syllablesPerWord - 15.59;
    return value.clamp(0, 20).toDouble();
  }

  String get gradeLabel {
    if (!hasEnglish) return '--';
    if (grade < 1) return '1 or below';
    return grade.toStringAsFixed(0);
  }

  String get easeBand {
    if (!hasEnglish) return 'English only';
    if (ease >= 90) return 'Very easy';
    if (ease >= 80) return 'Easy';
    if (ease >= 70) return 'Fairly easy';
    if (ease >= 60) return 'Plain English';
    if (ease >= 50) return 'Fairly hard';
    if (ease >= 30) return 'Hard';
    return 'Very hard';
  }

  String get readingTime {
    final minutes = words / 200;
    if (minutes < 1) return '${math.max(1, (minutes * 60).round())} sec';
    if (minutes < 60) return '${minutes.toStringAsFixed(1)} min';
    return '${(minutes / 60).toStringAsFixed(1)} hr';
  }

  String verdict() {
    if (!hasEnglish) {
      return 'This text is mostly not in Latin script, so the reading-ease '
          'formula does not apply. The word, sentence and time counts still '
          'do.';
    }
    if (ease >= 70) {
      return 'Most adults will read this without effort.';
    }
    if (ease >= 50) {
      return 'Readable, but some sentences will need a second pass. Split the '
          'longest ones first.';
    }
    return 'This is hard work for a general reader. Shorter sentences and '
        'fewer long words will help more than anything else.';
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.readability});

  final _Readability readability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.assistant_outlined, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            readability.verdict(),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.sliderValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String value;
  final double sliderValue;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: sliderValue,
          min: min,
          max: max,
          divisions: divisions,
          label: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer({required this.term, required this.text});

  final String term;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            term,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
