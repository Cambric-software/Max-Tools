# Releases

How to create and publish a Cambric application release.

---

## Version tags

Releases are triggered by pushing a Git tag:

```powershell
git tag v1.4.3
git push origin v1.4.3
```

The tag format must match `v*` (e.g. `v1.0.0`, `v1.4.3`).

---

## What the release workflow does

1. Builds Windows, Linux, and Android in parallel
2. Runs `flutter analyze` and `flutter test` on each platform
3. Packages artifacts:
   - `windows.zip` — Windows release bundle
   - `linux.tar.gz` — Linux release bundle
   - `android.apk` — Android APK
4. Generates SHA-256 checksums for each artifact
5. Creates a GitHub Release with all artifacts and checksums attached

---

## Artifact naming

Artifacts are published as:

```
windows.zip
windows.zip.sha256
linux.tar.gz
linux.tar.gz.sha256
android.apk
android.apk.sha256
```

The update system reads these names to select the correct platform asset.

---

## Release metadata

`ReleaseService` fetches from:

```
https://api.github.com/repos/<owner>/<repo>/releases/latest
```

Configure your repository in `cambric_config.json`:

```json
{
  "release": {
    "provider": "github",
    "repository": "owner/repo",
    "apiBase": "https://api.github.com"
  }
}
```

---

## Checklist before releasing

- [ ] Version updated in `cambric_config.json`, `pubspec.yaml` **and**
      `app/cambric.manifest.json` (all three must match)
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] No secrets in source code (`security.yml` gates this)
- [ ] Documentation updated
- [ ] Git tag created and pushed

The `Build` workflow already compiles the Windows installer and packages the
`.deb` on every push, so a broken installer fails long before a tag is cut.
The release then publishes:

| Asset | What it is |
|---|---|
| `MaxTools-Setup-<version>.exe` | Windows installer, per-user |
| `MaxTools-Setup.exe` | Stable alias of the same file, for the download page |
| `windows.zip` | Portable Windows build |
| `max-tools_<version>.deb` | Linux package, versioned layout |
| `max-tools.deb` | Stable alias of the same package |
| `linux.tar.gz` | Portable Linux build |
| `android.apk` | Android build |

The asset list is assembled from what each job actually produced, with
`fail_on_unmatched_files`, so a failed platform cannot leave a dead download
button.
