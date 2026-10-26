/// Runs one tool from its declared parameters.
///
/// The form is generated from [ToolDescriptor.parameters], so adding a tool
/// never means writing a screen. Missing or invalid input is reported by the
/// registry as a failure result and shown verbatim — the UI never invents an
/// error message the tool layer did not produce.
library;

import 'package:flutter/material.dart';

import '../../tools/tool_descriptor.dart';
import '../../tools/tool_registry.dart';
import '../../tools/tools_scope.dart';

/// Screen that collects arguments for a tool and runs it.
class ToolRunnerScreen extends StatefulWidget {
  /// Create a runner for [tool].
  const ToolRunnerScreen({super.key, required this.tool, this.registry});

  /// The tool to run.
  final ToolDescriptor tool;

  /// Registry override, used by tests. Null uses [ToolsScope].
  final ToolRegistry? registry;

  @override
  State<ToolRunnerScreen> createState() => _ToolRunnerScreenState();
}

class _ToolRunnerScreenState extends State<ToolRunnerScreen> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  ToolResult? _result;
  bool _running = false;

  ToolRegistry get _registry => widget.registry ?? ToolsScope.of(context);

  @override
  void initState() {
    super.initState();
    for (final parameter in widget.tool.parameters) {
      final initial = parameter.defaultValue;
      _controllers[parameter.name] = TextEditingController(
        text: initial == null ? '' : '$initial',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _result = null;
    });
    final args = <String, dynamic>{};
    for (final parameter in widget.tool.parameters) {
      final text = _controllers[parameter.name]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      args[parameter.name] = _coerce(text);
    }
    final result = await _registry.run(widget.tool.id, args);
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  /// Interpret a typed value as a bool when it obviously is one.
  ///
  /// Only unambiguous forms convert; everything else stays a string so a tool
  /// that expects text never receives a surprise bool.
  static Object _coerce(String text) {
    switch (text.toLowerCase()) {
      case 'true':
      case 'yes':
        return true;
      case 'false':
      case 'no':
        return false;
      default:
        return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return Scaffold(
      appBar: AppBar(title: Text(tool.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(tool.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            tool.id,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 20),
          for (final parameter in tool.parameters) ...<Widget>[
            TextField(
              controller: _controllers[parameter.name],
              decoration: InputDecoration(
                labelText: parameter.name,
                helperText: parameter.required
                    ? '${parameter.description} (required)'
                    : parameter.description,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_outlined),
            label: Text(_running ? 'Running...' : 'Run'),
          ),
          if (!tool.readOnly) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'This tool changes data.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          if (_result != null) ...<Widget>[
            const SizedBox(height: 24),
            _ResultPanel(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final ToolResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = result.success
        ? scheme.surfaceContainerHighest
        : scheme.errorContainer;
    final foreground = result.success
        ? scheme.onSurface
        : scheme.onErrorContainer;
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              result.success ? 'Result' : 'Failed',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: foreground),
            ),
            const SizedBox(height: 8),
            SelectableText(
              result.success ? '${result.value}' : '${result.error}',
              style: TextStyle(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
