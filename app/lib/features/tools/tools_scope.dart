/// Provides the app-wide [ToolRegistry] to the widget tree.
///
/// A scope rather than a service locator: widgets depend on the registry the
/// same way they depend on a theme, and tests can supply their own instance.
library;

import 'package:flutter/widgets.dart';

import '../../../core/command/intent_parser.dart';
import 'tool_registry.dart';
import 'variable_store.dart';

/// Exposes the app's tool state to descendants.
class ToolsScope extends InheritedWidget {
  /// Wrap [child] so descendants can read the registry and variables.
  const ToolsScope({
    super.key,
    required this.registry,
    required super.child,
    this.variables,
    this.parser,
  });

  /// The registry every tool screen and runner resolves tools through.
  final ToolRegistry registry;

  /// Variables shared between tool runs.
  ///
  /// Defaults to an in-memory store, which is right for tests and for a
  /// session where persistence is not wanted.
  final VariableStore? variables;

  /// Parser used by the command palette.
  ///
  /// Built on demand from [registry] when not supplied.
  final IntentParser? parser;

  /// The nearest registry.
  ///
  /// Throws a readable [Error] when no scope is present, because a tool screen
  /// without a registry is a wiring bug rather than a runtime condition.
  static ToolRegistry of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ToolsScope>();
    if (scope == null) {
      throw FlutterError(
        'ToolsScope.of() was called with a context that does not contain a '
        'ToolsScope. Wrap the widget tree in a ToolsScope at the app root.',
      );
    }
    return scope.registry;
  }

  /// The nearest scope itself, for variables and the parser.
  static ToolsScope scopeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ToolsScope>();
    if (scope == null) {
      throw FlutterError(
        'ToolsScope.scopeOf() was called with a context that does not contain '
        'a ToolsScope.',
      );
    }
    return scope;
  }

  /// The shared variable store.
  static VariableStore variablesOf(BuildContext context) =>
      scopeOf(context).variables ?? VariableStore();

  /// The palette parser for this scope.
  static IntentParser parserOf(BuildContext context) =>
      scopeOf(context).parser ??
      IntentParser(scopeOf(context).registry);

  @override
  bool updateShouldNotify(ToolsScope oldWidget) =>
      oldWidget.registry != registry ||
      oldWidget.variables != variables ||
      oldWidget.parser != parser;
}
