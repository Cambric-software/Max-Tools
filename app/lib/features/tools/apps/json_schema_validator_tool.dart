import 'dart:convert';

import 'package:flutter/material.dart';

import 'tool_shell.dart';

/// Validates a JSON document against a JSON Schema (subset).
///
/// Supports type, required, min/max, minLength/maxLength, pattern, enum and
/// additionalProperties. Reports every violation with its path.
class JsonSchemaValidatorTool extends StatefulWidget {
  const JsonSchemaValidatorTool({super.key});

  @override
  State<JsonSchemaValidatorTool> createState() => _JsonSchemaValidatorToolState();
}

class _JsonSchemaValidatorToolState extends State<JsonSchemaValidatorTool> {
  final TextEditingController _schema = TextEditingController(text:
      '{\n  "type": "object",\n  "required": ["name"],\n  "properties": {\n    "name": {"type": "string", "minLength": 1},\n    "age": {"type": "integer", "minimum": 0}\n  }\n}');
  final TextEditingController _data = TextEditingController(text:
      '{\n  "name": "Ada",\n  "age": 30\n}');
  String _result = '';

  @override
  void dispose() {
    _schema.dispose();
    _data.dispose();
    super.dispose();
  }

  void _run() {
    try {
      final schema = jsonDecode(_schema.text);
      final data = jsonDecode(_data.text);
      final errors = <String>[];
      _validate(schema, data, '', errors);
      setState(() {
        _result = errors.isEmpty
            ? 'Valid.'
            : 'Invalid:\n${errors.map((e) => ' - $e').join('\n')}';
      });
    } catch (e) {
      setState(() => _result = 'Parse error: $e');
    }
  }

  void _validate(dynamic schema, dynamic data, String path, List<String> errors) {
    if (schema is! Map<String, dynamic>) return;
    // type
    final type = schema['type'];
    if (type != null && !_checkType(type, data)) {
      errors.add('$path: expected $type, got ${_typeName(data)}');
    }
    // enum
    final en = schema['enum'];
    if (en is List && !en.contains(data)) {
      errors.add('$path: value not in enum $en');
    }
    // string constraints
    if (data is String) {
      final minL = schema['minLength'];
      if (minL is int && data.length < minL) {
        errors.add('$path: length ${data.length} < minLength $minL');
      }
      final maxL = schema['maxLength'];
      if (maxL is int && data.length > maxL) {
        errors.add('$path: length ${data.length} > maxLength $maxL');
      }
      final pat = schema['pattern'];
      if (pat is String) {
        final re = RegExp(pat);
        if (!re.hasMatch(data)) errors.add('$path: does not match pattern $pat');
      }
    }
    // number constraints
    if (data is num) {
      final min = schema['minimum'];
      if (min is num && data < min) errors.add('$path: $data < minimum $min');
      final max = schema['maximum'];
      if (max is num && data > max) errors.add('$path: $data > maximum $max');
    }
    // object
    if (data is Map<String, dynamic>) {
      final required = schema['required'];
      if (required is List) {
        for (final r in required) {
          if (r is String && !data.containsKey(r)) {
            errors.add('$path: missing required property "$r"');
          }
        }
      }
      final props = schema['properties'];
      if (props is Map<String, dynamic>) {
        for (final entry in props.entries) {
          if (data.containsKey(entry.key)) {
            _validate(entry.value, data[entry.key], '$path/${entry.key}', errors);
          }
        }
      }
      final addl = schema['additionalProperties'];
      if (addl == false) {
        for (final k in data.keys) {
          if (props is Map && !props.containsKey(k)) {
            errors.add('$path: unexpected property "$k"');
          }
        }
      }
    }
    // array
    if (data is List) {
      final items = schema['items'];
      if (items is Map<String, dynamic>) {
        for (var i = 0; i < data.length; i++) {
          _validate(items, data[i], '$path[$i]', errors);
        }
      }
      final minI = schema['minItems'];
      if (minI is int && data.length < minI) {
        errors.add('$path: ${data.length} items < minItems $minI');
      }
      final maxI = schema['maxItems'];
      if (maxI is int && data.length > maxI) {
        errors.add('$path: ${data.length} items > maxItems $maxI');
      }
    }
  }

  bool _checkType(dynamic type, dynamic data) {
    switch (type) {
      case 'null':
        return data == null;
      case 'boolean':
        return data is bool;
      case 'integer':
        return data is int;
      case 'number':
        return data is num;
      case 'string':
        return data is String;
      case 'array':
        return data is List;
      case 'object':
        return data is Map;
    }
    return true;
  }

  String _typeName(dynamic data) {
    if (data == null) return 'null';
    if (data is bool) return 'boolean';
    if (data is int) return 'integer';
    if (data is num) return 'number';
    if (data is String) return 'string';
    if (data is List) return 'array';
    if (data is Map) return 'object';
    return data.runtimeType.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'JSON Schema validator',
      howTo: 'Paste a JSON Schema on the left and a JSON document on the right. '
          'Every violation is reported with its path.',
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _schema,
                  decoration: const InputDecoration(labelText: 'Schema'),
                  maxLines: null,
                  expands: true,
                  onChanged: (_) => _run(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _data,
                  decoration: const InputDecoration(labelText: 'Data'),
                  maxLines: null,
                  expands: true,
                  onChanged: (_) => _run(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: SelectableText(_result,
                style: const TextStyle(fontFamily: 'monospace')),
          ),
        ),
      ],
    );
  }
}