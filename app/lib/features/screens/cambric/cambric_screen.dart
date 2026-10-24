import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/cambric_config.dart';
import '../../../core/ecosystem/product_registry_service.dart';
import '../../../core/storage/cambric_paths.dart';
import '../updates/updates_screen.dart';

/// The Cambric screen: what this installation is, what else from Cambric is on
/// the machine, where its data lives, and the terms it ships under.
///
/// This replaces the home screen's "Cambric Setup" card, which opened the
/// first-run wizard as a dialog. That wizard registered the product — something
/// startup already does — so on a configured machine the card did nothing at
/// all. Everything shown here is read from the running build or the live
/// registry, so nothing on it can go stale.
class CambricScreen extends StatefulWidget {
  /// Create the screen for [config].
  const CambricScreen({
    super.key,
    required this.config,
    this.initialProducts = const <Map<String, dynamic>>[],
  });

  /// The running product's configuration.
  final CambricConfig config;

  /// Products discovered at startup, used until the live registry is read.
  final List<Map<String, dynamic>> initialProducts;

  @override
  State<CambricScreen> createState() => _CambricScreenState();
}

class _CambricScreenState extends State<CambricScreen> {
  late List<Map<String, dynamic>> _products = widget.initialProducts;
  String? _dataRoot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final registry = ProductRegistryService();
    List<Map<String, dynamic>> products = widget.initialProducts;
    String? root;

    try {
      products = await registry.products();
    } catch (_) {
      // A registry that cannot be read is not a reason to fail the screen; the
      // startup snapshot is still accurate as of launch.
    }

    try {
      root = (await CambricPaths.appData()).path;
    } catch (_) {
      root = null;
    }

    if (!mounted) return;
    setState(() {
      _products = products;
      _dataRoot = root;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambric')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              _thisProduct(context),
              const SizedBox(height: 16),
              _installation(context),
              const SizedBox(height: 16),
              _otherProducts(context),
              const SizedBox(height: 16),
              _updates(context),
              const SizedBox(height: 16),
              _licence(context),
              const SizedBox(height: 28),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── this product ─────────────────────────────────────────────────────────

  Widget _thisProduct(BuildContext context) {
    final theme = Theme.of(context);
    final config = widget.config;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.layers_rounded,
                  size: 34,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        config.productName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Version ${config.version}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (config.description != null &&
                config.description!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                config.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── installation ─────────────────────────────────────────────────────────

  Widget _installation(BuildContext context) {
    final config = widget.config;

    return _section(
      context,
      title: 'This installation',
      icon: Icons.memory_outlined,
      children: <Widget>[
        _row(context, 'Product ID', config.productId),
        _row(context, 'Version', config.version),
        _row(context, 'Publisher', config.publisher ?? 'Cambric Software'),
        _row(context, 'Environment', config.environment),
        _row(context, 'Platform', _platformLabel()),
        _row(
          context,
          'Ecosystem protocol',
          'version ${config.ecosystemProtocolVersion}',
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 150,
              child: Text(
                'Data folder',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Text('Reading…')
                  : SelectableText(
                      _dataRoot ?? 'Unavailable',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
            if (_dataRoot != null)
              IconButton(
                tooltip: 'Copy the data folder path',
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _dataRoot!));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data folder path copied.')),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  // ── other products ───────────────────────────────────────────────────────

  Widget _otherProducts(BuildContext context) {
    final others = _products
        .where(
          (Map<String, dynamic> p) =>
              p['productId']?.toString() != widget.config.productId,
        )
        .toList();

    return _section(
      context,
      title: 'Cambric products on this device',
      icon: Icons.devices_other_outlined,
      children: <Widget>[
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Reading the Cambric registry…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else if (others.isEmpty)
          Text(
            'None besides ${widget.config.productName}. Cambric products '
            'register themselves here the first time they start, so anything '
            'else you install will appear in this list.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          )
        else
          for (final product in others) ...<Widget>[
            _productTile(context, product),
            if (product != others.last) const Divider(height: 1),
          ],
      ],
    );
  }

  Widget _productTile(BuildContext context, Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? 'Unnamed product';
    final version = product['version']?.toString();
    final platform = product['platform']?.toString();
    final lastSeen = product['lastSeen']?.toString();

    final details = <String>[
      if (version != null && version.isNotEmpty) 'v$version',
      if (platform != null && platform.isNotEmpty) platform,
      if (lastSeen != null && lastSeen.isNotEmpty) _shortDate(lastSeen),
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.widgets_outlined),
      title: Text(name),
      subtitle: Text(details.isEmpty ? 'Registered' : details.join(' · ')),
    );
  }

  String _shortDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return 'last seen ${local.year}-$month-$day';
  }

  // ── updates ──────────────────────────────────────────────────────────────

  Widget _updates(BuildContext context) {
    final config = widget.config;

    return _section(
      context,
      title: 'Updates',
      icon: Icons.system_update_alt_outlined,
      children: <Widget>[
        _row(context, 'Updates', config.updatesEnabled ? 'Enabled' : 'Disabled'),
        _row(
          context,
          'Automatic checks',
          config.automaticUpdateChecks ? 'On' : 'Off',
        ),
        _row(
          context,
          'Pre-releases',
          config.allowPrerelease ? 'Included' : 'Excluded',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.system_update_alt_outlined),
            label: const Text('Check for updates'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UpdatesScreen(config: config),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── licence ──────────────────────────────────────────────────────────────

  Widget _licence(BuildContext context) {
    final theme = Theme.of(context);

    return _section(
      context,
      title: 'Licence',
      icon: Icons.gavel_outlined,
      children: <Widget>[
        Text(
          '${widget.config.productName} is proprietary software owned by '
          '${widget.config.publisher ?? 'Cambric Software'}. It is not open '
          'source, and no permission is granted to copy, modify or '
          'redistribute it. The full agreement ships with the application as '
          'LICENSE.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
        ),
        const SizedBox(height: 10),
        Text(
          'Copyright © 2026 ${widget.config.publisher ?? 'Cambric Software'}. '
          'All rights reserved.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ── footer ───────────────────────────────────────────────────────────────

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
      ],
    );
  }

  // ── primitives ───────────────────────────────────────────────────────────

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

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _platformLabel() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    return Platform.operatingSystem;
  }
}
