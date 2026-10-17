/// Updates screen: check, download, verify, and explain how to install.
///
/// Deliberately does not replace the running application's files. A tool that
/// overwrites itself while running is how you end up with a broken install and
/// no way back, so the screen downloads, verifies, and then tells the person
/// exactly what to do.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/config/cambric_config.dart';
import '../../core/updates/update_center.dart';

/// Shows the update state and the actions available.
class UpdatesScreen extends StatefulWidget {
  /// Create the screen.
  const UpdatesScreen({super.key, required this.config, this.centre});

  /// Product configuration, which decides whether updates are enabled.
  final CambricConfig config;

  /// Centre override, used by tests.
  final UpdateCenter? centre;

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  late final UpdateCenter _centre;
  UpdateCheck? _check;
  bool _working = false;
  String? _downloadNote;
  File? _verifiedPackage;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _centre = widget.centre ?? UpdateCenter(config: widget.config);
  }

  Future<void> _runCheck() async {
    setState(() {
      _working = true;
      _downloadNote = null;
      _progress = null;
    });
    final result = await _centre.check(currentVersion: widget.config.version);
    if (!mounted) return;
    setState(() {
      _working = false;
      _check = result;
    });
  }

  Future<void> _download() async {
    setState(() {
      _working = true;
      _downloadNote = null;
      _progress = 0;
    });
    final file = await _centre.downloadAndVerify(
      onProgress: (received, total) {
        if (total <= 0 || !mounted) return;
        setState(() => _progress = received / total);
      },
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      _verifiedPackage = file;
      _downloadNote = file == null
          ? (_centre.lastError ?? 'Download failed.')
          : 'Verified: ${file.path}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Installed version'),
            subtitle: Text(widget.config.version),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Updates from'),
            subtitle: Text(_centre.repository.isEmpty
                ? 'No release repository configured'
                : _centre.repository),
          ),
          const SizedBox(height: 8),
          if (!_centre.isEnabled)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Automatic updates are switched off in configuration, or no '
                  'release repository is set. Nothing will be downloaded.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _working || !_centre.isEnabled ? null : _runCheck,
            icon: const Icon(Icons.refresh),
            label: Text(_working ? 'Checking...' : 'Check for updates'),
          ),
          if (check != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(check.summary),
                    if (check.isUpdateAvailable) ...<Widget>[
                      const SizedBox(height: 8),
                      Text('Asset: ${check.assetName}'),
                      if (check.assetSizeBytes > 0)
                        Text('Size: ${check.assetSizeBytes} bytes'),
                      if (check.notes.isNotEmpty) Text(check.notes),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (check.isUpdateAvailable)
              FilledButton.icon(
                onPressed: _working ? null : _download,
                icon: const Icon(Icons.download),
                label: const Text('Download and verify'),
              ),
          ],
          if (_progress != null) ...<Widget>[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
          ],
          if (_downloadNote != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_downloadNote!),
          ],
          if (_verifiedPackage != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'The download passed its checksum. To finish installing:',
                    ),
                    const SizedBox(height: 8),
                    Text(UpdateCenter.installHelp(currentPlatformKey())),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Max Tools never replaces its own files while running. Downloads '
            'are verified before they are offered for install.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
