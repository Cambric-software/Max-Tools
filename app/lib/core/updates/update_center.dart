/// Orchestrates the update stack for the running app.
///
/// The template already ships release discovery, download, checksum
/// verification and rollback. This wires them together behind one surface the
/// UI and the startup path can call, and adds the two things that were missing:
/// a real version comparison, and the rule that an update is never presented
/// unless it is genuinely newer.
///
/// Every collaborator is injectable so the whole flow can be tested without a
/// network, which matters more here than anywhere else — an update path that
/// only works when GitHub is reachable is not a path you can trust.
library;

import 'dart:io';

import '../config/cambric_config.dart';
import '../updates/release_service.dart';
import '../updates/update_service.dart';
import '../updates/update_state.dart';
import '../updates/update_verification_service.dart';

/// The outcome of looking for an update.
class UpdateCheck {
  /// Create a check result.
  const UpdateCheck({
    required this.currentVersion,
    required this.state,
    this.latestVersion = '',
    this.notes = '',
    this.assetName = '',
    this.assetSizeBytes = 0,
    this.releaseUrl = '',
    this.error,
  });

  /// Version the app is running.
  final String currentVersion;

  /// Version published upstream, empty when there is none.
  final String latestVersion;

  /// Release notes published upstream.
  final String notes;

  /// Name of the asset chosen for this platform.
  final String assetName;

  /// Size of that asset in bytes.
  final int assetSizeBytes;

  /// Link to the release page.
  final String releaseUrl;

  /// Which state the check ended in.
  final UpdateState state;

  /// Why the check failed, when it did.
  final String? error;

  /// Whether a newer version is available.
  ///
  /// False when up to date, when the check failed, or when the published
  /// version is the same or older. Never guesses.
  bool get isUpdateAvailable =>
      state == UpdateState.available && latestVersion.isNotEmpty;

  /// One-line summary for the UI.
  String get summary {
    if (error != null) return 'Update check failed: $error';
    if (!isUpdateAvailable) return 'You are on the latest version.';
    return 'Version $latestVersion is available (you have $currentVersion).';
  }
}

/// Manages checking for, verifying and rolling back updates.
class UpdateCenter {
  final CambricConfig? _config;
  final UpdateService _updates;
  final UpdateVerificationService _verification;

  /// Create an update centre.
  ///
  /// [config] supplies the repository and the enabled flag. When it is null
  /// updates are disabled, which is the correct default for a build with no
  /// configured repository.
  UpdateCenter({
    CambricConfig? config,
    UpdateService? updates,
    UpdateVerificationService? verification,
  })  : _config = config,
        _updates = updates ?? UpdateService(),
        _verification = verification ?? UpdateVerificationService();

  /// The `owner/repo` releases are read from.
  String get repository => _config?.repository?.trim() ?? '';

  /// Whether update checks may run.
  ///
  /// Requires both an explicit configuration flag and a repository, so a
  /// half-configured build cannot silently phone home.
  bool get isEnabled =>
      (_config?.updatesEnabled ?? false) && repository.isNotEmpty;

  /// The current state of the underlying update flow.
  UpdateState get state => _updates.state;

  /// The release discovered by the last successful check.
  ReleaseMetadata? get available => _updates.available;

  /// Path of the downloaded, verified package, when there is one.
  File? get downloadedPackage => _updates.downloadedPackage;

  /// Look for a newer release.
  ///
  /// Never throws: a failed check is reported as a failed [UpdateCheck].
  Future<UpdateCheck> check({required String currentVersion}) async {
    if (!isEnabled) {
      return UpdateCheck(
        currentVersion: currentVersion,
        state: UpdateState.notAvailable,
        error: repository.isEmpty
            ? 'No release repository is configured.'
            : 'Automatic updates are switched off.',
      );
    }
    ReleaseMetadata? release;
    try {
      release = await _updates.check(repository);
    } catch (error) {
      return UpdateCheck(
        currentVersion: currentVersion,
        state: UpdateState.checkFailed,
        error: '$error',
      );
    }
    if (release == null) {
      return UpdateCheck(
        currentVersion: currentVersion,
        state: UpdateState.notAvailable,
        error: _updates.error ?? 'No published release was found.',
      );
    }

    final newer = compareVersions(release.version, currentVersion) > 0;
    final asset = release.assetForCurrentPlatform();
    if (!newer || asset == null) {
      return UpdateCheck(
        currentVersion: currentVersion,
        state: UpdateState.notAvailable,
        latestVersion: release.version,
      );
    }
    return UpdateCheck(
      currentVersion: currentVersion,
      state: UpdateState.available,
      latestVersion: release.version,
      notes: release.name,
      assetName: asset.name,
      assetSizeBytes: asset.sizeBytes,
      releaseUrl: release.releaseUrl,
    );
  }

  /// Download the discovered release and verify its checksum.
  ///
  /// [expectedSha256] is compared before the package is considered usable.
  /// Returns the verified file, or null with the reason in [lastError].
  Future<File?> downloadAndVerify({
    void Function(int received, int total)? onProgress,
    String? expectedSha256,
  }) async {
    if (_updates.state != UpdateState.available) {
      _lastError = 'No update has been offered yet.';
      return null;
    }
    File? file;
    try {
      file = await _updates.download(onProgress: onProgress);
    } catch (error) {
      _lastError = 'Download failed: $error';
      return null;
    }
    if (file == null) {
      _lastError = _updates.error ?? 'Download failed.';
      return null;
    }
    final result = await _verification.verify(file, expectedSha256: expectedSha256);
    if (!result.passed) {
      _lastError = result.reason ?? 'The download did not pass verification.';
      // A package that fails verification is worse than no package at all.
      try {
        await file.delete();
      } catch (_) {
        // Nothing useful to do if cleanup fails.
      }
      return null;
    }
    _lastError = null;
    return file;
  }

  /// Why the last download failed, when it did.
  String? get lastError => _lastError;
  String? _lastError;

  /// Checks once on startup without blocking the UI.
  ///
  /// Returns null if updates are disabled or the check fails; callers that
  /// want to surface the problem should use [check] directly.
  static Future<UpdateCheck?> checkInBackground({
    required CambricConfig config,
    required String currentVersion,
  }) async {
    final centre = UpdateCenter(config: config);
    if (!centre.isEnabled) return null;
    try {
      return await centre.check(currentVersion: currentVersion);
    } catch (_) {
      return null;
    }
  }

  /// Where a human should be sent to install manually.
  static String installHelp(String platform) => switch (platform) {
        'windows' =>
          'Close Max Tools, replace the contents of the install folder with '
              'the new release, then run max_tools.exe again.',
        'linux' =>
          'Close Max Tools, replace the bundle folder with the new release, '
              'then run the max_tools binary again.',
        'android' =>
          'Install the downloaded APK over the existing app. Android will ask '
              'you to allow installs from this source.',
        _ =>
          'Download the release and replace the current installation.',
      };

  /// Compare two dotted version strings.
  ///
  /// Returns a positive number when [a] is newer than [b]. Prefixes such as
  /// `v` are ignored, numeric segments are compared as numbers (so 0.10 is
  /// newer than 0.9), and a non-numeric segment sorts before a numeric one so
  /// a pre-release never outranks a stable release of the same number.
  static int compareVersions(String a, String b) {
    final left = _segments(a);
    final right = _segments(b);
    final length =
        left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : null;
      final r = i < right.length ? right[i] : null;
      if (l == null) {
        // b has more segments: 1.2 is older than 1.2.1
        return r == _preRelease ? 1 : -1;
      }
      if (r == null) {
        return l == _preRelease ? -1 : 1;
      }
      if (l == r) continue;
      final leftNumber = int.tryParse(l);
      final rightNumber = int.tryParse(r);
      if (leftNumber != null && rightNumber != null) {
        return leftNumber.compareTo(rightNumber);
      }
      if (leftNumber != null) return 1;
      if (rightNumber != null) return -1;
      // Two non-numeric segments: the documented pre-release marker sorts first.
      if (l == _preRelease) return -1;
      if (r == _preRelease) return 1;
      return l.compareTo(r);
    }
    return 0;
  }

  static const String _preRelease = 'pre';

  static List<String> _segments(String version) => version
      .trim()
      .replaceFirst(RegExp('^[vV]'), '')
      .split(RegExp(r'[.\-+_]'))
      .where((segment) => segment.isNotEmpty)
      .toList();
}

/// Convenience: the platform key used for release asset selection.
String currentPlatformKey() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  if (Platform.isAndroid) return 'android';
  return Platform.operatingSystem;
}
