/// Browsable catalogue of every registered tool.
///
/// Search, category filter and tool counts all read from the registry, so the
/// screen has no hardcoded knowledge of which tools exist.
library;

import 'package:flutter/material.dart';

import '../../tools/tool_descriptor.dart';
import '../../tools/tool_registry.dart';
import '../../tools/tools_scope.dart';
import 'tool_runner_screen.dart';

/// Lists tools with search and category filtering.
class ToolsScreen extends StatefulWidget {
  /// Create the tools browser.
  const ToolsScreen({super.key, this.registry});

  /// Registry override, used by tests. Null uses [ToolsScope].
  final ToolRegistry? registry;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  ToolCategory? _category;

  ToolRegistry get _registry => widget.registry ?? ToolsScope.of(context);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ToolDescriptor> get _visibleTools {
    final byCategory = _category == null
        ? _registry.all()
        : _registry.byCategory(_category!);
    if (_query.trim().isEmpty) return byCategory;
    return byCategory
        .where((tool) => _matches(tool, _query))
        .toList();
  }

  /// Match every word of the query against the tool's tokens, so
  /// "parse csv" finds "Parse CSV" and not merely anything containing "csv".
  static bool _matches(ToolDescriptor tool, String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty);
    final tokens = tool.searchTokens;
    return words.every(tokens.contains);
  }

  @override
  Widget build(BuildContext context) {
    final tools = _visibleTools;
    final counts = _registry.categoryCounts();
    return Scaffold(
      appBar: AppBar(
        title: Text('Tools (${_registry.length})'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tools',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: <Widget>[
                _chip(context, label: 'All', selected: _category == null, onTap: () {
                  setState(() => _category = null);
                }),
                for (final entry in counts.entries)
                  _chip(
                    context,
                    label: '${entry.key.label} (${entry.value})',
                    selected: _category == entry.key,
                    onTap: () => setState(() => _category = entry.key),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tools.isEmpty
                ? const Center(
                    child: Text('No tools match that search.'),
                  )
                : ListView.separated(
                    itemCount: tools.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tool = tools[index];
                      return ListTile(
                        leading: Icon(tool.icon ?? Icons.widgets_outlined),
                        title: Text(tool.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(tool.description),
                            _healthLine(tool),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Health',
                              icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                              onPressed: () => _showHealth(context, tool),
                            ),
                            if (tool.screen != null)
                              const Icon(Icons.chevron_right)
                            else if (!tool.readOnly)
                              const Icon(Icons.edit_outlined, size: 18),
                          ],
                        ),
                        onTap: () => _open(context, tool),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _healthLine(ToolDescriptor tool) {
    final h = _registry.healthOf(tool.id);
    if (h.runs == 0) return const SizedBox.shrink();
    final pct = (h.successRate * 100).round();
    return Text(
      '$pct% success · ${h.runs} run${h.runs == 1 ? '' : 's'}'
          '${h.lastError == null ? '' : ' · last error: ${h.lastError}'}',
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Future<void> _showHealth(BuildContext context, ToolDescriptor tool) async {
    final h = _registry.healthOf(tool.id);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${tool.name} health'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Runs: ${h.runs}'),
            Text('Successes: ${h.successes}'),
            Text('Failures: ${h.failures}'),
            Text('Success rate: ${(h.successRate * 100).round()}%'),
            Text('Last used: ${h.lastUsed?.toLocal() ?? 'never'}'),
            if (h.lastError != null) Text('Last error: ${h.lastError}'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              h.runs = 0;
              h.successes = 0;
              h.failures = 0;
              h.lastUsed = null;
              h.lastError = null;
              Navigator.of(ctx).pop();
              setState(() {});
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  /// Open a tool. A tool with its own screen opens that; anything else gets
  /// the generated argument form.
  void _open(BuildContext context, ToolDescriptor tool) {
    final screen = tool.screen;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: screen ??
            (_) => ToolRunnerScreen(
                  tool: tool,
                  registry: widget.registry,
                ),
      ),
    );
  }

  Widget _chip(    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
