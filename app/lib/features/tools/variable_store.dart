/// Typed variables that flow between tools.
///
/// The point is chaining: run a tool, keep its result under a name, and refer
/// to that name in the next tool's arguments. `$out/todo.csv` interpolates,
/// `$count` is substituted as a number, and `${name}` works when a name is
/// followed by text that is not an identifier character.
///
/// Variables are persisted so a session survives a restart, and every value
/// keeps its declared type so downstream tools get a number as a number.
library;

import 'dart:convert';
import 'dart:io';

/// The kinds of value a variable can hold.
enum VariableType {
  text('text'),
  number('number'),
  boolean('boolean'),
  list('list'),
  map('map'),
  path('path');

  const VariableType(this.wireName);

  /// Stable name used in storage.
  final String wireName;

  /// Resolve a stored name back to a type, defaulting to [text].
  static VariableType fromWire(String value) {
    for (final type in VariableType.values) {
      if (type.wireName == value) return type;
    }
    return VariableType.text;
  }

  /// Infer the natural type of [value].
  static VariableType infer(Object? value) {
    if (value is bool) return VariableType.boolean;
    if (value is num) return VariableType.number;
    if (value is List) return VariableType.list;
    if (value is Map) return VariableType.map;
    return VariableType.text;
  }

  /// Render [value] as text for interpolation.
  static String render(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    if (value is List) return value.map(render).join(', ');
    return jsonEncode(value);
  }
}

/// One stored variable.
class Variable {
  /// Create a variable.
  const Variable({
    required this.name,
    required this.value,
    required this.type,
    required this.updatedAt,
    this.description = '',
    this.fromTool = '',
  });

  /// Identifier used for interpolation. Case-insensitive.
  final String name;

  /// The stored value.
  final Object? value;

  /// Declared type of [value].
  final VariableType type;

  /// When the value was last written.
  final DateTime updatedAt;

  /// Optional human note about what this holds.
  final String description;

  /// Id of the tool that produced the value, when it came from one.
  final String fromTool;

  /// Whether [name] is a legal variable name.
  static bool isValidName(String name) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name);

  /// Serialise for storage.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'value': value,
        'type': type.wireName,
        'updatedAt': updatedAt.toIso8601String(),
        'description': description,
        'fromTool': fromTool,
      };

  /// Restore from storage, tolerating missing or malformed fields.
  static Variable fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final raw = json['value'];
    return Variable(
      name: name,
      value: raw,
      type: json['type'] == null
          ? VariableType.infer(raw)
          : VariableType.fromWire(json['type'].toString()),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      description: json['description']?.toString() ?? '',
      fromTool: json['fromTool']?.toString() ?? '',
    );
  }

  /// Text form used when interpolating.
  String get rendered => VariableType.render(value);
}

/// Raised when a variable reference cannot be resolved.
class VariableError implements Exception {
  /// Create an error describing [message].
  const VariableError(this.message);

  /// What went wrong, phrased for the user.
  final String message;

  @override
  String toString() => message;
}

/// Stores named variables and interpolates `$name` references in text.
class VariableStore {
  final Map<String, Variable> _variables = <String, Variable>{};
  final File? _file;
  bool _loaded = false;

  /// Create a store.
  ///
  /// When [file] is given, [load] reads it and [save] writes it. In-memory
  /// operation without a file is fully supported, which keeps tests free of
  /// platform channels.
  VariableStore({File? file}) : _file = file;

  /// Read persisted variables. Safe to call repeatedly.
  void load() {
    if (_loaded) return;
    _loaded = true;
    final file = _file;
    if (file == null || !file.existsSync()) return;
    try {
      final decoded = jsonDecode(file.readAsStringSync(encoding:utf8));
      if (decoded is! List) return;
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final variable = Variable.fromJson(entry);
          if (Variable.isValidName(variable.name)) {
            _variables[variable.name.toLowerCase()] = variable;
          }
        }
      }
    } catch (_) {
      // Corrupt store: start empty rather than refuse to run.
      _variables.clear();
    }
  }

  /// Persist variables, if this store has a file.
  void save() {
    final file = _file;
    if (file == null) return;
    try {
      file.parent.createSync(recursive: true);
      final temp = File('${file.path}.tmp');
      temp.writeAsStringSync(
        jsonEncode(_variables.values.map((v) => v.toJson()).toList()),
        encoding: utf8,
      );
      // Atomic replace so a crash cannot truncate the store.
      temp.renameSync(file.path);
    } catch (_) {
      // Persistence is best-effort; in-memory state stays correct.
    }
  }

  /// Store [value] under [name], inferring the type when not given.
  void set(
    String name, {
    Object? value,
    required VariableType type,
    String description = '',
    String fromTool = '',
  }) {
    if (!Variable.isValidName(name)) {
      throw VariableError(
        'Variable name "$name" is not valid. Use letters, digits and '
        'underscores, starting with a letter or underscore.',
      );
    }
    _loaded = true;
    _variables[name.toLowerCase()] = Variable(
      name: name,
      value: value,
      type: type,
      updatedAt: DateTime.now(),
      description: description,
      fromTool: fromTool,
    );
    save();
  }

  /// The variable called [name], or null.
  Variable? get(String name) => _variables[name.toLowerCase()];

  /// Whether a variable called [name] exists.
  bool has(String name) => _variables.containsKey(name.toLowerCase());

  /// Remove [name]. Returns true when something was removed.
  bool remove(String name) {
    final removed = _variables.remove(name.toLowerCase()) != null;
    if (removed) save();
    return removed;
  }

  /// Every variable, newest first.
  List<Variable> all() {
    final list = _variables.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Remove everything.
  void clear() {
    _variables.clear();
    save();
  }

  /// Names of every variable, for autocompletion.
  List<String> names() => _variables.keys.toList()..sort();

  /// Replace `$name` and `${name}` in [input] with stored values.
  ///
  /// Escaping a dollar with a backslash (`\$name`) emits a literal `$name`.
  /// Throws [VariableError] for an unknown name, because silently passing an
  /// empty string into a tool is worse than a clear failure.
  String interpolate(String input) {
    if (!input.contains(r'$')) return input;
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == r'\' && i + 1 < input.length && input[i + 1] == r'$') {
        buffer.write(r'$');
        i++;
        continue;
      }
      if (char != r'$') {
        buffer.write(char);
        continue;
      }
      final braced = i + 1 < input.length && input[i + 1] == '{';
      final name = braced ? _readBracedName(input, i) : _readBareName(input, i);
      if (name == null) {
        buffer.write(char);
        continue;
      }
      final variable = get(name);
      if (variable == null) {
        throw VariableError(
          'Unknown variable "\$$name". Known variables: '
          '${names().join(', ')}',
        );
      }
      buffer.write(variable.rendered);
      i = braced ? input.indexOf('}', i) : i + name.length;
    }
    return buffer.toString();
  }

  /// Interpolate every string in an argument map.
  ///
  /// Whole-value references keep their type: if the entire argument is
  /// `$count`, the number itself is passed, not its text form.
  Map<String, dynamic> interpolateArgs(Map<String, dynamic> args) {
    final result = <String, dynamic>{};
    for (final entry in args.entries) {
      final value = entry.value;
      if (value is! String) {
        result[entry.key] = value;
        continue;
      }
      final whole = _wholeVariableReference(value);
      if (whole != null) {
        final variable = get(whole);
        if (variable == null) {
          throw VariableError(
            'Unknown variable "\$$whole". Known variables: '
            '${names().join(', ')}',
          );
        }
        result[entry.key] = variable.value;
        continue;
      }
      result[entry.key] = interpolate(value);
    }
    return result;
  }

  /// Return the variable name when [value] is exactly `$name` or `${name}`.
  static String? _wholeVariableReference(String value) {
    final bare = RegExp(r'^\$([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(value);
    if (bare != null) return bare.group(1);
    final braced = RegExp(r'^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$').firstMatch(value);
    if (braced != null) return braced.group(1);
    return null;
  }

  /// Read a `${name}` reference starting at [start]; returns the name.
  static String? _readBracedName(String input, int start) {
    final end = input.indexOf('}', start);
    if (end < 0) return null;
    final name = input.substring(start + 2, end);
    return RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name) ? name : null;
  }

  /// Read a `$name` reference starting at [start]; returns the name.
  static String? _readBareName(String input, int start) {
    final match =
        RegExp(r'^[A-Za-z_][A-Za-z0-9_]*').firstMatch(input.substring(start + 1));
    return match?.group(0);
  }
}
