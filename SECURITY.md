# Security Policy

Security model, guarantees and reporting process for **Max Tools**.

---

## Security model

Max Tools is **local-first**. Everything it does runs on the user's machine:

- No account, sign-in or remote authentication
- No telemetry, analytics or usage tracking
- No mandatory cloud backend
- No network calls except the optional update check (off by default, see below)
- User data stays on the device unless the user explicitly shares it

The app reads and writes only inside the platform's application-support
directory, resolved by `CambricPaths`.

---

## What ships as secure by default

These are real services in `app/lib/core/`, each with its own test suite.

### Atomic writes

`AtomicFileService` — every persistent write is write-to-temp then rename:

- A file is committed only after the write fully succeeds
- A crash mid-write cannot leave a truncated or corrupt file behind
- Used by the variable store, settings and other persisted state

### Input sanitization

`InputSanitizationService` — for anything that reaches storage, a filename or
the filesystem:

- `sanitizeFilename` — strips path traversal characters
- `toSafeIdentifier` — normalises to a safe alphanumeric identifier
- `escapeHtml` — escapes HTML metacharacters
- `validateRequired`, `validateEmail`, `validateUrl`, `validateMinLength`
- `looksLikeSecret` — flags accidental secret values in input

### Secret redaction

`SecretRedactionService` — redacts before anything is logged or exported.
Detects private keys, API keys, bearer tokens, GitHub tokens (`ghp_…`) and AWS
access key IDs (`AKIA…`).

- `redact(string)`
- `redactMap(map)`

### Hashing and integrity

`SecurityService`:

- `sha256String`, `sha256Bytes`, `sha256File`
- `constantTimeEquals` — timing-safe comparison, so a checksum check cannot be
  defeated by timing the response
- `generateIntegrityTag` / `verifyIntegrityTag` — HMAC-SHA256
- `verifyFileChecksum` — verify a file against an expected SHA-256

### Access control

`AccessControlService` — capability gating for bundled subsystems. Note this is
**software-level**, not an OS sandbox: it stops a mis-wired feature, not a
determined attacker.

---

## Update integrity

Updates are the one path that reaches the network, so it is the strictest.

- **Opt-in and gated.** Update checks run only when a release repository is
  configured *and* the config flag is on. A half-configured build cannot phone
  home.
- **Never self-replacing.** Max Tools does not overwrite its own files while
  running. It downloads, verifies, and tells you exactly how to install.
- **Verified before use.** `UpdateVerificationService` checks existence,
  non-emptiness and the SHA-256 checksum. A package that fails verification is
  **deleted**, not offered.
- **Version comparison cannot be fooled.** Segments compare numerically, so
  `0.10.0` correctly beats `0.9.0`, and a pre-release never outranks a stable
  release of the same number.

Every published artifact ships a companion `.sha256` file:

```
windows.zip.sha256
linux.tar.gz.sha256
android.apk.sha256
```

Verify before installing:

```powershell
Get-FileHash .\windows.zip -Algorithm SHA256
# compare against windows.zip.sha256
```

---

## CI security gates

The `Security` workflow runs on every push and pull request, plus weekly:

| Check | Fails the build? |
|---|---|
| `dart pub audit` | No — informational advisories are surfaced, not fatal |
| Hardcoded-secret grep over `lib/` (excluding tests) | **Yes** |
| `.env` files committed to the repo | **Yes** |

`dart pub audit` is intentionally `continue-on-error`: upstream packages carry
informational advisories that do not affect a local-first desktop app. Review
its output rather than ignoring it.

The `Analyze` and `Test` workflows additionally gate every push, so a change
that breaks static analysis or the 353-test suite cannot merge.

---

## What Max Tools deliberately does NOT do

- It does **not** implement OS keychain or secure-enclave storage (would need
  platform plugins)
- It does **not** implement OAuth or any remote authentication flow
- It does **not** send diagnostic data to any server
- It does **not** execute code supplied by a downloaded file; tools are Dart
  functions in the shipped binary

Be clear about the first one: secrets are not stored in the OS keychain, so do
not treat the app's storage as a place for long-lived credentials.

---

## Reporting a vulnerability

**Do not open a public GitHub issue for a security vulnerability.**

Report it privately through GitHub's security advisory form for this
repository:

> <https://github.com/Cambric-software/Max-Tools/security/advisories/new>

Please include:

1. A description of the vulnerability and its potential impact
2. Steps to reproduce, or a proof of concept
3. The affected version(s)
4. Your platform (Windows / Linux / Android)

You should expect an acknowledgement within **48 hours**, and a target fix
within **14 days** for critical issues.

**Security contact:** `security@cambric.dev`

If that address is not monitored, use the GitHub advisory form above — it
reaches the maintainers without needing a working email round-trip.