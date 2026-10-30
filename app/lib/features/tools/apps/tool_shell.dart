import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/tool_theme_service.dart';

/// The frame every tool's own screen sits inside.
///
/// A tool is meant to feel like a small application rather than a menu entry,
/// so each one opens with a plain-language explanation of what it does and how
/// to use it, then the tool itself. The explanation is not decoration: the
/// complaint that started this rebuild was tools nobody could work out.
class ToolShell extends StatelessWidget {
  /// Create the frame.
  const ToolShell({
    super.key,
    required this.title,
    required this.howTo,
    required this.children,
    this.actions,
    this.exportText,
    this.toolId,
    this.maxWidth = 900,
  });

  /// Shown in the app bar.
  final String title;

  /// One short paragraph: what this does, and how to use it.
  final String howTo;

  /// The tool itself.
  final List<Widget> children;

  /// Optional app-bar actions.
  final List<Widget>? actions;

  /// When set, an export menu is shown in the app bar.
  final String? exportText;

  /// Optional tool id. When set, per-tool accent and density overrides apply.
  final String? toolId;

  /// Content width. Charts and tables get more room than text tools.
  final double maxWidth;

  void _export(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exported to clipboard.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exportActions = exportText == null
        ? const <Widget>[]
        : <Widget>[
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: () => _export(context, exportText!),
            ),
          ];
    final appearanceActions = toolId == null
        ? const <Widget>[]
        : <Widget>[
            IconButton(
              tooltip: 'Appearance',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => _showAppearance(context, toolId!),
            ),
          ];
    final accent = toolId == null
        ? null
        : ToolThemeService.instance.accentFor(toolId!);
    Widget body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: <Widget>[
            _HowTo(text: howTo),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
    if (accent != null) {
      body = Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        ),
        child: body,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[...?actions, ...exportActions, ...appearanceActions],
      ),
      body: body,
    );
  }

  Future<void> _showAppearance(BuildContext context, String toolId) async {
    final service = ToolThemeService.instance;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appearance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Accent'),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (var i = 0; i < ToolThemeService.accents.length; i++)
                  GestureDetector(
                    onTap: () async {
                      await service.setAccent(toolId, i);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ToolThemeService.accents[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: service.accentFor(toolId) ==
                                  ToolThemeService.accents[i]
                              ? Colors.black
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Density'),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final d in const <String>['compact', 'comfortable', 'spacious'])
                  ChoiceChip(
                    label: Text(d),
                    selected: service.densityFor(toolId) == d,
                    onSelected: (_) async {
                      await service.setDensity(toolId, d);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    // Trigger rebuild by no-op setState not available in StatelessWidget;
    // the next build reads the updated service.
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.lightbulb_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled block inside a tool screen.
class ToolSection extends StatelessWidget {
  /// Create a section.
  const ToolSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
  });

  /// Section heading.
  final String title;

  /// Optional icon beside the heading.
  final IconData? icon;

  /// Optional widget on the right of the heading.
  final Widget? trailing;

  /// Section contents.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 19, color: theme.colorScheme.primary),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A quiet explanatory line, used under a control or above a result.
class ToolNote extends StatelessWidget {
  /// Create a note.
  const ToolNote(this.text, {super.key, this.warning = false});

  /// What to say.
  final String text;

  /// Render as a warning rather than an aside.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = warning
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 16,
            color: colour,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colour,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A selectable monospace result box with a copy button.
class ToolOutput extends StatelessWidget {
  /// Create an output box.
  const ToolOutput({
    super.key,
    required this.text,
    this.label = 'Result',
    this.minHeight = 90,
  });

  /// The text to show.
  final String text;

  /// Heading above the box.
  final String label;

  /// Keeps short results from jumping around as they change.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy to clipboard',
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              onPressed: () {
                // Imported lazily so every tool does not need the services
                // import just to offer a copy button.
                _copy(context, text);
              },
            ),
          ],
        ),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: SelectableText(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied.'), duration: Duration(seconds: 1)),
    );
  }
}
