/// Provides the app-wide [ToolRegistry] to the widget tree.
///
/// A scope rather than a service locator: widgets depend on the registry the
/// same way they depend on a theme, and tests can supply their own instance.
library;

import 'package:flutter/widgets.dart';

import 'tool_registry.dart';

/// Exposes a [ToolRegistry] to descendants.
class ToolsScope extends InheritedWidget {
  /// Wrap [child] so descendants can read the registry.
  const ToolsScope({
    super.key,
    required this.registry,
    required super.child,
  });

  /// The registry every tool screen and runner resolves tools through.
  final ToolRegistry registry;

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

  @override
  bool updateShouldNotify(ToolsScope oldWidget) =>
      oldWidget.registry != registry;
}
