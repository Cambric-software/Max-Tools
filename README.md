# Max Tools

[![CI](https://github.com/Cambric-software/Max-Tools/actions/workflows/ci.yml/badge.svg)](https://github.com/Cambric-software/Max-Tools/actions/workflows/ci.yml)

**All-in-one toolkit for developers, animators, freelancers and business users.**

Built on the Cambric app-template foundation. Runs on **Windows**, **Linux**, and
**Android**. Offline-capable and local-first.

> **Proprietary.** Copyright (c) 2026 Cambric Software. All rights reserved.
> Not open source. See [LICENSE](LICENSE).

---

## Table of contents

- [What this is](#what-this-is)
- [The four pillars](#the-four-pillars)
- [Quick start](#quick-start)
- [Project layout](#project-layout)
- [The service library](#the-service-library)
- [Architecture](#architecture)
- [Verification](#verification)
- [Building](#building)
- [Releases](#releases)
- [Configuration](#configuration)
- [Roadmap](#roadmap)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## What this is

Max Tools is Cambric's internal all-in-one utility suite: one application
that replaces a pile of single-purpose tools with a single, searchable,
keyboard-driven surface.

Instead of fifteen separate utilities, fifteen installers, and fifteen UIs to
learn, Max Tools gives you:

- a **tool registry** that exposes every capability as a named, parameterised
  tool;
- a **command palette** where you type what you want in plain English and the
  app works out which tool you meant — and corrects you when it is unsure;
- a **variable system** so results flow between tools without retyping;
- one consistent, fast, keyboard-first **UI** over all of it.

It is deliberately **local-first**: no account, no cloud dependency, no
telemetry. Your data stays on your machine.

---

## The four pillars

### 1. Developer tools

Format conversion, encoding, hashing, checksums, diffs, JSON/CSV/XML/YAML
handling, regex, text transforms, file inspection, archive handling, HTTP
utilities, log analysis, and code formatting helpers.

### 2. Animator tools

Frame-rate and timecode conversion, frame-count calculations, shot-duration
maths, render-time and asset-size estimation, resolution and aspect-ratio
conversion, colour-space and bit-depth helpers, delivery-spec calculators.

### 3. Freelancer tools

Quote and estimate builders, invoice generation, milestone and retainer
billing, hourly/day/fixed-rate conversion, time tracking maths, payment
terms and late-payment calculators, client communication templates.

### 4. Business tools

Project profitability, cost versus revenue analysis, tax and set-aside
calculations, budget burn-rate, cash-flow projection for a project,
multi-currency conversion, break-even analysis.

---

## Quick start

```powershell
# Clone
git clone https://github.com/Cambric-software/Max-Tools.git
cd Max-Tools

# Verify the toolchain matches what this project expects
.\scripts-doctor.ps1

# Install dependencies and run the checks
cd app
flutter pub get
flutter analyze        # must report: No issues found!
flutter test           # must report: All tests passed!
```

### Running it

```powershell
cd app

# On the host platform
flutter run -d windows
flutter run -d linux

# Android (device or emulator attached)
flutter run -d android

# Release builds
flutter build windows --release
flutter build linux   --release
flutter build apk     --release
```

---

## Project layout

```
Max-Tools/
├── LICENSE                  # Proprietary — Cambric Software
├── README.md                # This file
├── SECURITY.md              # Security policy and reporting
├── SETUP.md                 # First-time developer setup
├── cambric.manifest.json    # Product manifest (name, id, platforms, capabilities)
├── cambric.lock             # Toolchain lock (Flutter/Dart versions)
├── scripts-doctor.ps1       # Environment + drift checker
├── docs/                    # Architecture, development, testing, storage, updates
├── scripts/                 # Generation and changelog tooling
├── assets/branding/         # Brand assets
└── app/                     # The Flutter application
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart                 # Entry point: config, lifecycle, registry
    │   ├── cambric_app_shell.dart    # App chrome shared by every screen
    │   ├── core/                     # Platform core (see below)
    │   │   ├── cache/                # Cache, entries, cleanup
    │   │   ├── config/                # Product configuration
    │   │   ├── diagnostics/           # Health, reports, error counters
    │   │   ├── ecosystem/             # Local product registry / discovery
    │   │   ├── lifecycle/             # App + environment lifecycle, feature flags
    │   │   ├── network/               # Connectivity
    │   │   ├── platform/              # Desktop integration, installers
    │   │   ├── security/              # Access control, sanitisation, redaction
    │   │   ├── storage/               # Atomic writes, paths, backup, restore, migration
    │   │   └── updates/               # Release discovery, updates, rollback, verification
    │   ├── models/                   # Shared data models
    │   ├── screens/                  # UI screens
    │   ├── services/library/         # The tool library (see next section)
    │   ├── theme/                    # Light and dark themes
    │   ├── tools/                    # Tool registry and descriptors
    │   └── widgets/                  # Shared widgets
    ├── test/                         # Test suite
    ├── android/  linux/  windows/    # Platform runners
    └── tools/                         # Install scripts
```

---

## The service library

`app/lib/services/library/` is the capability inventory that Max Tools is
built on. Every entry is a self-contained, dependency-light service.

| Group | What it provides |
|---|---|
| **app** | Event bus, form state, localisation, navigation, observer, scheduler, theme, timer |
| **core** | App state, audit log, configuration, crash reports, error handling, feature flags, health checks, integrity, logging, migrations, retry, timeout, validation, versions |
| **data** | CSV, JSON, XML, database, local storage, preferences, repositories, secure storage, serialisation |
| **files** | Archives, backups, checksums, directories, downloads, exports, imports, queues, paths, caches, temp files, transfers |
| **network** | API client, connectivity, filters, HTTP, pagination, rate limiting, request queues, search, sorting |
| **security** | Access control, encryption, hashing, input sanitisation, locks, permissions, redaction, policies, sessions, tokens |
| **system** | Clipboard, deep links, desktop integration, device info, notifications, platform, processes, system info, URI |
| **testing** | Installers, plugins, releases, test utilities, update check/install/rollback/verify |

These services are **the tool inventory**: the tool registry exposes them as
named, parameterised tools, and the command palette drives them.

---

## Architecture

Max Tools is layered so that every layer is replaceable:

```
UI (screens, widgets, command palette)
        │
        ▼
Tool layer (tool registry, descriptors, variable system)
        │
        ▼
Service library (core, data, files, network, security, system, testing)
        │
        ▼
Platform core (storage, cache, config, updates, security, lifecycle)
        │
        ▼
OS (Windows / Linux / Android)
```

Principles:

- **Local-first.** No required network calls. Everything works offline.
- **Atomic writes.** State is written to a temp file and replaced, so a crash
  mid-write cannot corrupt data.
- **Versioned backup and restore.** Destructive operations snapshot first.
- **Never silently swallow errors.** Services return explicit failures.
- **Backups before changes, rollback after failures.**
- **No global mutable state.** Services are instantiated and passed, which
  keeps them testable.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full write-up.

---

## Verification

Every change must keep both gates green:

```powershell
cd app
flutter analyze     # static analysis — must be "No issues found!"
flutter test        # unit + widget + integration tests — must all pass
```

CI runs the same checks plus security scanning on every push. See
[docs/TESTING.md](docs/TESTING.md).

---

## Building

| Target | Command | Output |
|---|---|---|
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/` |
| Linux | `flutter build linux --release` | `build/linux/x64/release/bundle/` |
| Android | `flutter build apk --release` | `build/app/outputs/flutter-apk/` |

Installers are in `app/tools/`:

```powershell
# Windows
.\app\tools\install_windows.ps1

# Linux
./app/tools/install_linux.sh
```

---

## Releases

GitHub Actions workflows in `.github/workflows/`:

| Workflow | Purpose |
|---|---|
| `ci.yml` | Analyze, test, lint on every push and PR |
| `build.yml` | Matrix builds for Windows, Linux, Android |
| `release.yml` | Tagged release builds and artifacts |
| `security.yml` | Dependency and secret scanning |
| `test.yml` | Test-only run |
| `analyze.yml` | Static analysis only |

Release notes are generated with `scripts/cambric-changelog.ps1`. See
[docs/RELEASES.md](docs/RELEASES.md).

---

## Configuration

Product configuration lives in `app/lib/core/config/cambric_config.json`:
product identity, version, cache limits, update policy, ecosystem protocol,
localisation, feature flags, branding, security posture, and diagnostics.

The product manifest (`cambric.manifest.json`) declares identity, supported
platforms, capabilities, and locales. Max Tools advertises:

```json
"platforms": ["android", "windows", "linux"],
"capabilities": ["offline", "updates", "ecosystem", "localization"]
```

Feature flags start conservative and are enabled deliberately:

```json
"featureFlags": {
  "showDeveloperTools": false,
  "enableExperimentalCache": false
}
```

---

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 0 | Rebrand to Max Tools, proprietary licence, dead-code cleanup | Complete |
| 1 | Tool registry exposing the service library as callable tools | Next |
| 2 | Command palette: English sentences + correction system | Planned |
| 3 | Variable system: typed variables, interpolation, chaining | Planned |
| 4 | Animator tools | Planned |
| 5 | Freelancer and business/money tools | Planned |
| 6 | Tool browser UI, categories, search, favourites | Planned |
| 7 | Download website (Windows / Linux / Android) | Planned |
| 8 | Remaining duplicate-service consolidation | Planned |

---

## Troubleshooting

**`flutter analyze` fails after a dependency change**
Run `flutter pub get`, then `flutter pub outdated`. The project pins
versions in `pubspec.lock`.

**`flutter test` cannot delete a build directory**
A cloud-sync folder (OneDrive, Dropbox) can lock files briefly. Close any
running build, then delete `app/build/` and re-run. This is a filesystem lock,
not a code fault.

**Toolchain version mismatch**
Run `.\scripts-doctor.ps1` from the repository root. It reports the expected
and actual Flutter/Dart versions and flags drift against `cambric.lock`.

**App shows the first-run wizard**
That is expected on a fresh install. The wizard is part of the template
bootstrap.

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more.

---

## Contributing

1. Branch from `main`.
2. Make the change.
3. `flutter analyze` — no issues.
4. `flutter test` — all passing.
5. Add tests for new behaviour.
6. Open a pull request.

Conventions: Dart doc comments on public API, null safety, no new
dependencies without discussion, and nothing that requires a network call at
runtime.

Security issues: see [SECURITY.md](SECURITY.md). Do not open a public issue
for a vulnerability.

---

## License

Proprietary. Copyright (c) 2026 Cambric Software. All rights reserved.

This software is **not** open source and carries no open-source licence
grant. No permission is granted to copy, modify, publish, sublicense,
redistribute, or create derivative works. Client deliveries are covered by a
separate written engagement agreement. See [LICENSE](LICENSE).
