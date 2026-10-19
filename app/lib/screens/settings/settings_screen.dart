import 'package:flutter/material.dart';

import '../../core/config/cambric_config.dart';
import '../../core/settings/app_settings.dart';
import '../cache/cache_screen.dart';
import '../cambric/cambric_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../updates/updates_screen.dart';

/// Application settings.
///
/// Every control on this screen has a visible effect. The previous version was
/// four cards of template text — an "About" that described a Cambric template
/// rather than this product, and a cache card that was the only thing that did
/// anything at all.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.config});

  /// Product configuration, for the about and update sections.
  final CambricConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              _section(
                context,
                title: 'Appearance',
                icon: Icons.palette_outlined,
                children: <Widget>[
                  Text(
                    'Choose how Max Tools looks. System follows your operating '
                    'system setting, including when it changes at sunset.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppSettings.instance.themeMode,
                    builder: (BuildContext context, ThemeMode mode, Widget? _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const <ButtonSegment<ThemeMode>>[
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: <ThemeMode>{mode},
                        onSelectionChanged: (Set<ThemeMode> selection) {
                          if (selection.isEmpty) return;
                          AppSettings.instance.setThemeMode(selection.first);
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                context,
                title: 'Storage',
                icon: Icons.storage_outlined,
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('Cache'),
                    subtitle: const Text(
                      'See how much cached data is being held, and clear it',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(context, const CacheScreen()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.monitor_heart_outlined),
                    title: const Text('Diagnostics'),
                    subtitle: const Text(
                      'Platform, build and storage details for support',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(context, const DiagnosticsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                context,
                title: 'Updates',
                icon: Icons.system_update_alt_outlined,
                children: <Widget>[
                  Text(
                    config.updatesEnabled
                        ? 'Updates are enabled. Max Tools checks for a new '
                            'release ${config.automaticUpdateChecks ? "automatically" : "when you ask"}, '
                            'downloads it, and verifies its published checksum '
                            'before installing.'
                        : 'Updates are disabled in this build. You can still '
                            'check for a release manually.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.system_update_alt_outlined),
                      label: const Text('Check for updates'),
                      onPressed: () =>
                          _open(context, UpdatesScreen(config: config)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                context,
                title: 'About',
                icon: Icons.info_outline,
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.layers_outlined),
                    title: Text(config.productName),
                    subtitle: Text(
                      'Version ${config.version} · ${config.publisher ?? "Cambric Software"}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(
                      context,
                      CambricScreen(config: config),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restart_alt_outlined),
                    title: const Text('Restore default settings'),
                    subtitle: const Text(
                      'Returns appearance to following your system. Does not '
                      'delete tools, files or history.',
                    ),
                    onTap: () => _restoreDefaults(context),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreDefaults(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Restore default settings?'),
        content: const Text(
          'Appearance goes back to following your system. Your files, tools '
          'and history are untouched.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AppSettings.instance.restoreDefaults();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default settings restored.')),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Icon(
          Icons.copyright_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 6),
        Text(
          'Copyright © 2026 Cambric Software. All rights reserved.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${config.productName} ${config.version}',
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
