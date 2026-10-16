/// Descriptor model for a Max Tools tool.
///
/// A tool is data plus a runner. Anything that can be described (name,
/// category, parameters, tags) and invoked with a map of arguments can be
/// exposed to the UI and to the command palette without either of them
/// knowing anything about the implementation.
library;

import 'variable_store.dart';

/// Broad grouping used for browsing, filtering and palette prefixes.
enum ToolCategory {
  developer('Developer'),
  animator('Animator'),
  freelancer('Freelancer'),
  business('Business'),
  data('Data'),
  file('File'),
  security('Security'),
  network('Network'),
  system('System');

  const ToolCategory(this.label);

  /// Human-readable name shown in the UI.
  final String label;

  /// Resolve a label (case-insensitive) back to its category.
  ///
  /// Returns null for an unknown label so callers can report it rather than
  /// silently defaulting to the wrong bucket.
  static ToolCategory? tryParse(String value) {
    final needle = value.trim().toLowerCase();
    for (final category in ToolCategory.values) {
      if (category.name.toLowerCase() == needle ||
          category.label.toLowerCase() == needle) {
        return category;
      }
    }
    return null;
  }
}

/// A single named input to a tool.
class ToolParameter {
  /// Create a parameter description.
  const ToolParameter({
    required this.name,
    required this.description,
    this.required = false,
    this.defaultValue,
    this.type = VariableType.text,
  });

  /// Machine name, as passed in the arguments map.
  final String name;

  /// What this input means, shown in the palette and tool browser.
  final String description;

  /// Whether the tool cannot run without it.
  final bool required;

  /// Value used when the caller omits a non-required parameter.
  final Object? defaultValue;

  /// Expected kind of value.
  ///
  /// Left as [VariableType.text] by default; [resolvedType] then infers the
  /// type from [defaultValue] so existing descriptors describe themselves.
  final VariableType type;

  /// The type to use when parsing and rendering: the declared [type] unless it
  /// was left as text and [defaultValue] implies something else.
  VariableType get resolvedType {
    if (type != VariableType.text) return type;
    if (defaultValue == null) return VariableType.text;
    return VariableType.infer(defaultValue);
  }

  /// Whether this parameter holds a number.
  bool get isNumeric => resolvedType == VariableType.number;

  /// Whether this parameter holds a flag.
  bool get isBoolean => resolvedType == VariableType.boolean;
}

/// Outcome of running a tool.
///
/// Tools never throw at the caller: every failure is an explicit [ToolResult]
/// with `success == false` and a human-readable [error].
class ToolResult {
  /// A successful result carrying [value].
  const ToolResult.success(this.value)
      : success = true,
        error = null;

  /// A failed result. [error] must be present and non-empty.
  const ToolResult.failure(this.error)
      : success = false,
        value = null;

  /// Whether the tool completed successfully.
  final bool success;

  /// The produced value on success; null on failure.
  final Object? value;

  /// Why it failed; null on success.
  final String? error;

  @override
  String toString() => success ? 'ToolResult.success($value)' : 'ToolResult.failure($error)';
}

/// Signature every tool implementation must match.
///
/// [args] has already been validated and defaulted by the registry.
typedef ToolRunner = Future<ToolResult> Function(Map<String, dynamic> args);

/// Everything the registry knows about one callable tool.
class ToolDescriptor {
  /// Create a tool descriptor.
  const ToolDescriptor({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.run,
    this.parameters = const <ToolParameter>[],
    this.tags = const <String>[],
    this.synonyms = const <String>[],
    this.readOnly = true,
  });

  /// Dotted identifier, e.g. `data.csv.parse`. Stable across renames of
  /// [name]; automation and saved workflows bind to this.
  final String id;

  /// Short display name, e.g. `Parse CSV`.
  final String name;

  /// One-line explanation of what the tool does.
  final String description;

  /// Grouping for browsing and palette prefixes.
  final ToolCategory category;

  /// The implementation.
  final ToolRunner run;

  /// Declared inputs, in display order.
  final List<ToolParameter> parameters;

  /// Extra keywords for search.
  final List<String> tags;

  /// Alternative phrasings the command palette should also match.
  final List<String> synonyms;

  /// Whether the tool only reads state. Write tools are called out so the UI
  /// can confirm before running them and so audits can separate them.
  final bool readOnly;

  /// Lookup a parameter by name.
  ToolParameter? parameter(String name) {
    for (final parameter in parameters) {
      if (parameter.name == name) return parameter;
    }
    return null;
  }

  /// Every word this tool should be findable by: id, name, description,
  /// tags and synonyms.
  Set<String> get searchTokens => <String>{
        id,
        name,
        description,
        ...tags,
        ...synonyms,
      }
          .map((token) => token.toLowerCase())
          .expand((token) => token.split(RegExp(r'[^a-z0-9]+')))
          .where((token) => token.isNotEmpty)
          .toSet();
}
