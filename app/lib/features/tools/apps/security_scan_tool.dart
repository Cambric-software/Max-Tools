import 'dart:io';

import 'package:flutter/material.dart';

import 'tool_io.dart';
import 'tool_shell.dart';

/// Findings are deliberately few and concrete. A scanner that reports "1000
/// things" teaches nobody anything.
enum _Severity { high, medium, note }

class _Finding {
  const _Finding(this.severity, this.path, this.reason);

  final _Severity severity;
  final String path;
  final String reason;
}

/// Antivirus and file check.
///
/// Two genuinely different things happen here, and the screen says which is
/// which rather than blurring them:
///
///  * The **system scan** drives the antivirus the machine already has —
///    Microsoft Defender on Windows, ClamAV on Linux — and reports its real
///    exit code and output. That is a real scan by a real engine.
///
///  * The **quick check** is a pattern review: double extensions, executables
///    in download and temp folders, hidden executables, bidirectional filename
///    tricks, and script files containing the handful of constructs used by
///    droppers. It is not signature-based and cannot detect a novel binary.
///
/// Claiming otherwise would be the exact kind of invented result this rebuild
/// exists to remove.
class SecurityScanTool extends StatefulWidget {
  /// Create the tool.
  const SecurityScanTool({super.key});

  @override
  State<SecurityScanTool> createState() => _SecurityScanToolState();
}

class _SecurityScanToolState extends State<SecurityScanTool> {
  final TextEditingController _path = TextEditingController(text: homeDirectory);

  bool _running = false;
  String _activity = '';
  List<_Finding> _findings = <_Finding>[];
  String? _summary;
  int _filesChecked = 0;
  bool _checked = false;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  /// Look for an antivirus already installed on this machine.
  ///
  /// Detection deliberately waits until a scan is asked for: nothing should
  /// start a process on this computer just because a screen was opened.
  Future<String?> _detectScanner() async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run(
          'powershell',
          <String>[
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'Get-MpComputerStatus | Select-Object -ExpandProperty AMServiceEnabled',
          ],
        ).timeout(const Duration(seconds: 15));
        if ('${result.stdout}'.toLowerCase().contains('true')) {
          return 'Microsoft Defender';
        }
      } catch (_) {
        // No Defender, no PowerShell, or no permission.
      }
      return null;
    }

    if (Platform.isLinux) {
      for (final candidate in <String>['clamdscan', 'clamscan']) {
        try {
          final result = await Process.run('which', <String>[candidate]);
          if (result.exitCode == 0 && '${result.stdout}'.trim().isNotEmpty) {
            return 'ClamAV ($candidate)';
          }
        } catch (_) {
          // Try the next candidate.
        }
      }
    }

    return null;
  }

  Future<void> _pick() async {
    final chosen = await pickDirectory(context, start: _path.text.trim());
    if (chosen == null) return;
    setState(() => _path.text = chosen);
  }

  Future<void> _runSystemScan() async {
    final folder = _path.text.trim();
    if (folder.isEmpty) return;

    setState(() {
      _running = true;
      _checked = false;
      _findings = <_Finding>[];
      _summary = null;
      _activity = 'Looking for an antivirus on this machine…';
    });

    final scanner = await _detectScanner();
    if (!mounted) return;
    if (scanner == null) {
      setState(() {
        _running = false;
        _checked = true;
        _activity = '';
        _summary = 'No system antivirus was found. Microsoft Defender and '
            'ClamAV were both checked. The quick check still works, but it '
            'cannot replace a scanner with virus signatures.';
      });
      return;
    }

    setState(() => _activity = 'Running $scanner…');

    try {
      ProcessResult result;
      if (Platform.isWindows) {
        final escaped = folder.replaceAll("'", "''");
        result = await Process.run(
          'powershell',
          <String>[
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "Start-MpScan -ScanType CustomScan -ScanPath '$escaped'",
          ],
        ).timeout(const Duration(minutes: 10));
      } else {
        final command = scanner.contains('clamdscan') ? 'clamdscan' : 'clamscan';
        result = await Process.run(
          command,
          <String>['-r', '--infected', '--no-summary', folder],
        ).timeout(const Duration(minutes: 20));
      }

      final output = <String>[
        if ('${result.stdout}'.trim().isNotEmpty) '${result.stdout}'.trim(),
        if ('${result.stderr}'.trim().isNotEmpty) '${result.stderr}'.trim(),
      ].join('\n');

      if (!mounted) return;
      setState(() {
        _running = false;
        _checked = true;
        _activity = '';
        _summary = output.isEmpty
            ? '$scanner finished with exit code ${result.exitCode}. '
                'No output was produced, which normally means it found nothing '
                'to report.'
            : '$scanner finished with exit code ${result.exitCode}.\n\n'
                '$output';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _activity = '';
        _summary = 'The system scan could not run: $error';
      });
    }
  }

  Future<void> _runQuickCheck() async {
    final folder = Directory(_path.text.trim());
    if (!folder.existsSync()) {
      setState(() {
        _checked = true;
        _summary = 'That folder does not exist.';
        _findings = <_Finding>[];
      });
      return;
    }

    setState(() {
      _running = true;
      _checked = false;
      _findings = <_Finding>[];
      _summary = null;
      _filesChecked = 0;
      _activity = 'Reading files…';
    });

    final findings = <_Finding>[];
    var checked = 0;

    try {
      await for (final entity in folder.list(recursive: true, followLinks: false)) {
        if (!mounted) return;
        if (entity is! File) continue;
        checked++;
        if (checked > 8000) break;
        if (checked % 250 == 0) {
          setState(() => _activity = 'Checking… $checked files');
        }

        final name = entity.path.split(Platform.pathSeparator).last;
        final lower = name.toLowerCase();

        if (name.contains('\u202E') ||
            name.contains('\u202D') ||
            name.contains('\u2066') ||
            name.contains('\u2069')) {
          findings.add(_Finding(
            _Severity.high,
            entity.path,
            'The filename contains a bidirectional control character, which is '
                'used to make a program look like a different kind of file.',
          ));
        }

        const documents = <String>[
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'jpg', 'jpeg',
          'png', 'gif', 'txt', 'zip', 'rar', 'mp3', 'mp4',
        ];
        const executables = <String>[
          'exe', 'scr', 'bat', 'cmd', 'com', 'pif', 'vbs', 'vbe', 'js', 'jse',
          'ps1', 'hta', 'msi', 'jar', 'wsf', 'lnk',
        ];
        final parts = lower.split('.');
        if (parts.length > 2) {
          final last = parts.last;
          final previous = parts[parts.length - 2];
          if (executables.contains(last) && documents.contains(previous)) {
            findings.add(_Finding(
              _Severity.high,
              entity.path,
              'Double extension: this is a program disguised as a '
                  '".$previous" document.',
            ));
          }
        }

        final isExecutable = executables.contains(parts.last);
        if (isExecutable) {
          final fullLower = entity.path.toLowerCase();
          final inRiskyFolder = <String>[
            'temp', 'tmp', 'downloads', 'download', 'public', 'shared',
          ].any((String marker) => fullLower.contains(marker));

          if (inRiskyFolder) {
            findings.add(_Finding(
              _Severity.medium,
              entity.path,
              'An executable sits in a download or temporary folder, where '
                  'unexpected programs usually arrive.',
            ));
          }
          if (name.startsWith('.')) {
            findings.add(_Finding(
              _Severity.high,
              entity.path,
              'A hidden executable. There is rarely a legitimate reason for '
                  'one to be hidden.',
            ));
          }
        }

        // Script contents. Bounded so a huge file cannot stall the check.
        if (isExecutable && entity.statSync().size <= 512 * 1024) {
          final extension = parts.last;
          if (<String>['ps1', 'js', 'vbs', 'hta', 'wsf', 'bat', 'cmd']
              .contains(extension)) {
            String text;
            try {
              text = await entity.readAsString();
            } catch (_) {
              // Unreadable or not text. Nothing to judge.
              text = '';
            }
            final lowerText = text.toLowerCase();
            final markers = <String, String>{
              'encodedcommand': 'runs a base64-encoded payload',
              'downloadstring': 'downloads code from the internet',
              'invoke-expression': 'executes text as code',
              'frombase64string': 'decodes an embedded payload',
              'wscript.shell': 'launches other programs silently',
              'net.webclient': 'downloads from the internet',
              'hidden': 'asks to run without a window',
            };
            final hits = markers.entries
                .where((MapEntry<String, String> e) =>
                    lowerText.contains(e.key))
                .map((MapEntry<String, String> e) => e.value)
                .toSet()
                .toList();
            if (hits.length >= 2) {
              findings.add(_Finding(
                _Severity.high,
                entity.path,
                'This script ${hits.join(', ')}. That combination is typical '
                    'of a dropper and rare in ordinary work scripts.',
              ));
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _running = false;
        _checked = true;
        _activity = '';
        _filesChecked = checked;
        _findings = findings;
        _summary = findings.isEmpty
            ? 'No patterns matched in $checked files. This is a good sign, not '
                'a guarantee: a novel program can pass a pattern check.'
            : '${findings.length} item${findings.length == 1 ? "" : "s"} need '
                'a look, in $checked files.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _activity = '';
        _checked = true;
        _summary = 'The check stopped early: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolShell(
      title: 'Antivirus & scan',
      howTo: 'Choose a folder, then use your system antivirus for a real scan, '
          'or run a quick pattern check. The system scan uses Microsoft '
          'Defender on Windows and ClamAV on Linux. The quick check looks for '
          'disguised programs, hidden executables and known dropper patterns. '
          'It does not use virus signatures, so a clean result is a good sign '
          'rather than a guarantee.',
      children: <Widget>[
        ToolSection(
          title: 'Folder to check',
          icon: Icons.folder_outlined,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _path,
                    decoration: const InputDecoration(
                      labelText: 'Folder path',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Browse',
                  onPressed: _running ? null : _pick,
                  icon: const Icon(Icons.folder_open_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _running ? null : _runQuickCheck,
                  icon: const Icon(Icons.search),
                  label: const Text('Quick check'),
                ),
                OutlinedButton.icon(
                  onPressed: _running ? null : _runSystemScan,
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Scan with your system antivirus'),
                ),
              ],
            ),
            if (!isDesktopPlatform)
              const ToolNote(
                'File scanning needs a desktop build. On this platform the '
                'folder picker and file access are unavailable.',
                warning: true,
              )
            else
              const ToolNote(
                'The system scan uses whatever is already installed on this '
                'machine, so the engine and the way it reports results are '
                'theirs, not this app’s.',
              ),
          ],
        ),
        if (_running)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_activity),
              ],
            ),
          ),
        if (_checked && _summary != null)
          ToolSection(
            title: 'What was found',
            icon: Icons.fact_check_outlined,
            children: <Widget>[
              SelectableText(_summary!),
              if (_filesChecked > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Files read: $_filesChecked',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              if (_findings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                for (final finding in _findings)
                  _FindingTile(finding: finding),
              ],
            ],
          ),
        if (_findings.isEmpty && !_running)
          const ToolNote(
            'A file only appears here when a specific reason matched. Nothing '
            'is listed merely for being unusual.',
          ),
      ],
    );
  }
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding});

  final _Finding finding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color colour, String label) = switch (finding.severity) {
      _Severity.high => (
          Icons.dangerous_outlined,
          theme.colorScheme.error,
          'High',
        ),
      _Severity.medium => (
          Icons.warning_amber_rounded,
          Colors.orange.shade700,
          'Medium',
        ),
      _Severity.note => (
          Icons.info_outline,
          theme.colorScheme.primary,
          'Note',
        ),
    };

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colour),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$label · ${finding.reason}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    finding.path,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
