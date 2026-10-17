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
import '../../core/updates/install_layout.dart';
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

  /// True once a verified download is waiting to be installed.
  bool get _readyToInstall =>
      _verifiedPackage != null && (_check?.isUpdateAvailable ?? false);

  /// Start installing the verified download, then restart into it.
  Future<void> _installAndRestart() async {
    final version = _check?.latestVersion;
    if (version == null || version.isEmpty) return;
    setState(() {
      _working = true;
      _downloadNote = null;
    });

    final outcome = await _centre.installDownloaded(version);
    if (!mounted) return;
    if (!outcome.ok) {
      setState(() {
        _working = false;
        _downloadNote = outcome.message ?? 'The update could not be installed.';
      });
      return;
    }

    // Remember what we came from so rollback stays available.
    _centre.rememberRollbackTarget(outcome.previousVersion);
    setState(() {
      _working = false;
      _downloadNote = 'Installed $version. Restarting...';
    });

    // Hand over to the new version and exit. The running files are never
    // touched, so this cannot fail half-way.
    await relaunchVersion(version, layout: _centre.layout);
  }

  /// Return to the previous version.
  Future<void> _rollback(String version) async {
    setState(() {
      _working = true;
      _downloadNote = null;
    });
    final outcome = await _centre.rollbackTo(version);
    if (!mounted) return;
    setState(() {
      _working = false;
      _downloadNote = outcome.ok
          ? 'Switched back to $version. Restarting...'
          : (outcome.message ?? 'Could not switch back to $version.');
    });
    if (outcome.ok) {
      await relaunchVersion(version, layout: _centre.layout);
    }
  }

  @override
  void initState() {
    super.initState();
    // The centre is the single source of truth, including the rollback target
    // recorded by an update earlier in this session.
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
                      'The download passed its checksum.',
                    ),
                    const SizedBox(height: 8),
                    if (_centre.canSelfUpdate)
                      const Text(
                        'Installing adds the new version alongside the current '
                        'one and switches to it on restart. Your current '
                        'version stays on disk, so you can go back at any time.',
                      )
                    else
                      Text(
                        'This copy of Max Tools was not installed with the '
                        'setup executable, so it cannot update itself.\n\n'
                        '${UpdateCenter.installHelp(currentPlatformKey())}',
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_readyToInstall) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _working ? null : _installAndRestart,
              icon: const Icon(Icons.restart_alt),
              label: Text(
                'Install ${_check!.latestVersion} and restart',
              ),
            ),
          ],
          if (_centre.rollbackTarget != null) ...<Widget>[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed:
                  _working ? null : () => _rollback(_centre.rollbackTarget!),
              icon: const Icon(Icons.history),
              label: Text('Go back to version ${_centre.rollbackTarget}'),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Max Tools never replaces its own files while running. Each update '
            'is unpacked into its own folder and only becomes active after you '
            'restart, so a failed install cannot damage the version you have.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
