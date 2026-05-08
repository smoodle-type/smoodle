# Stack Research — Phase 1 Finish

**Domain:** Cross-platform desktop IME (Rime/librime-based), dogfood distribution
**Researched:** 2026-05-08
**Overall confidence:** HIGH on telemetry + linting; MEDIUM on Sparkle re-swap (no off-the-shelf recipe — synthesized from launchd primitives)
**Constraint posture:** solo, ~$0 budget, ≤2 weeks remaining work, opt-in default OFF, dogfood circle audience, no commercial commitment yet

---

## Executive recommendation (TL;DR)

| Phase 1 finish item | Pick | Confidence |
|---|---|---|
| Telemetry backend | **Self-hosted umami v3.1.0** (PostgreSQL + Node, ~200 MB RAM) | HIGH |
| Telemetry client | **Hand-rolled `curl -X POST` (Bash) + `Invoke-RestMethod` (PowerShell)** against `/api/send` | HIGH |
| Schema lint | **Layered: yamllint 1.38 (syntax/style) + Python custom validator (Rime-specific algebra/import_preset)** | HIGH |
| YAML schema linter (general) | **Skip JSON Schema for Rime files** — Rime's algebra DSL is regex-shaped, not JSON-Schema-shaped | HIGH |
| macOS E2E CI | **`macos-15` runner + bash harness invoked from existing `tests/test_install_e2e_*` shape** | HIGH |
| Windows E2E CI | **`windows-latest` runner + Pester 5.x** (preinstalled) + winget verification | MEDIUM |
| Universal dylib | **`lipo -create` step inside `smoodle-build.yml` after both arm64 + x86_64 jobs land artifacts** | HIGH |
| Asset SHA256 verify | **Native GitHub Releases asset digests** (released 2025-06) + fallback `.sha256` file pattern | HIGH |
| Sparkle re-swap detect | **`launchd` user `LaunchAgent` with `WatchPaths` on `/Library/Input Methods/Squirrel.app/Contents/Frameworks/`** invoking a hash-compare script | MEDIUM |

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| umami (self-hosted) | **3.1.0** (released 2026-04-16) | Telemetry backend — receives `/api/send` events from installer scripts | Smallest practical privacy-first analytics stack: single Node container + PostgreSQL, ~200 MB RAM (per umami docs and Paul's Blog 2026 setup), cookieless and GDPR-clean by design. v3.x adds Boards / Session Replay but Phase 1 only uses the base `/api/send` event endpoint. Native Docker Compose, runs on the founder's existing infra. |
| yamllint | **1.38.0** (released 2026-01-13) | Catch YAML syntax errors, key duplication, inconsistent indentation in `schema/*.yaml` | The de facto Python YAML linter. Adrienverge maintained, ships a `default` ruleset that already catches the realistic failure modes (duplicate keys, bad indent, inconsistent line endings). Used by every major Python CI we surveyed. Pip-installable, single dep, runs in 200 ms. |
| Custom Python validator | stdlib only | Rime-specific schema rules: algebra regex compiles, weights are non-negative ints, `import_preset` references resolve, `speller.algebra` rule shape is `{xform,erase,derive,abbrev,fuzz}/<pat>/<repl>/`. | No off-the-shelf Rime schema linter exists in the wild (verified via web search and GitHub topic search across rime/, openvanilla/, smoodle-type/ orgs as of 2026-05). JSON Schema is the wrong tool because Rime algebra is a free-form `op/regex/replacement/` DSL inside YAML strings, not a JSON-typed object. Stdlib `re` + PyYAML (already a dev dep candidate) covers it in ~150 lines. Matches the existing test-suite ethos (stdlib-only, see `tests/test_dict.py`). |
| Pester | **5.x** (preinstalled on `windows-latest`) | Windows installer E2E test framework | The PowerShell test framework. Already preinstalled on GHA `windows-latest`. Returns NUnit XML for GitHub Actions checks. Native `Describe / Context / It / Should` DSL. Replaces the regex-against-script-body shape tests in `tests/test_installers.py:245-444` for Windows-only assertions. |
| `lipo` | macOS native (Xcode CLT) | Combine arm64 + x86_64 dylibs into universal binary | Apple's official tool. Single command: `lipo -create arm64.dylib x86_64.dylib -output universal.dylib`. Verifiable with `lipo -info` + `lipo -verify_arch arm64 x86_64`. CI-friendly. |
| `launchd` (`WatchPaths`) | macOS native | Detect Sparkle re-overwriting the patched dylib | Native macOS service supervisor. `~/Library/LaunchAgents/im.smoodle.dylib-watch.plist` with `WatchPaths` array → fires when `/Library/Input Methods/Squirrel.app/Contents/Frameworks/` mutates. Synthesized from launchd primitives — no off-the-shelf "detect Sparkle overwrite" recipe exists, but the launchd `WatchPaths` + `shasum -c` two-script pattern is well-trodden. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PyYAML | **6.0.2+** (system Python via pip) | Parse `schema/*.yaml` in `tests/test_schema_lint.py` | Only place we cave on stdlib-only. Already an implicit dep for dict-build pipeline (`scripts/merge_dict.py` reads YAML body). The custom validator needs real YAML parsing to walk `speller.algebra` lists. |
| `re` (stdlib) | Python 3.10+ | Compile-test each algebra rule's regex | Rime uses `boost::regex` semantics; Python `re` is close enough for syntax-error detection (the failure mode that matters for lint). False-positives on rare boost-extension syntax acceptable — surfaces in dogfood, not in CI. |
| `curl` | system | Telemetry POST from Bash installers | Already a transitive dep (used in `install-librime-fork.sh` line 78 for the dylib download). Single line: `curl -fsS -X POST -H "Content-Type: application/json" -d '{...}' https://umami.<host>/api/send` with `--max-time 5` so a dead endpoint can never block install. |
| `Invoke-RestMethod` | PowerShell 5.1+ | Telemetry POST from PowerShell installers | Native cmdlet. `Invoke-RestMethod -Method POST -Uri ... -Body (ConvertTo-Json $payload) -TimeoutSec 5 -ErrorAction SilentlyContinue` — silent failure is the right default for opt-in telemetry. |
| `shasum -a 256` (macOS) / `Get-FileHash -Algorithm SHA256` (Win) | system | Verify GitHub Releases asset hash before swap | Native, no-dep. Pin a known-good SHA256 inline in `install-librime-fork.{sh,ps1}` next to the version tag. Mirrors the "embed the digest" pattern that GitHub now natively exposes for releases (June 2025 changelog). |
| `gh` CLI | 2.x | Fetch CI artifacts on Windows fallback path (already in use) | Existing dep in `install-librime-fork.ps1`. Phase 1 keeps as-is. |
| Pester `BeforeAll` / `AfterAll` | 5.x | Snapshot + restore `%APPDATA%\Rime\` between Windows E2E runs | Ensures the windows-latest runner does not poison subsequent jobs with stale schema files. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `actions/setup-python@v5` | Provision Python 3.12 in GHA | Pin to Python 3.12 for yamllint + custom validator + existing test suite. Already pinned at 3.10 minimum in code; 3.12 in CI removes any drift surface. |
| `actions/checkout@v4` | Fetch repo + submodules | Only `.github/workflows/install-mac-e2e.yml` and `install-win-e2e.yml` need this; existing `install-linux-e2e.yml` already uses it. |
| `actions/upload-artifact@v4` | Upload installer logs + Pester JUnit XML on failure | Critical for debugging GHA failures — the dockur/windows test bed gives interactive RDP, but GHA `windows-latest` is one-shot. |
| `actions/cache@v4` | Cache the librime fork build between runs | librime release builds are 5-15 min on macOS-15. Caching the `vendor/librime/build/` dir keyed on the fork tag drops re-runs to <30s. |
| GitHub-hosted `macos-15` | Run macOS install E2E | Generally available since 2025-04-10, retired the macos-14 default in 2026 H1. Apple Silicon by default; `macos-15-large` for Intel parity tests if Phase 1 needs them. |
| GitHub-hosted `windows-latest` (Server 2025) | Run Windows install E2E | Generally available since 2025-04-10. PowerShell 5.1 + 7.x both preinstalled. Pester 5.x preinstalled. winget available. |

## Installation

```bash
# Schema lint test deps (Lane D5)
pip install --user yamllint==1.38.0 PyYAML==6.0.2

# Telemetry backend (founder's infra; one-time)
docker compose -f infra/umami/docker-compose.yml up -d
# uses ghcr.io/umami-software/umami:postgresql-3.1.0 + postgres:16-alpine

# Install-side telemetry: zero deps. curl + Invoke-RestMethod are already on every target box.

# Universal dylib build (CI-side, in smoodle-type/librime smoodle-build.yml)
# After arm64-build and x86_64-build jobs:
lipo -create \
  artifacts/arm64/librime.1.dylib \
  artifacts/x86_64/librime.1.dylib \
  -output librime-1.16.0-smoodle.1-macOS-universal.dylib
lipo -verify_arch arm64 x86_64 librime-1.16.0-smoodle.1-macOS-universal.dylib
shasum -a 256 librime-1.16.0-smoodle.1-macOS-universal.dylib > "$_.sha256"
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **umami self-hosted** | **OpenPanel self-hosted** | If Phase 1.5 needs funnels / retention / cohort analysis. OpenPanel ships ClickHouse + PostgreSQL + Redis (4 vCPU / 8 GB RAM minimum per docs) — **3-4× the footprint of umami** for features the dogfood circle does not need. Worth revisiting only when the wedge expands past ~20 users. |
| **umami self-hosted** | **Plausible self-hosted** | If GDPR audit becomes a hard requirement. Plausible's Community Edition is also lightweight, but its event API is more pageview-shaped and less natural for "install completed" / "deploy succeeded" install-script events. umami's `/api/send` event model is closer to what installers emit. |
| **umami self-hosted** | **PostHog self-hosted (open source)** | If/when the LLM plugin (Phase 1.5) needs feature flags, A/B testing, or session replay. Per PostHog's own infra docs: needs PostgreSQL + Redis + ClickHouse + Kafka, **min 4 vCPU / 16 GB RAM / 30 GB storage**. Massive overkill for Phase 1. Reconsider for Phase 2. |
| **umami self-hosted** | **TelemetryDeck** | Strong privacy-anonymization story (k-anonymity-shaped install_id hashing). Hosted SaaS at $$/mo per project. Phase 1 budget says no. Worth a look at Phase 2 for a managed-host alternative. |
| **yamllint + custom validator** | **check-jsonschema 0.37.1** | If Rime schema YAML had a public JSON Schema. It does not (verified). check-jsonschema is the right pick for *.github/workflows/*.yml validation — Phase 1 might add it for the new `install-{mac,win}-e2e.yml` files as a freebie. |
| **yamllint + custom validator** | **yamale** | Yamale's schema DSL is simpler than JSON Schema for YAML-shaped data, but Rime's algebra is still regex-in-strings, which yamale does not introspect. Same blocker as JSON Schema. |
| **Pester 5** for Windows E2E | Custom regex-against-script-body (current state in `tests/test_installers.py`) | Keep regex shape tests for cross-OS structure assertions. Pester 5 owns *Windows-only* behavior: `Get-WinUserLanguageList` registration check, `WeaselDeployer.exe` invocation, file presence under `%APPDATA%\Rime\`. |
| **`lipo` + manual SHA pin** | **GitHub Releases native asset digests + `gh release view --json`** | GitHub now exposes SHA256 digests natively (June 2025 changelog). Use as primary source of truth in install scripts: `gh release view 1.16.0-smoodle.1 --json assets --jq '.assets[].digest'`. Fallback to inline `.sha256` file for offline-reviewable cases. |
| **launchd `WatchPaths`** for Sparkle re-swap | **fswatch / Wazuh FIM / osquery** | All work but need third-party install. Phase 1 budget = $0 + zero extra deps on the user's machine. launchd is built-in. The trade-off: launchd `WatchPaths` doesn't recurse, so the watched path must be the exact dir, not a tree. |
| **launchd `WatchPaths`** for Sparkle re-swap | **Disable Sparkle in Squirrel via `defaults write`** | Cleanest answer ("turn off the auto-updater") but breaks Squirrel's security update path. User now has to manually update Squirrel forever. Explicitly rejected. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Google Analytics / GA4** | Cookies + IP-based fingerprinting + Google contractual data flow. Violates "no PII, install_id_hash only" decision (D2). Wedge audience is privacy-conscious by selection. | umami self-hosted |
| **Sentry / error tracking SaaS** | Default capture grabs stack traces with file paths (PII for someone-with-Thai-Bangkok-folder-name). Phase 1 doesn't need crash telemetry; install scripts have explicit success/failure codes already. Add at Phase 2 if any C++ plugin work lands. | None for Phase 1 — log to install-side stderr, surface manually in dogfood debrief. |
| **Hatchet / dedicated job runner** | Massively over-engineered for a 56-test suite + 3 single-file E2E scripts. Phase 1 is 2 weeks of work, not a platform. | Plain GHA workflows, one per OS lane. |
| **PostHog OSS** for Phase 1 | Min 4 vCPU / 16 GB RAM. Founder's existing infra likely cannot host this without dedicated VPS spend. Audience signal is qualitative ("≥1 unsolicited bug report"); pageview-equivalent-events is enough. | umami |
| **JSON Schema for Rime YAML** | Rime's `speller.algebra` is `op/regex/replacement/` strings inside a YAML list. JSON Schema cannot validate that the regex is well-formed. Adopting JSON Schema gives false confidence — passes lint, fails at runtime in Squirrel's Console.app. | Custom Python validator that compiles each algebra regex via `re.compile`. |
| **WiX MSI / signed installer** for Phase 1 | Per design doc and Lane B doc: signing requires $200 Sectigo cert (1-2 week procurement) and is an explicit pre-public-ship gate. Zip+scripts is documented and approved. | Existing `install-windows.ps1` / `install-librime-fork.ps1` shape. |
| **Sparkle for smoodle's own auto-update** | Phase 1 ships GitHub Releases manual download. Sparkle is the *upstream* problem we're trying to detect, not the right tool for our own update path. | None for Phase 1. |
| **fswatch / third-party FIM** | Adds a brew dep for a single-purpose detector. launchd is already there. | launchd `WatchPaths` |
| **codesign verify** as the primary trust check on the downloaded dylib | The fork-built dylib is **unsigned** (Phase 1 explicitly defers code-signing). `codesign --verify` on an unsigned dylib returns "code object is not signed at all" and provides no signal. | SHA256 pinning to a known-good digest from CI artifact, **then** Mach-O magic check, **then** swap. Code signature verification re-enters the picture at the pre-public-ship gate. |
| **Bash wget** | Inconsistent on macOS (not preinstalled), retry semantics differ from curl. | curl with `-fsSL --retry 3 --max-time 30` |
| **Plausible Cloud** | Drops on the "self-hosted on founder's infra" budget line and the "no third-party data flow" constraint. | umami self-hosted on the existing VPS. |

## Stack Patterns by Variant

**If founder's infra has a Postgres already:**
- Point umami at the existing Postgres database (separate `umami` schema).
- Save the ~200 MB extra Postgres container.
- Otherwise: use `postgres:16-alpine` in the same Compose file (umami's reference setup).

**If telemetry endpoint is unreachable from CI runner (firewall, VPN-only):**
- Set `SMOODLE_TELEMETRY_URL=""` in the GHA env.
- Installers must treat empty `SMOODLE_TELEMETRY_URL` as "telemetry disabled" — never block install.
- Test: `tests/test_installers.py::test_telemetry_opt_in_default_off` already stubbed (line 577); convert to assertion-on-empty-URL behavior.

**If Sparkle re-swap detection LaunchAgent fires too often (false positives):**
- Sparkle re-writes adjacent files in `Frameworks/` during legitimate Squirrel updates. The `WatchPaths` plist would fire then too.
- Mitigation: the LaunchAgent invokes `bash scripts/verify-librime-hash.sh` which only re-swaps if the *hash* drifted, not just the mtime. Idempotent — running on every Frameworks/ change is fine.

**If the GHA macos-15 runner can't write to `/Library/Input Methods/`:**
- It probably can't (SIP). Fall back to `~/Library/Input Methods/` for the E2E test (per-user IM dir) or stub the swap step entirely and assert installer dry-run output instead.
- Document the gap in `tests/test_install_e2e_mac.sh`: "verifies schema-only path; librime swap E2E covered by manual dogfood until SIP relaxation lands."

**If Windows runner can't run `WeaselDeployer.exe` (Session 0, no desktop):**
- Already known per `docs/LANE-B-WINDOWS.md` lines 124-148. GHA `windows-latest` is interactive desktop, so it *should* work — but the install script's existing 60s timeout + manual fallback path covers the failure mode either way.
- Test asserts: schema files land at `%APPDATA%\Rime\`, `Get-WinUserLanguageList` shows Rime, and the installer either auto-deploys (success) or surfaces the manual instruction block (also success — no silent failure).

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| umami 3.1.0 | PostgreSQL 12-17 | umami's reference Compose uses 16-alpine. Stick with it. |
| umami 3.1.0 | Node 18-22 (image bundles its own) | Self-hosted via Docker — Node is hidden. |
| yamllint 1.38 | Python 3.8+ | Repo's existing minimum is 3.10. Comfortable. |
| check-jsonschema 0.37.1 | Python 3.9+ | Only used for `.github/workflows/*.yml` validation if we add it. |
| Pester 5.x | PowerShell 5.1+ | preinstalled on `windows-latest`. **Do not** test under PowerShell Core 7 only — production target is 5.1 (per `install-windows.ps1` line 60-62 inline-function constraint). |
| `lipo` | Xcode CLT 14+ | macos-15 runner ships it preinstalled. |
| `launchd` `WatchPaths` | macOS 11+ | Founder's machine is macOS 14+. Comfortable. Note: WatchPaths does **not** recurse. |
| GitHub Releases native digests | gh CLI 2.50+ | macos-15 + windows-latest both ship a recent enough `gh` for `--json digest`. |

## Concrete deliverables (what this stack maps to)

| Phase 1 finish work item | Files produced | Effort estimate |
|---|---|---|
| Telemetry client | `scripts/lib/telemetry.sh` (curl POST helper) + `scripts/lib/telemetry.ps1` (Invoke-RestMethod helper) + `infra/umami/docker-compose.yml` + `infra/umami/README.md` + opt-in prompt block in `install.sh` / `install-windows.ps1` / `install-linux.sh` | 2 days |
| Schema lint (D5) | `tests/test_schema_lint.py` (yamllint subprocess + custom validator class) + `.yamllint` config in repo root | 1 day |
| macOS E2E (Lane E) | `tests/test_install_e2e_mac.sh` + `.github/workflows/install-mac-e2e.yml` (matrix: macos-15 + macos-15-large) | 2 days |
| Windows E2E (Lane E) | `tests/test_install_e2e_win.ps1` (Pester 5) + `.github/workflows/install-win-e2e.yml` | 2 days |
| Universal macOS dylib | edit `smoodle-type/librime/.github/workflows/smoodle-build.yml` to add `lipo` join job + Releases promotion step | 1 day |
| SHA256 verify | edit `install-librime-fork.sh` (lines 78-87) + `install-librime-fork.ps1` (lines 244-288) to read pinned SHA from env or `.sha256` companion file | 0.5 day |
| Sparkle re-swap detect | `infra/macos/im.smoodle.dylib-watch.plist` + `scripts/verify-librime-hash.sh` (compares running dylib's `shasum` to expected) + install-time `launchctl bootstrap` | 1 day |
| README + LoneExile→smoodle-type migration | global text replace across 6 doc files + new Win/Linux install snippets + troubleshooting block | 1 day |
| Decision Gate close | review-and-write task — no new tooling | 0.5 day |
| **Total** | | **~10 days solo wall-time** — fits the ≤2-week budget |

## Sources

- [umami v3.1.0 release (2026-04-16)](https://github.com/umami-software/umami/releases) — version pin, Boards/Replay features, PostgreSQL pairing — HIGH
- [umami self-hosted Docker Compose guide (Paul's Blog 2026)](https://www.paulsblog.dev/self-host-umami-analytics-with-docker-compose/) — 200 MB RAM footprint, postgresql-latest tag — HIGH
- [umami official docs](https://docs.umami.is/docs) — `/api/send` event model, opt-in patterns — HIGH
- [OpenPanel self-hosting docs](https://openpanel.dev/docs/self-hosting/deploy-docker-compose) — ClickHouse + PostgreSQL + Redis stack, 4 vCPU / 8 GB RAM minimum — HIGH (informs the "why not OpenPanel" decision)
- [PostHog vs alternatives blog](https://posthog.com/blog/best-open-source-analytics-tools) — PostHog OSS infra requirements (4 vCPU / 16 GB RAM / 30 GB) — HIGH (informs "why not PostHog")
- [OpenPanel self-hosted analytics 2026 comparison](https://openpanel.dev/articles/self-hosted-web-analytics) — feature breakdown across umami / Plausible / Matomo / OpenPanel — MEDIUM (vendor-authored)
- [Pants anonymous telemetry docs](https://www.pantsbuild.org/dev/docs/using-pants/anonymous-telemetry) — install_id-hash + opt-in CLI + DO_NOT_TRACK convention — HIGH
- [GitHub CLI opt-out telemetry changelog (2026-04-22)](https://github.blog/changelog/2026-04-22-github-cli-opt-out-usage-telemetry/) — current "industry-standard" desktop CLI telemetry shape — HIGH
- [TelemetryDeck anonymization docs](https://telemetrydeck.com/docs/articles/anonymization-how-it-works/) — k-anonymity install_id model — MEDIUM (vendor-authored, useful for "what does good look like")
- [yamllint 1.38.0 (2026-01-13)](https://pypi.org/project/yamllint/) — version, ruleset, Python compat — HIGH
- [check-jsonschema 0.37.1 (2026-03-26)](https://pypi.org/project/check-jsonschema/) — version, JSON Schema CLI behavior — HIGH
- [check-jsonschema GitHub README](https://github.com/python-jsonschema/check-jsonschema) — built-in Workflow / Renovate / Azure schemas — HIGH
- [Pester docs](https://pester.dev/) — Describe/It DSL, NUnit XML output, CI integration — HIGH
- [GitHub Actions PowerShell guide](https://docs.github.com/en/actions/tutorials/build-and-test-code/powershell) — Pester preinstalled on windows-latest — HIGH
- [GitHub Actions macOS 15 + Windows 2025 GA changelog (2025-04-10)](https://github.blog/changelog/2025-04-10-github-actions-macos-15-and-windows-2025-images-are-now-generally-available/) — runner availability — HIGH
- [Apple lipo + universal binary docs](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary) — official `lipo -create` workflow — HIGH
- [GitHub release asset digests changelog (2025-06-03)](https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/) — native SHA256 on Releases — HIGH
- [thanoskoutr SHA256 release verification guide](https://thanoskoutr.com/posts/download-release-github/) — curl + sha256sum pattern — MEDIUM
- [launchd.info tutorial](https://www.launchd.info/) — `LaunchAgent` plist schema, `WatchPaths` semantics — HIGH
- [Apple launchd creating jobs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html) — official `WatchPaths` reference — HIGH
- [LaunchAgents WatchPaths Apple Discussions thread](https://discussions.apple.com/thread/3738263) — non-recursive limitation, mitigation patterns — MEDIUM
- [Sparkle project security docs](https://sparkle-project.org/documentation/customization/) — EdDSA signature model (informs why we cannot intercept Sparkle, only detect after-the-fact) — HIGH
- [Wazuh FIM use case](https://wazuh.com/use-cases/file-integrity-monitoring/) — file integrity monitoring conceptual reference (alternative we are *not* picking) — MEDIUM
- Web searches across `rime/`, `openvanilla/`, `smoodle-type/` orgs for "schema lint" / "yaml linter" / IME CI patterns — **negative result** is the finding: no Rime-specific schema linter exists, custom validator is the right call. Confidence HIGH on "negative result" given multiple search angles attempted.

---

*Stack research for: Smoodle Phase 1 finish (telemetry, schema lint, CI E2E, universal dylib, hash-pinning, Sparkle re-swap detect)*
*Researched: 2026-05-08*
*Solo / ~$0 budget / ≤2 weeks wall-time / dogfood circle audience*
