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
                        title: Text(tool.name),
                        subtitle: Text(tool.description),
                        trailing: tool.readOnly
                            ? null
                            : const Icon(Icons.edit_outlined, size: 18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ToolRunnerScreen(
                              tool: tool,
                              registry: widget.registry,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
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
