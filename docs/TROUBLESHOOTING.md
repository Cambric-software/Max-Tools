# Troubleshooting

## `flutter pub get` fails with dependency conflict

Run `flutter pub outdated` to see what is conflicting. The template pins dependencies to known-working versions. If you need a newer version of a specific package, update `pubspec.yaml` and re-run `flutter pub get`.

---

## `flutter analyze` reports issues after pulling updates

Run a clean analysis:
```bash
flutter clean
flutter pub get
flutter analyze
```

---

## Linux build fails on Windows host

Linux builds require a Linux toolchain (GCC, CMake, GTK headers). On Windows, use GitHub Actions (`ubuntu-latest`) — the `ci.yml` and `release.yml` workflows build Linux automatically.

---

## Android build fails: licenses not accepted

```bash
flutter doctor --android-licenses
```

Accept all licenses, then retry the build.

---

## Version drift between pubspec, config and manifest

**Symptom:** `flutter test` fails in
`test/core/version_consistency_test.dart`, e.g. `expected: <0.1.0> actual:
<1.0.0>`.

**Cause:** the three version sources disagree. This matters more than it
looks: the update system compares `cambric_config.json`'s version against the
published git tag, so a config claiming a *higher* version than the tag makes
the app conclude it is already up to date and silently stop offering updates.

**Fix:** bump all three together:
1. `version:` in `app/pubspec.yaml`
2. `product.version` in `app/lib/core/config/cambric_config.json`
3. `version` in `app/cambric.manifest.json`

The test fails loudly so this cannot ship again.

---

## Update check says "no release repository is configured"

**Symptom:** the Updates screen shows that message and downloads nothing.

**Cause:** either `release.repository` is empty in
`cambric_config.json`, or `updates.enabled` is false. Both are required —
a half-configured build deliberately phones home to nothing.

**Fix:** confirm `release.repository` is `Cambric-software/Max-Tools` and that
the update flag is on. See [UPDATES.md](UPDATES.md).

---

## `CambricConfig.load` returns default values unexpectedly

**Cause:** The config file path is wrong. `CambricConfig.load` silently returns defaults when the file is missing (by design — the app must always start).

**Fix:** Verify the path matches where the JSON lives. The default path used in `main.dart` is `'lib/core/config/cambric_config.json'`.

---

## AtomicFileService leaves `.tmp` files behind

This only happens when the process is killed during a write. The `.tmp` files are safe to delete manually — they are intermediate write buffers, not the real data.

---

## Update check returns stale data

The `ReleaseService` caches release metadata locally. To force a fresh check, clear the cache:
```dart
await CacheCleanupService().clearAll();
```

---

## Ecosystem discovery returns empty list

`CambricEcosystemService.discover()` scans the local registry. If no other Cambric products are installed on the same device, the list will be empty — this is correct behaviour, not a bug.

---

## Tests time out on Windows

Widget tests that load Google Fonts or complex themes can hang on Windows due to font resolution. Keep widget tests simple (avoid `ThemeData` with external fonts in tests). Pure Dart tests run reliably with `flutter test`.
