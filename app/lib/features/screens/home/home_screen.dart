import 'package:flutter/material.dart';

import '../../../core/config/cambric_config.dart';
import '../../../core/localization/app_strings.dart';
import '../../widgets/responsive_layout.dart';
import '../cache/cache_screen.dart';
import '../cambric/cambric_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../palette/command_palette_screen.dart';
import '../settings/settings_screen.dart';
import '../tools/tools_screen.dart';
import '../updates/updates_screen.dart';

/// The product's home screen.
///
/// Every entry on this screen does something. The old "Cambric Setup" card
/// opened the first-run wizard as a dialog, which on an already-configured
/// machine accomplished nothing; it is now a real Cambric screen showing this
/// installation, the other Cambric products present, where the data lives, and
/// the licence.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.config,
    this.existingProducts = const <Map<String, dynamic>>[],
  });

  /// Product configuration, used by Updates and Cambric.
  final CambricConfig config;

  /// Other Cambric products found on this machine.
  final List<Map<String, dynamic>> existingProducts;

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveLayout.isDesktop(context);
    final AppStrings s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(config.productName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.bolt_outlined),
            tooltip: s.text('home.command_palette_tooltip'),
            onPressed: () => showCommandPalette(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: s.text('home.settings_tooltip'),
            onPressed: () => _open(context, SettingsScreen(config: config)),
          ),
        ],
      ),
      body: isWide ? _wideLayout(context) : _narrowLayout(context),
    );
  }

  Widget _narrowLayout(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: _cards(context),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: _cards(context),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: _quickActions(context),
          ),
        ),
      ],
    );
  }

  // ── cards ────────────────────────────────────────────────────────────────

  List<Widget> _cards(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return <Widget>[
      _heroCard(context),
      const SizedBox(height: 16),
      _navCard(
        context,
        icon: Icons.handyman_outlined,
        title: s.text('home.tools_title'),
        subtitle: s.text('home.tools_subtitle'),
        onTap: () => _open(context, const ToolsScreen()),
      ),
      const SizedBox(height: 8),
      _navCard(
        context,
        icon: Icons.bolt_outlined,
        title: s.text('home.palette_title'),
        subtitle: s.text('home.palette_subtitle'),
        onTap: () => showCommandPalette(context),
      ),
      const SizedBox(height: 8),
      _navCard(
        context,
        icon: Icons.layers_outlined,
        title: s.text('home.cambric_title'),
        subtitle: s.text('home.cambric_subtitle'),
        onTap: () => _open(
          context,
          CambricScreen(config: config, initialProducts: existingProducts),
        ),
      ),
      const SizedBox(height: 8),
      _navCard(
        context,
        icon: Icons.system_update_alt_outlined,
        title: s.text('home.updates_title'),
        subtitle: s.text('home.updates_subtitle'),
        onTap: () => _open(context, UpdatesScreen(config: config)),
      ),
      const SizedBox(height: 8),
      _navCard(
        context,
        icon: Icons.storage_outlined,
        title: s.text('home.cache_title'),
        subtitle: s.text('home.cache_subtitle'),
        onTap: () => _open(context, const CacheScreen()),
      ),
      const SizedBox(height: 8),
      _navCard(
        context,
        icon: Icons.monitor_heart_outlined,
        title: s.text('home.diagnostics_title'),
        subtitle: s.text('home.diagnostics_subtitle'),
        onTap: () => _open(context, const DiagnosticsScreen()),
      ),
      const SizedBox(height: 8),
      _navCard(
        context,
        icon: Icons.settings_outlined,
        title: s.text('home.settings_title'),
        subtitle: s.text('home.settings_subtitle'),
        onTap: () => _open(context, SettingsScreen(config: config)),
      ),
      const SizedBox(height: 28),
      _footer(context),
    ];
  }

  Widget _heroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final AppStrings s = AppStrings.of(context);
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.layers_outlined,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
            Text(
              config.productName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              s.withValues(
                'home.hero_subtitle',
                <String, String>{'version': config.version},
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // ── wide-layout panel ────────────────────────────────────────────────────

  List<Widget> _quickActions(BuildContext context) {
    final theme = Theme.of(context);
    final AppStrings s = AppStrings.of(context);

    return <Widget>[
      Text(
        s.text('home.quick_actions'),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      _actionTile(
        context,
        icon: Icons.search,
        title: s.text('home.find_tool_title'),
        subtitle: s.text('home.find_tool_subtitle'),
        onTap: () => _open(context, const ToolsScreen()),
      ),
      _actionTile(
        context,
        icon: Icons.bolt_outlined,
        title: s.text('home.run_command_title'),
        subtitle: s.text('home.run_command_subtitle'),
        onTap: () => showCommandPalette(context),
      ),
      _actionTile(
        context,
        icon: Icons.system_update_alt_outlined,
        title: s.text('home.check_updates_title'),
        subtitle: s.text('home.check_updates_subtitle'),
        onTap: () => _open(context, UpdatesScreen(config: config)),
      ),
      _actionTile(
        context,
        icon: Icons.layers_outlined,
        title: s.text('home.cambric_title'),
        subtitle: s.text('home.cambric_quick_subtitle'),
        onTap: () => _open(
          context,
          CambricScreen(config: config, initialProducts: existingProducts),
        ),
      ),
      const SizedBox(height: 20),
      Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                s.text('home.privacy_title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.text('home.privacy_body'),
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 28),
      _footer(context),
    ];
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // ── footer ───────────────────────────────────────────────────────────────

  Widget _footer(BuildContext context) {
    final theme = Theme.of(context);
    final AppStrings s = AppStrings.of(context);
    return Column(
      children: <Widget>[
        Divider(color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 8),
        Text(
          s.text('home.copyright'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.withValues(
            'home.version',
            <String, String>{'version': config.version},
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}
