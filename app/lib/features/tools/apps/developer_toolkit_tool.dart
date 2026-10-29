import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'tool_shell.dart';

enum _DevTask {
  base64Encode('Base64 — encode'),
  base64Decode('Base64 — decode'),
  urlEncode('URL — encode'),
  urlDecode('URL — decode'),
  jsonPretty('JSON — format'),
  jsonMinify('JSON — minify'),
  htmlEscape('HTML — escape'),
  htmlUnescape('HTML — unescape'),
  uuid('UUID — generate'),
  timestamp('Timestamp — convert'),
  regex('Regex — test'),
  csvToJson('CSV — to JSON'),
  jsonToCsv('JSON ? to CSV'),
  sqlFormat('SQL ? format'),
  cidr('CIDR ? subnet info');

  const _DevTask(this.label);
  final String label;
}

/// The converter bench a developer reaches for several times a day.
///
/// Each task states what it does to the text, and failures (malformed JSON, bad
/// Base64, an invalid pattern) are reported as errors rather than silently
/// producing something wrong.
class DeveloperToolkitTool extends StatefulWidget {
  /// Create the tool.
  const DeveloperToolkitTool({super.key});

  @override
  State<DeveloperToolkitTool> createState() => _DeveloperToolkitToolState();
}

class _DeveloperToolkitToolState extends State<DeveloperToolkitTool> {
  _DevTask _task = _DevTask.base64Encode;
  final TextEditingController _input = TextEditingController();
  final TextEditingController _second = TextEditingController();
  String _output = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _input.dispose();
    _second.dispose();
    super.dispose();
  }

  void _run() {
    final text = _input.text;
    try {
      final result = switch (_task) {
        _DevTask.base64Encode => base64.encode(utf8.encode(text)),
        _DevTask.base64Decode => utf8.decode(base64.decode(text.trim())),
        _DevTask.urlEncode => Uri.encodeComponent(text),
        _DevTask.urlDecode => Uri.decodeComponent(text.trim()),
        _DevTask.jsonPretty => const JsonEncoder.withIndent('  ')
            .convert(jsonDecode(text)),
        _DevTask.jsonMinify => jsonEncode(jsonDecode(text)),
        _DevTask.htmlEscape => _escapeHtml(text),
        _DevTask.htmlUnescape => _unescapeHtml(text),
        _DevTask.uuid => _uuid(),
        _DevTask.timestamp => _timestamp(text.trim()),
        _DevTask.regex => _regex(text, _second.text),
        _DevTask.csvToJson => _csvToJson(text),
        _DevTask.jsonToCsv => _jsonToCsv(text),
        _DevTask.sqlFormat => _sqlFormat(text),
        _DevTask.cidr => _cidr(text),
      };
      setState(() {
        _output = result;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _output = '';
        _error = '$error';
      });
    }
  }

  // ── conversions ──────────────────────────────────────────────────────────

  static String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  static String _unescapeHtml(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');

  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static String _timestamp(String text) {
    if (text.isEmpty) {
      final now = DateTime.now();
      return 'Now\n'
          '  local: ${now.toIso8601String()}\n'
          '  UTC:   ${now.toUtc().toIso8601String()}\n'
          '  epoch: ${now.millisecondsSinceEpoch ~/ 1000} seconds\n'
          '         ${now.millisecondsSinceEpoch} milliseconds';
    }

    final number = int.tryParse(text);
    if (number != null) {
      // Ten digits is seconds; thirteen is milliseconds. Anything else is
      // reported rather than guessed at.
      final DateTime moment;
      if (text.length <= 10) {
        moment = DateTime.fromMillisecondsSinceEpoch(number * 1000);
      } else if (text.length <= 13) {
        moment = DateTime.fromMillisecondsSinceEpoch(number);
      } else {
        throw const FormatException(
          'An epoch is 10 digits (seconds) or 13 (milliseconds).',
        );
      }
      return '${moment.toUtc().toIso8601String()}  (UTC)\n'
          '${moment.toIso8601String()}  (local)';
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      throw const FormatException(
        'Enter an epoch number or a date such as 2026-10-19T14:30:00Z.',
      );
    }
    return '${parsed.millisecondsSinceEpoch ~/ 1000} seconds\n'
        '${parsed.millisecondsSinceEpoch} milliseconds';
  }

  static String _regex(String pattern, String text) {
    if (pattern.isEmpty) {
      throw const FormatException('Enter a pattern in the second box.');
    }
    final expression = RegExp(pattern);
    final matches = expression.allMatches(text).toList();
    if (matches.isEmpty) return 'No matches.';
    final buffer = StringBuffer('${matches.length} match');
    buffer.writeln(matches.length == 1 ? '' : 'es');
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      buffer.writeln('\n${i + 1}. "${match.group(0)}" at ${match.start}');
      for (var g = 1; g <= match.groupCount; g++) {
        if (match.group(g) != null) {
          buffer.writeln('   group $g: ${match.group(g)}');
        }
      }
    }
    return buffer.toString().trimRight();
  }

  static String _csvToJson(String text) {
    final rows = _parseCsv(text);
    if (rows.isEmpty) return '[]';
    final header = rows.first;
    final records = <Map<String, String>>[];
    for (final row in rows.skip(1)) {
      if (row.every((String cell) => cell.trim().isEmpty)) continue;
      records.add(<String, String>{
        for (var i = 0; i < header.length; i++)
          header[i]: i < row.length ? row[i] : '',
      });
    }
    return const JsonEncoder.withIndent('  ').convert(records);
  }

  static String _jsonToCsv(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! List || decoded.isEmpty) {
      throw const FormatException('A CSV needs a non-empty JSON array.');
    }
    if (decoded.first is! Map) {
      throw const FormatException(
        'Each item must be an object, for example [{"name":"A","size":1}].',
      );
    }
    final columns = <String>{};
    for (final item in decoded) {
      if (item is Map) {
        columns.addAll(item.keys.map((Object? key) => '$key'));
      }
    }
    final ordered = columns.toList();
    final buffer = StringBuffer()
      ..writeln(ordered.map(_csvCell).join(','));
    for (final item in decoded) {
      if (item is! Map) continue;
      buffer.writeln(
        ordered
            .map((String column) => _csvCell('${item[column] ?? ''}'))
            .join(','),
      );
    }
    return buffer.toString().trimRight();
  }
  static String _sqlFormat(String text) {
    const keywords = <String>{
      'select', 'from', 'where', 'and', 'or', 'insert', 'into', 'values',
      'update', 'set', 'delete', 'create', 'table', 'alter', 'drop', 'join',
      'left', 'right', 'inner', 'outer', 'on', 'group', 'by', 'order', 'having',
      'limit', 'offset', 'as', 'distinct', 'union', 'all',
    };
    final tokens = text.split(RegExp(r'\s+'));
    final out = StringBuffer();
    for (final t in tokens) {
      if (t.isEmpty) continue;
      final lower = t.toLowerCase();
      if (keywords.contains(lower)) {
        out.write('${lower.toUpperCase()} ');
      } else {
        out.write('$t ');
      }
    }
    return out.toString().trim();
  }

  static String _cidr(String text) {
    final input = text.trim();
    if (input.isEmpty) throw const FormatException('Enter a CIDR like 192.168.1.0/24.');
    final parts = input.split('/');
    if (parts.length != 2) throw const FormatException('Expected address/prefix, e.g. 10.0.0.0/8.');
    final ip = parts[0];
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32) {
      throw const FormatException('Prefix must be 0..32.');
    }
    final octets = ip.split('.');
    if (octets.length != 4) throw const FormatException('Invalid IPv4 address.');
    var ipInt = 0;
    for (final o in octets) {
      final v = int.tryParse(o);
      if (v == null || v < 0 || v > 255) throw const FormatException('Invalid octet.');
      ipInt = (ipInt << 8) | v;
    }
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    final network = ipInt & mask;
    final broadcast = network | (~mask & 0xFFFFFFFF);
    final hosts = prefix >= 31 ? 0 : (1 << (32 - prefix)) - 2;
    String toIp(int v) =>
        '${(v >> 24) & 0xff}.${(v >> 16) & 0xff}.${(v >> 8) & 0xff}.${v & 0xff}';
    return 'Network:   ${toIp(network)}\n'
        'Broadcast: ${toIp(broadcast)}\n'
        'Mask:      ${toIp(mask)}\n'
        'Prefix:    /$prefix\n'
        'Hosts:     $hosts\n'
        'Range:     ${toIp(network + 1)} - ${toIp(broadcast - 1)}';
  }


  static String _csvCell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// A small RFC 4180 reader: quoted fields, doubled quotes, embedded commas
  /// and newlines.
  static List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(char);
        }
        continue;
      }

      switch (char) {
        case '"':
          quoted = true;
        case ',':
          row.add(field.toString());
          field.clear();
        case '\n':
          row.add(field.toString());
          field.clear();
          rows.add(row);
          row = <String>[];
        case '\r':
          break;
        default:
          field.write(char);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  // ── ui ───────────────────────────────────────────────────────────────────

  String get _firstLabel => switch (_task) {
        _DevTask.regex => 'Text to search',
        _DevTask.jsonToCsv => 'JSON array',
        _DevTask.csvToJson => 'CSV text',
        _DevTask.timestamp => 'Epoch or date (empty for now)',
        _DevTask.uuid => 'Ignored - press Generate',
        _DevTask.sqlFormat => 'SQL to format',
        _DevTask.cidr => 'CIDR (e.g. 10.0.0.0/8)',
        _ => 'Input',
      };

  String get _secondLabel => switch (_task) {
        _DevTask.regex => 'Pattern',
        _DevTask.jsonToCsv => 'Not used',
        _DevTask.csvToJson => 'Not used',
        _ => '',
      };

  String get _explanation => switch (_task) {
        _DevTask.base64Encode =>
          'Base64 turns any text or binary into plain letters and digits. It '
              'is not encryption and provides no secrecy.',
        _DevTask.base64Decode =>
          'Decodes Base64 back to text. Malformed input is reported rather '
              'than half-decoded.',
        _DevTask.urlEncode =>
          'Percent-encodes every character that is unsafe in a URL component.',
        _DevTask.urlDecode => 'Reverses percent-encoding.',
        _DevTask.jsonPretty =>
          'Parses the JSON and reprints it with two-space indentation. Invalid '
              'JSON produces the parser error and the position it failed at.',
        _DevTask.jsonMinify =>
          'Parses the JSON and removes all insignificant whitespace. The data '
              'is unchanged.',
        _DevTask.htmlEscape =>
          'Replaces &, <, >, " and \' with HTML entities so text displays '
              'literally instead of being interpreted as markup.',
        _DevTask.htmlUnescape => 'Reverses the five common HTML entities.',
        _DevTask.uuid =>
          'Generates a random version 4 UUID using the platform\'s secure '
              'random source.',
        _DevTask.timestamp =>
          'Converts between epoch seconds or milliseconds and an ISO date. '
              'Ten digits is treated as seconds, thirteen as milliseconds.',
        _DevTask.regex =>
          'Runs the pattern against the text and lists every match with its '
              'position and capture groups.',
        _DevTask.csvToJson =>
          'Reads RFC 4180 CSV, using the first row as column names, and prints '
              'a JSON array of objects.',
        _DevTask.jsonToCsv =>
          'Reads a JSON array of objects and writes CSV, quoting any value '
              'that contains a comma, quote or newline.',
        _DevTask.sqlFormat =>
          'Upper-cases SQL keywords and separates tokens with single spaces. '
              'A quick tidy, not a full formatter.',
        _DevTask.cidr =>
          'Computes the network, broadcast, mask and host count for a CIDR block.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolShell(
      title: 'Developer toolkit',
      howTo: 'Pick a task, paste your text, and read the result. Everything '
          'happens on this machine — nothing is sent to a server. Errors are '
          'shown as errors, so a malformed document never looks converted.',
      maxWidth: 900,
      children: <Widget>[
        ToolSection(
          title: 'What to do',
          icon: Icons.build_outlined,
          children: <Widget>[
            DropdownButtonFormField<_DevTask>(
              initialValue: _task,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Task',
              ),
              items: <DropdownMenuItem<_DevTask>>[
                for (final task in _DevTask.values)
                  DropdownMenuItem<_DevTask>(
                    value: task,
                    child: Text(task.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (_DevTask? value) {
                if (value == null) return;
                setState(() {
                  _task = value;
                  _second.clear();
                });
                _run();
              },
            ),
            const SizedBox(height: 10),
            Text(
              _explanation,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ToolSection(
          title: 'Input',
          icon: Icons.input,
          children: <Widget>[
            TextField(
              controller: _input,
              minLines: 5,
              maxLines: 14,
              onChanged: (_) => _run(),
              decoration: InputDecoration(
                labelText: _firstLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_secondLabel.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: _second,
                onChanged: (_) => _run(),
                decoration: InputDecoration(
                  labelText: _secondLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _task == _DevTask.uuid
                      ? () => setState(() {
                            _input.text = _uuid();
                            _run();
                          })
                      : _run,
                  icon: Icon(
                    _task == _DevTask.uuid
                        ? Icons.casino_outlined
                        : Icons.play_arrow_outlined,
                  ),
                  label: Text(
                    _task == _DevTask.uuid ? 'Generate' : 'Convert',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ToolSection(
          title: 'Result',
          icon: Icons.output,
          children: <Widget>[
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              )
            else
              ToolOutput(text: _output, minHeight: 120),
          ],
        ),
      ],
    );
  }
}
