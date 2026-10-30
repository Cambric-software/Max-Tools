/// Registry of callable tools.
///
/// The registry is the single source of truth for "what Max Tools can do".
/// The UI, the command palette and automation all resolve tools through it, so
/// adding a capability means registering one descriptor — never editing a
/// screen, a switch statement, or a command map.
library;

import 'tool_descriptor.dart';
import '../../core/cache/tool_result_cache.dart';

/// Raised internally when arguments do not satisfy a descriptor.
class ToolArgumentError implements Exception {
  /// Create an argument error with a user-facing [message].
  const ToolArgumentError(this.message);

  /// What is wrong, phrased for the person using the app.
  final String message;

  @override
  String toString() => message;
}

/// Health record for a single tool.
class ToolHealth {
  ToolHealth({this.runs = 0, this.successes = 0, this.failures = 0});

  int runs;
  int successes;
  int failures;
  DateTime? lastUsed;
  String? lastError;

  double get successRate => runs == 0 ? 1.0 : successes / runs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'runs': runs,
        'successes': successes,
        'failures': failures,
        'lastUsed': lastUsed?.toIso8601String(),
        'lastError': lastError,
      };
}

/// Holds tools and runs them safely.
class ToolRegistry {
  ToolRegistry({this.cache});

  final ToolResultCache? cache;

  final Map<String, ToolDescriptor> _tools = <String, ToolDescriptor>{};
  final Map<String, ToolHealth> _health = <String, ToolHealth>{};

  /// Number of registered tools.
  int get length => _tools.length;

  /// Whether a tool with [id] is registered.
  bool contains(String id) => _tools.containsKey(id);

  /// Register [tool], replacing any existing tool with the same id.
  ///
  /// Throws [ToolArgumentError] on a malformed descriptor so a bad tool can
  /// never reach the UI in a half-working state.
  void register(ToolDescriptor tool) {
    if (tool.id.trim().isEmpty) {
      throw const ToolArgumentError('A tool needs a non-empty id.');
    }
    if (tool.name.trim().isEmpty) {
      throw ToolArgumentError('Tool "${tool.id}" needs a name.');
    }
    if (tool.description.trim().isEmpty) {
      throw ToolArgumentError('Tool "${tool.id}" needs a description.');
    }
    final seen = <String>{};
    for (final parameter in tool.parameters) {
      if (!seen.add(parameter.name)) {
        throw ToolArgumentError(
          'Tool "${tool.id}" declares parameter "${parameter.name}" twice.',
        );
      }
    }
    _tools[tool.id] = tool;
  }

  /// Register many tools at once.
  void registerAll(Iterable<ToolDescriptor> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  /// Remove the tool with [id]. Returns true when something was removed.
  bool unregister(String id) => _tools.remove(id) != null;

  /// The tool with [id], or null.
  ToolDescriptor? find(String id) => _tools[id];

  /// Health record for [id], creating one if absent.
  ToolHealth healthOf(String id) =>
      _health.putIfAbsent(id, () => ToolHealth());

  /// All health records, keyed by tool id.
  Map<String, ToolHealth> get allHealth => Map<String, ToolHealth>.unmodifiable(_health);

  /// Last cached result for [id], if any.
  String? lastCachedResult(String id) => cache?.get(id);

  /// Every registered tool, ordered by id for stable output.
  List<ToolDescriptor> all() {
    final tools = _tools.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return tools;
  }

  /// Tools in [category], ordered by id.
  List<ToolDescriptor> byCategory(ToolCategory category) =>
      all().where((tool) => tool.category == category).toList();

  /// How many tools sit in each category, for the UI's category counts.
  Map<ToolCategory, int> categoryCounts() {
    final counts = <ToolCategory, int>{};
    for (final tool in _tools.values) {
      counts[tool.category] = (counts[tool.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Tools matching any word of [query] in id, name, description, tags or
  /// synonyms. An empty query matches everything.
  List<ToolDescriptor> search(String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return all();
    final matches = all().where((tool) {
      final tokens = tool.searchTokens;
      return words.every(tokens.contains);
    }).toList();
    return matches;
  }

  /// Validate [args] against [tool]'s declared parameters.
  ///
  /// Fills defaults for omitted optional parameters and returns a new map.
  /// Throws [ToolArgumentError] for unknown or missing required parameters.
  Map<String, dynamic> validateArgs(
    ToolDescriptor tool,
    Map<String, dynamic> args,
  ) {
    final declared = <String, ToolParameter>{
      for (final parameter in tool.parameters) parameter.name: parameter,
    };
    for (final key in args.keys) {
      if (!declared.containsKey(key)) {
        final known = declared.keys.isEmpty ? 'none' : declared.keys.join(', ');
        throw ToolArgumentError(
          'Tool "${tool.id}" has no parameter "$key". Accepted: $known.',
        );
      }
    }
    final resolved = <String, dynamic>{};
    for (final parameter in tool.parameters) {
      final provided = args[parameter.name];
      if (provided == null) {
        if (parameter.required) {
          throw ToolArgumentError(
            'Tool "${tool.id}" is missing required parameter '
            '"${parameter.name}" — ${parameter.description}',
          );
        }
        if (parameter.defaultValue != null) {
          resolved[parameter.name] = parameter.defaultValue;
        }
        continue;
      }
      resolved[parameter.name] = provided;
    }
    return resolved;
  }

  /// Run the tool with [id].
  ///
  /// Never throws: a missing tool, bad arguments or a failing implementation
  /// all come back as a failed [ToolResult] so callers have one path.
  Future<ToolResult> run(String id, Map<String, dynamic> args) async {
    final tool = _tools[id];
    if (tool == null) {
      return ToolResult.failure('No tool registered with id "$id".');
    }
    Map<String, dynamic> resolved;
    try {
      resolved = validateArgs(tool, args);
    } on ToolArgumentError catch (error) {
      return ToolResult.failure(error.message);
    }
    final health = healthOf(id);
    health.runs++;
    health.lastUsed = DateTime.now();
    try {
      final result = await tool.run(resolved);
      if (result.success) {
        health.successes++;
        health.lastError = null;
        if (result.value != null) {
          cache?.put(id, '${result.value}');
        }
      } else {
        health.failures++;
        health.lastError = result.error;
        final cached = cache?.get(id);
        if (cached != null) {
          return ToolResult.success(cached);
        }
      }
      return result;
    } catch (error) {
      health.failures++;
      health.lastError = '$error';
      final cached = cache?.get(id);
      if (cached != null) {
        return ToolResult.success(cached);
      }
      return ToolResult.failure('${tool.id} failed: $error');
    }
  }
}
