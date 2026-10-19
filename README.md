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

Max Tools currently ships **106 tools**: 52 developer-side tools and 54 for
animators, freelancers and business work.

### 1. Developer tools (52)

| Area | Tools |
|---|---|
| Data | CSV parse/encode, JSON format/inspect, XML extract/escape |
| Text | base64, URL encode/decode, case and identifier conversion, slug, pad, word count, dedupe, sort, filter, replace, regex match/replace/test, markdown→CSV, line diff, indent, join, split, character codes, CSV escaping |
| Files | path join/basename/dirname/extension, exists, metadata, list, human size, checksum, verify checksum, create folder |
| Security | hash (SHA-256/MD5/HMAC), verify text hash, obfuscate/deobfuscate, key generation |
| Network | URL validate, query parameters, add parameters |

### 2. Animator tools (16)

Frames↔duration, timecode↔frames with correct drop-frame handling for 29.97
and 59.94, frame-rate comparison, render-time estimation with machine scaling,
video size from bitrate, bitrate for a target file size, resolution facts and
aspect-ratio simplification, slow-motion frame maths, audio sample-to-frame
alignment, frames per second, delivery-spec checking, frame step/stride, stops
to exposure, and a reference list of standard rates.

### 3. Freelancer tools (17)

Hourly-to-project pricing with markup, day-rate to hourly, quotes with tax,
invoice totals net of deposits, milestone plans, effective hourly rate,
billable split and utilisation, retainer consumption and overage, late-payment
interest, deposit-to-start, "can I take this job?", payment terms and ageing,
rate cards, capacity, utilisation gap, minimum viable project price and quote
splitting.

### 4. Business tools (21)

Project profit including labour, markup↔margin, price from target margin, tax
set-aside, break-even units, budget burn rate, cash-flow projection, currency
conversion, cost per client, scope-change pricing, three-tier pricing, margin
after tax, revenue target, monthly run rate, payback period, ROI, profit
scenarios, discount impact, expense ratio, cost escalation and withholding.

Every money tool states its assumptions rather than hiding them: tax applies
after discount, margin is measured on the selling price while markup is on
cost, and a loss never accrues tax.

---

## The command palette

Press **Ctrl+K** (Cmd+K on macOS) anywhere, or use the bolt button on the home
screen. Type what you want in plain English:

```
hash my password
parse csv useHeaders yes
convert 2gb
list files in C:/data
project profit revenue 5000 costs 1000
```

It shows exactly what it understood: the chosen tool, the word that matched,
a confidence percentage, and any arguments it filled in. When a required
argument is missing it asks for it instead of failing.

**Correction.** Typos are recovered rather than rejected: transposed letters
("teh" → "the"), missing letters ("checsum" → "checksum") and doubled letters
all resolve to the right tool, with a "did you mean" note. Correction is
deliberately conservative — paths, URLs and filenames are never rewritten, and
an ambiguous sentence offers options instead of guessing.

## Variables

Chain tools together. Run one, save the result as a typed variable, and refer
to it in the next command:

```
hash abc            → save as $result
base64 encode $result
```

`$name` and `${name}` both work, numbers stay numbers, `\$` escapes a literal
dollar, and an unknown name produces a clear error rather than an empty
string. Variables persist between sessions.

---

## Quick start

```powershell
# Clone
git clone https://github.com/Cambric-software/Max-Tools.git
cd Max-Tools

# Install dependencies and run the checks
cd app
flutter pub get
flutter analyze        # must report: No issues found!
flutter test           # must report: All tests passed!
```

Requires Flutter 3.47+ / Dart 3.13+. Every push runs the same two checks in CI,
so a local failure is never a surprise on the server.

### Installing

**Recommended: use the installer.** It installs per-user (no admin rights),
adds a desktop and Start Menu shortcut, provides an uninstaller, and lays the
app out so it can update itself later:

```
%LOCALAPPDATA%\Programs\MaxTools\
  current.txt              the active version
  versions\0.1.0\          a complete, independent copy
```

- **Windows** — `MaxTools-Setup-<version>.exe` (Inno Setup)
- **Linux** — `max-tools_<version>.deb` (installs under `/usr/lib/max-tools`)
- **Android** — the `.apk` installs in one tap

**Portable copies still work.** `windows.zip` and `linux.tar.gz` run fine from
anywhere, but a portable copy has no versioned layout, so it cannot update
itself. Max Tools detects this, refuses to self-update rather than risking a
broken install, and tells you to reinstall.

### How updates apply

An update never overwrites files that are running. It unpacks the new version
into its own folder and moves a pointer; the new version starts on your next
launch. If anything goes wrong the previous version is untouched and still on
disk, and one button puts it back.

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
├── cambric.manifest.json    # Product manifest (name, id, platforms, capabilities)
├── cambric-icon-transparent.png  # Official Cambric mark
├── docs/                    # Architecture, development, testing, storage, updates
├── assets/branding/         # Brand assets (Cambric logo source)
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

Release notes are generated automatically by GitHub from the commit history
(`generate_release_notes`). See [docs/RELEASES.md](docs/RELEASES.md).

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

The authoritative, ordered plan for this product and its sibling **Digital
Saver** lives in [docs/ROADMAP.md](docs/ROADMAP.md). Work it top to bottom.

**Still open before a public release**

- Enable GitHub Pages (repository Settings → Pages → Source: GitHub Actions)
  so the download page goes live.
- Tag the first release (`v0.1.0`) to trigger the build-and-publish workflow.
- Duplicate-service consolidation: 9 duplicated pairs remain where both copies
  are referenced. Resolving them needs per-pair review, not a bulk delete.

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md). It covers dependency
changes, locked build directories on cloud-synced drives, toolchain version
mismatches, and a missing release repository.

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
grant. Anyone may install and use it on devices they control for personal,
educational or internal business purposes, free of charge. You may not
redistribute it, modify it, or create derivative works. Client deliveries are
covered by a separate written engagement agreement. See [LICENSE](LICENSE).
