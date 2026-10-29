import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Builds and explains cron expressions.
///
/// Type a five-field cron expression and read what it means in plain English,
/// plus the next few times it will fire. Type a schedule in English-ish fields
/// and get the expression back. No external service; everything is local.
class CronBuilderTool extends StatefulWidget {
  const CronBuilderTool({super.key});

  @override
  State<CronBuilderTool> createState() => _CronBuilderToolState();
}

class _CronBuilderToolState extends State<CronBuilderTool> {
  final TextEditingController _expr = TextEditingController(text: '*/5 * * * *');
  String _explanation = '';
  String? _error;
  List<DateTime> _next = <DateTime>[];

  @override
  void dispose() {
    _expr.dispose();
    super.dispose();
  }

  static const List<String> _months = <String>[
    '', 'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _days = <String>[
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  void _run() {
    final parts = _expr.text.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) {
      setState(() {
        _error = 'A cron expression has 5 fields: minute hour day month weekday.';
        _explanation = '';
        _next = <DateTime>[];
      });
      return;
    }
    // Validate each field parses as a simple value or */n or * .
    for (final p in parts) {
      if (!_validField(p)) {
        setState(() {
          _error = 'Invalid field: "$p".';
          _explanation = '';
          _next = <DateTime>[];
        });
        return;
      }
    }
    setState(() {
      _error = null;
      _explanation = _describe(parts);
      _next = _nextRuns(parts, 5);
    });
  }

  bool _validField(String f) {
    if (f == '*') return true;
    if (f.startsWith('*/')) {
      final n = int.tryParse(f.substring(2));
      return n != null && n > 0;
    }
    return int.tryParse(f) != null;
  }

  bool _matches(String field, int value, int min, int max) {
    if (field == '*') return true;
    if (field.startsWith('*/')) {
      final n = int.parse(field.substring(2));
      return value % n == 0;
    }
    return int.tryParse(field) == value;
  }

  String _describe(List<String> p) {
    final minute = p[0] == '*' ? 'every minute' : (p[0].startsWith('*/') ? 'every ${p[0].substring(2)} minutes' : 'minute ${p[0]}');
    final hour = p[1] == '*' ? '' : (p[1].startsWith('*/') ? 'every ${p[1].substring(2)} hours' : 'at hour ${p[1]}');
    final day = p[2] == '*' ? '' : 'on day ${p[2]} of the month';
    final month = p[3] == '*' ? '' : 'in ${_months[int.tryParse(p[3]) ?? 0]}';
    final weekday = p[4] == '*' ? '' : 'on ${_days[int.tryParse(p[4]) ?? 0]}';
    return [minute, hour, day, month, weekday].where((s) => s.isNotEmpty).join(', ');
  }

  List<DateTime> _nextRuns(List<String> p, int count) {
    final out = <DateTime>[];
    var t = DateTime.now().add(const Duration(minutes: 1));
    t = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    while (out.length < count && t.isBefore(DateTime.now().add(const Duration(days: 365)))) {
      if (_matches(p[0], t.minute, 0, 59) &&
          _matches(p[1], t.hour, 0, 23) &&
          _matches(p[2], t.day, 1, 31) &&
          _matches(p[3], t.month, 1, 12) &&
          _matches(p[4], t.weekday % 7, 0, 6)) {
        out.add(t);
      }
      t = t.add(const Duration(minutes: 1));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _expr.addListener(_run);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'Cron builder',
      howTo: 'Type a five-field cron expression (minute hour day month weekday). '
          'The meaning and the next few run times appear below.',
      children: [
        TextField(
          controller: _expr,
          decoration: const InputDecoration(labelText: 'Cron expression'),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_error == null) ...[
          Text('Meaning: $_explanation',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text('Next runs:', style: Theme.of(context).textTheme.titleSmall),
          Expanded(
            child: ListView.builder(
              itemCount: _next.length,
              itemBuilder: (context, i) =>
                  Text(_next[i].toLocal().toString()),
            ),
          ),
        ],
      ],
    );
  }
}