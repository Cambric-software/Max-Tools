import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Converts between Unix timestamps and human-readable dates.
///
/// Paste an epoch value to see it in local and UTC time, or pick a date to
/// get its epoch value. Handles seconds and milliseconds.
class TimestampConverterTool extends StatefulWidget {
  const TimestampConverterTool({super.key});

  @override
  State<TimestampConverterTool> createState() => _TimestampConverterToolState();
}

class _TimestampConverterToolState extends State<TimestampConverterTool> {
  final TextEditingController _epoch = TextEditingController();
  final TextEditingController _date = TextEditingController();
  String? _error;
  DateTime? _parsed;
  bool _asMillis = false;

  @override
  void dispose() {
    _epoch.dispose();
    _date.dispose();
    super.dispose();
  }

  void _fromEpoch() {
    final raw = _epoch.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _parsed = null;
        _error = null;
      });
      return;
    }
    final n = int.tryParse(raw);
    if (n == null) {
      setState(() {
        _error = 'Not a number.';
        _parsed = null;
      });
      return;
    }
    final ms = _asMillis ? n : n * 1000;
    setState(() {
      _error = null;
      _parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    });
  }

  void _fromDate() {
    final raw = _date.text.trim();
    if (raw.isEmpty) return;
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      setState(() => _error = 'Could not parse date. Use ISO 8601.');
      return;
    }
    final epoch = dt.toUtc().millisecondsSinceEpoch;
    setState(() {
      _error = null;
      _epoch.text = _asMillis ? epoch.toString() : (epoch ~/ 1000).toString();
      _parsed = dt;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'Timestamp converter',
      howTo: 'Paste an epoch value to read it as a date, or type a date to '
          'get its epoch value. Toggle seconds/milliseconds.',
      children: [
        SwitchListTile(
          title: const Text('Milliseconds'),
          value: _asMillis,
          onChanged: (v) {
            setState(() => _asMillis = v);
            _fromEpoch();
          },
        ),
        TextField(
          controller: _epoch,
          decoration: const InputDecoration(labelText: 'Epoch value'),
          onChanged: (_) => _fromEpoch(),
        ),
        const SizedBox(height: 8),
        if (_parsed != null) ...[
          Text('Local: ${_parsed!.toLocal()}'),
          Text('UTC:   ${_parsed!.toUtc()}'),
          Text('ISO:   ${_parsed!.toUtc().toIso8601String()}'),
        ],
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 16),
        TextField(
          controller: _date,
          decoration: const InputDecoration(
              labelText: 'Date (ISO 8601, e.g. 2026-10-29T12:00:00)'),
          onChanged: (_) => _fromDate(),
        ),
        const SizedBox(height: 8),
        Text('Type a date above to fill the epoch field.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}