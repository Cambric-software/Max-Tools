/// The command palette: say what you want, watch it run.
///
/// Everything here is a thin view over [IntentParser] and [ToolRegistry]. The
/// palette never decides for itself which tool to run — it shows what the
/// parser understood, how confident it is, and what it is missing, so the user
/// stays in control.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../command/intent_parser.dart';
import '../../tools/tool_descriptor.dart';
import '../../tools/tool_registry.dart';
import '../../tools/tools_scope.dart';
import '../../tools/variable_store.dart';

/// Show the palette as a modal overlay.
///
/// Returns the sentence that was run, or null if dismissed.
Future<String?> showCommandPalette(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const CommandPaletteDialog(),
  );
}

/// Modal palette dialog.
class CommandPaletteDialog extends StatefulWidget {
  /// Create the palette.
  const CommandPaletteDialog({super.key, this.registry, this.variables});

  /// Registry override, used by tests.
  final ToolRegistry? registry;

  /// Variable store override, used by tests.
  final VariableStore? variables;

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _input = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers =
      <String, TextEditingController>{};
  final FocusNode _inputFocus = FocusNode();

  PaletteIntent? _intent;
  ToolResult? _result;
  bool _running = false;
  List<String> _history = <String>[];

  ToolRegistry get _registry =>
      widget.registry ?? ToolsScope.of(context);

  VariableStore get _variables =>
      widget.variables ?? ToolsScope.variablesOf(context);

  /// The parser for this scope.
  ///
  /// Resolved through [ToolsScope] so an injected parser — with a vocabulary
  /// suited to the registry in use — is honoured rather than replaced by a
  /// fresh default one.
  IntentParser get _parser => ToolsScope.parserOf(context);

  @override
  void initState() {
    super.initState();
    // Ctrl+K and Cmd+K open the palette from anywhere.
    HardwareKeyboard.instance.addHandler(_handleShortcut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleShortcut);
    _input.dispose();
    _inputFocus.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _handleShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed;
    final meta = keyboard.isMetaPressed;
    if ((ctrl || meta) && event.logicalKey == LogicalKeyboardKey.keyK) {
      _inputFocus.requestFocus();
      return true;
    }
    return false;
  }

  void _onChanged(String value) {
    setState(() {
      _result = null;
      _intent = value.trim().isEmpty ? null : _parser.parse(value, variables: _variables);
      _syncFields();
    });
  }

  /// Create a controller for every parameter the palette still needs.
  void _syncFields() {
    final parameters = _intent?.missingParameters ?? <ToolParameter>[];
    for (final parameter in parameters) {
      _fieldControllers.putIfAbsent(
        parameter.name,
        () => TextEditingController(
          text: '${_intent?.arguments[parameter.name] ?? ''}',
        ),
      );
    }
    for (final name in _fieldControllers.keys.toList()) {
      if (!parameters.any((p) => p.name == name)) {
        _fieldControllers.remove(name)!.dispose();
      }
    }
  }

  Future<void> _run() async {
    final intent = _intent;
    final best = intent?.best;
    if (best == null) return;

    // A tool with its own screen is an application, not a one-shot command:
    // close the palette and open it.
    final screen = best.tool.screen;
    if (screen != null) {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(MaterialPageRoute<void>(builder: screen));
      return;
    }

    final args = <String, dynamic>{...intent!.arguments};
    for (final entry in _fieldControllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) args[entry.key] = text;
    }

    setState(() => _running = true);
    final result = await _registry.run(best.tool.id, args);
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
      _history = <String>[intent.sentence, ..._history.take(9)];
    });
  }

  void _saveAsVariable() {
    final value = _result?.value;
    if (value == null) return;
    var name = 'result';
    var suffix = 1;
    while (_variables.has(name)) {
      name = 'result${suffix++}';
    }
    _variables.set(
      name,
      value: value,
      type: VariableType.infer(value),
      description: _intent?.best?.tool.name ?? '',
      fromTool: _intent?.best?.tool.id ?? '',
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.search),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      autofocus: true,
                      textInputAction: TextInputAction.go,
                      decoration: const InputDecoration(
                        hintText: 'What do you want to do?',
                        border: InputBorder.none,
                      ),
                      onChanged: _onChanged,
                      onSubmitted: (_) => _run(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              Flexible(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final intent = _intent;
    if (intent == null || intent.isEmpty) {
      // A plain scroll view rather than a ListView: every panel is built, so
      // the result is always reachable without lazy-loading surprises.
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
          const SizedBox(height: 12),
          Text(
            'Type a request in plain English.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Examples: "check a folder for viruses", "convert celsius to '
            'fahrenheit", "verify a checksum", "count the words".',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_history.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text('Recent', style: Theme.of(context).textTheme.labelLarge),
            for (final entry in _history)
              ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 18),
                title: Text(entry),
                onTap: () {
                  _input.text = entry;
                  _onChanged(entry);
                },
              ),
          ],
          if (_variables.names().isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text('Variables', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final variable in _variables.all().take(12))
                  Chip(
                    label: Text('\$${variable.name}'),
                    onDeleted: () => setState(() {
                      _variables.remove(variable.name);
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    }

    final best = intent.best!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
        if (intent.wasCorrected)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Did you mean "${intent.correctionNote}"?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            intent.isConfident ? Icons.check_circle_outline : Icons.help_outline,
            color: intent.isConfident
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.tertiary,
          ),
          title: Text(best.tool.name),
          subtitle: Text(
            '${best.tool.id} - ${best.tool.description}\n'
            'matched on "${best.matchedOn}" (${(best.score * 100).round()}%)',
          ),
          isThreeLine: true,
        ),
        for (final parameter in _intent?.missingParameters ?? <ToolParameter>[])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              controller: _fieldControllers[parameter.name],
              decoration: InputDecoration(
                labelText: parameter.name,
                helperText: parameter.description,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        if (intent.arguments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Arguments: ${intent.arguments.entries.map((e) => '${e.key}: ${e.value}').join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed: _running ? null : _run,
              icon: const Icon(Icons.play_arrow_outlined),
              label: Text(_running ? 'Running...' : 'Run'),
            ),
            if (_result?.success == true) ...<Widget>[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _saveAsVariable,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save as variable'),
              ),
            ],
          ],
        ),
        if (_result != null) ...<Widget>[
          const SizedBox(height: 16),
          _ResultBox(result: _result!),
        ],
        if (intent.candidates.length > 1) ...<Widget>[
          const SizedBox(height: 16),
          Text('Other matches', style: Theme.of(context).textTheme.labelLarge),
          for (final candidate in intent.candidates.skip(1))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(candidate.tool.name),
              subtitle: Text('${candidate.tool.id} - ${(candidate.score * 100).round()}%'),
              onTap: () {
                _input.text = candidate.tool.name;
                _onChanged(candidate.tool.name);
              },
            ),
        ],
      ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({required this.result});

  final ToolResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: result.success ? scheme.surfaceContainerHighest : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              result.success ? 'Result' : 'Failed',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SelectableText(
              result.success ? '${result.value}' : '${result.error}',
              style: TextStyle(
                color: result.success ? scheme.onSurface : scheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
