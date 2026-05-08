# External Integrations

**Analysis Date:** 2026-05-08

## APIs & External Services

**LLM (dict-build only, never runtime IME):**
- Anthropic Claude API (`api.anthropic.com`) — Used by `scripts/generate_dict.py` and `scripts/generate_words.py` to generate Thai romanization variants and curated word lists for the dict.
  - SDK/Client: `anthropic` Python package (no version pin), `anthropic.Anthropic()` default constructor (`scripts/generate_dict.py` line 216).
  - Auth: `ANTHROPIC_API_KEY` environment variable (SDK default).
  - Default model: `claude-opus-4-7` (`scripts/generate_dict.py` line 198); `claude-haiku-4-5` documented as the cheap-bulk alternative (line 28-30).
  - Features used: `messages.create` with `output_config.format.type == "json_schema"` (structured output, `VARIANTS_SCHEMA` line 92), `cache_control={"type": "ephemeral"}` on the system prompt (line 129), `thinking={"type": "adaptive"}` on by default (line 130).
  - Concurrency: up to N parallel workers via `concurrent.futures.ThreadPoolExecutor` (`scripts/generate_dict.py` line 281); script docstring notes the SDK is thread-safe.
  - Failure handling: SDK retries 429/5xx twice automatically (`max_retries=2` default); `_generate_with_retry` at line 293 surfaces `RateLimitError` and `BadRequestError` to the run-level handler so one failed word does not kill a 500-word run.
  - Notable absence: this API is **not** called at IME runtime. The end-user typing path is purely librime + dict; the LLM only writes the dict offline.

**Other external APIs:** None. The runtime IME has no network calls — Phase 1.5 plans an on-device `llama.cpp` + Qwen 1.8B Q4 plugin for tone disambiguation (`README.md` lines 8-10), explicitly "privacy-by-construction (all inference on-device)".

## Data Storage

**Databases:**
- None at the application layer. The shipped artifact is YAML + a TSV-bodied dict.
- Rime internally builds compiled `.bin`/`.prism`/`.table` artifacts plus an `.userdb` LevelDB-style store inside the user's Rime dir. Smoodle does not read/write these directly.

**File Storage:**
- `~/Library/Rime/` (macOS) - Schema YAML destination. Created by `scripts/install.sh` lines 53-70. Files: `thai_phonetic.schema.yaml`, `thai_phonetic.dict.yaml`, `default.custom.yaml`. Idempotent copy with timestamped `.bak.YYYYMMDD-HHMMSS` backups on diff.
- `%APPDATA%\Rime\` (Windows) - Same three YAMLs via `scripts/install-windows.ps1` lines 141-172. Backup naming and SHA-256 diff-check parallel the macOS path. The script also touches all schema timestamps to "now" (line 178-179) and clears `%APPDATA%\Rime\build\thai_phonetic.*` on content change (line 183-189) to force WeaselDeployer rebuild.
- `~/.local/share/fcitx5/rime/` (Linux, fcitx5) - Schema dir for fcitx5 hosts. Selected by `scripts/install-linux.sh` line 65.
- `~/.config/ibus/rime/` (Linux, ibus) - Schema dir for ibus hosts. Selected by `scripts/install-linux.sh` line 69. Verified end-to-end in `.github/workflows/install-linux-e2e.yml` lines 38-47.
- `/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib` (macOS) - Patched dylib swap target. Original preserved at `librime.1.dylib.smoodle-backup` (`scripts/install-librime-fork.sh` line 40, line 171-176).
- `C:\Program Files\Rime\weasel-*\rime.dll` (Windows) - Patched DLL swap target. Original preserved at `rime.dll.smoodle-backup` (`scripts/install-librime-fork.ps1` line 92, line 314-320). Path discovery handles the **versioned** subdir (`weasel-0.17.4`) that `winget install Rime.Weasel` actually uses (`install-windows.ps1` lines 56-76 documents this discovery from 2026-05-07).
- `$LOCALAPPDATA\smoodle\librime\` (Windows) - Cache dir for downloaded `rime.dll`. Default in `scripts/install-librime-fork.ps1` line 69; overridable via `SMOODLE_DLL_CACHE_DIR`.
- `vendor/librime/` - Optional source clone (gitignored except `vendor/*.patch`, `vendor/README.md`, `vendor/windows/rime.dll`). Holds the librime fork checkout when source-building (`scripts/install-librime-fork.sh` lines 109-132).
- `vendor/windows/rime.dll` - **Vendored** patched DLL allowlisted in `.gitignore` (line 24). Checked first by `scripts/install-librime-fork.ps1` lines 102-112 so users who git-clone the repo can install without any network fetch.
- `/tmp/smoodle-rime-test` - librime CLI test harness root. Bootstrapped by `scripts/init_rime_testdir.sh` line 13 with smoodle's two YAMLs plus Squirrel's preset configs (`default.yaml`, `punctuation.yaml`, `symbols.yaml`, `key_bindings.yaml` from `/Library/Input Methods/Squirrel.app/Contents/SharedSupport`); `default.yaml`'s `schema_list` is rewritten to a single `thai_phonetic` entry.
- `dist/smoodle-{version}-macOS.dmg` - DMG packaging output, built by `scripts/build-macos-dmg.sh` line 23.

**Caching:**
- HTTP-level: none (smoodle does not run a server).
- Build artifact cache: `vendor/librime/build/` (gitignored). Wiped on `SMOODLE_FORCE_REBUILD=1`.
- Windows DLL cache: `$LOCALAPPDATA\smoodle\librime\rime.dll` (see above). Subsequent runs skip the `gh run download` + 7-Zip extract.

## Authentication & Identity

**Auth Provider:**
- None for the IME runtime — there is no user account, no login, no telemetry-with-identity layer.
- Anthropic API key (`ANTHROPIC_API_KEY`) is the only credentialed surface, and only the maintainer running dict-build needs it.

## Monitoring & Observability

**Error Tracking:**
- None. No Sentry, Bugsnag, or similar SDK in the codebase.

**Logs:**
- Installer scripts log to stdout/stderr only.
- Dict-generation scripts append run logs to `*.log` files at repo root (e.g. `.generation.log`, `scripts/generate-tnc-full.log`, `scripts/generated-500.log`); `*.log` is in `.gitignore`.
- Squirrel/Weasel/ibus deploy errors surface in their own GUI logs (Console.app on macOS, Weasel tray icon → Show logs on Windows, `fcitx5 -d --replace` / `ibus-daemon -v -drxR` on Linux). Installer scripts print these as fallback hints when auto-deploy fails (`scripts/install.sh` lines 119-138, `scripts/install-linux.sh` lines 144-177, `scripts/install-windows.ps1` lines 244-265).

## CI/CD & Deployment

**Hosting:**
- GitHub - Source repo at `smoodle-type/smoodle`; sister repos `smoodle-type/librime` (the fork) and `smoodle-type/smoodle-app` (macOS Squirrel-fork app, lives outside this repo at `/Users/lex/Dev/my_repos/experiment/smoodle-app`).
- GitHub Releases (`smoodle-type/librime`) - Pre-built macOS universal `librime-{tag}-macOS-universal.dylib` asset hosted at `https://github.com/smoodle-type/librime/releases/download/${FORK_TAG}/librime-${FORK_TAG}-macOS-universal.dylib` (`scripts/install-librime-fork.sh` lines 43-44). Default tag `1.16.0-smoodle.1`.
- GitHub Releases (`smoodle-type/smoodle`) - Target for the macOS DMG (`scripts/build-macos-dmg.sh` line 153 documents `gh release upload v${VERSION} "${OUT_DMG}" -R smoodle-type/smoodle`).
- GitHub Actions Artifacts (`smoodle-type/librime`, workflow `smoodle-build`) - Source for the Windows `rime.dll` (`scripts/install-librime-fork.ps1` lines 226-251). Variants: `msvc-x64` (default), `msvc-x86`, `clang-x64`, `mingw`. Inner archive is `rime-*-Windows-{variant}.7z` containing `dist/lib/rime.dll`.

**CI Pipeline:**
- `.github/workflows/install-linux-e2e.yml` - Runs on push/PR to `main` when `scripts/install-linux.sh`, `schema/**`, or the workflow itself changes. `ubuntu-latest` runner, installs `ibus-rime` via apt, runs the Linux installer with `SMOODLE_AUTO_DEPLOY=0 SMOODLE_IM=ibus`, verifies the three schema files land in `~/.config/ibus/rime/`.
- No macOS or Windows CI in this repo. Windows artifact CI lives in the librime fork (`smoodle-build` workflow on `smoodle-type/librime`) and is consumed here, not produced here.

## Environment Configuration

**Required env vars:**
- `ANTHROPIC_API_KEY` - For `scripts/generate_dict.py` and `scripts/generate_words.py` only (dict-build path; not needed for IME use or installer tests).

**Optional env vars (override defaults):**
- Installer path/timeout/skip flags: `SMOODLE_RIME_DIR`, `SMOODLE_SQUIRREL_PATH`, `SMOODLE_WEASEL_PATH`, `SMOODLE_AUTO_DEPLOY`, `SMOODLE_DEPLOY_TIMEOUT_SECS`, `SMOODLE_NONINTERACTIVE`.
- librime fork acquisition: `SMOODLE_LIBRIME_FORK_TAG`, `SMOODLE_LIBRIME_FORK_URL`, `SMOODLE_LIBRIME_FORK_REPO`, `SMOODLE_LIBRIME_FORK_RUN_ID`, `SMOODLE_LIBRIME_VARIANT`, `SMOODLE_RELEASE_URL`, `SMOODLE_SKIP_DOWNLOAD`, `SMOODLE_SKIP_BUILD`, `SMOODLE_SKIP_SWAP`, `SMOODLE_FORCE_REBUILD`, `SMOODLE_DLL_CACHE_DIR`.
- Linux IM detection: `SMOODLE_IM` (`fcitx5` or `ibus`).
- Windows dev loop: `SMOODLE_TH_DC_HOST`, `SMOODLE_TH_DC_SHARE`, `SMOODLE_RSYNC_DRY_RUN`.

**Secrets location:**
- `.env` file at repo root, gitignored. Contents not read per security policy.
- No CI secrets currently configured (the one Linux workflow needs none).
- Anthropic API key never written to disk by smoodle scripts; sourced from env only.

## Webhooks & Callbacks

**Incoming:** None. There is no smoodle server.

**Outgoing:** None at runtime. The only outbound HTTP traffic is from operator/maintainer machines:
- `curl https://github.com/smoodle-type/librime/releases/download/...` (macOS dylib download, `scripts/install-librime-fork.sh` line 78).
- `gh run list` and `gh run download` against `smoodle-type/librime` (Windows DLL download, `scripts/install-librime-fork.ps1` lines 227, 246).
- `winget install ...` (Microsoft package source).
- `brew install ...` (Homebrew CDN).
- `apt-get install ...` (distro mirror).
- `git clone https://github.com/smoodle-type/librime.git` (source-build path).
- `https://api.anthropic.com` (dict-build only).
- `rsync` over SSH to `th-dc` (dev-loop only).

## Package-Manager Touch Points (by installer)

**macOS (`scripts/install.sh`, `scripts/install-librime-fork.sh`):**
- Homebrew (`brew install --cask squirrel-app`) - host IME (user-installed, script verifies presence).
- Homebrew formulae for source build only: `cmake boost leveldb marisa yaml-cpp opencc googletest pkg-config ninja glog` (script bails with the exact `brew install` line if missing).
- `curl` (preinstalled) - dylib download from GitHub Releases.
- No `pip install` invoked by installers; only by dict-build scripts (manual step in script docstrings).

**Windows (`scripts/install-windows.ps1`, `scripts/install-librime-fork.ps1`):**
- `winget install Rime.Weasel --interactive --accept-source-agreements --accept-package-agreements` - Weasel host. Deliberately **not** `--silent` (Weasel ships an Inno Setup MSI that hangs on `--silent`; verified 2026-05-07 on the th-dc test bed; comment at `install-windows.ps1` lines 110-116).
- `winget install GitHub.cli` - for `gh run download`.
- `winget install 7zip.7zip` - for archive extraction.

**Linux (`scripts/install-linux.sh`):**
- The script does **not** invoke any package manager. It assumes the user has already installed `ibus-rime` (`apt-get install -y ibus-rime`) or `fcitx5-rime` and bails if neither daemon is running.
- CI runner uses `sudo apt-get install -y ibus-rime` directly (`.github/workflows/install-linux-e2e.yml` line 27).

## librime Engine Integration

**Why the fork (`smoodle-type/librime` @ `1.16.0-smoodle.1`):**
- Patches `DictEntryIterator::Peek` to call `Sort()` once before the first peek.
- Without the patch, when an algebra-derived spelling shares a syllable with a direct one, the alphabetically-earlier syllable wins position #1 regardless of weight (e.g. `yaai` < `yai` causes `ย้าย` to outrank `ใหญ่`). See `schema/thai_phonetic.schema.yaml` lines 27-34 and `README.md` line 14-18.
- Patch was historically a `vendor/librime-1.16.0-peek-sort.patch` file; the fork tag is now canonical (`README.md` line 87).

**Distribution model differs by platform:**
- macOS: pre-built universal dylib via GitHub Releases (primary) or local source build via `make release` (fallback). Swap target `/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib`. Sparkle auto-update on Squirrel can overwrite the patched dylib — re-running the installer reapplies it (`scripts/install-librime-fork.sh` lines 193-196).
- Windows: pre-built DLL via `gh run download` from the fork's `smoodle-build` GHA artifact, or a vendored `vendor/windows/rime.dll`. Swap target `C:\Program Files\Rime\weasel-*\rime.dll`. WeaselServer + WeaselDeployer must be stopped before swap to release the file lock (`scripts/install-librime-fork.ps1` lines 322-333), with up to 5 retry attempts (lines 338-353).
- Linux: **no fork swap**. Distro librime is used; ranking limitation is documented inline in the installer's trailing test instructions (`scripts/install-linux.sh` lines 161-176) and revisited only if Linux dogfood signal materialises.

**Engine-mode tests:**
- `tests/test_dict.py --use-rime-api-console` drives `vendor/librime/build/bin/rime_api_console` against `/tmp/smoodle-rime-test/` (bootstrapped by `scripts/init_rime_testdir.sh`).
- The bootstrap copies smoodle's two YAMLs alongside Squirrel's preset configs (`default.yaml`, `punctuation.yaml`, `symbols.yaml`, `key_bindings.yaml`) from `/Library/Input Methods/Squirrel.app/Contents/SharedSupport`, then trims `default.yaml`'s `schema_list` to a single `thai_phonetic` entry.

## Lane B Test-Bed Integration (Windows)

**Docker on a remote context (`th-dc`):**
- `infra/lane-b-windows/docker-compose.yml` defines a single service `windows` using `dockurr/windows:latest` (Win 11, 16 GB RAM, 8 CPU cores, 64 GB disk).
- Bind mount: `/root/smoodle-shared:/data` on the host → `\\host.lan\Data` SMB share inside the VM (with a `Shared` desktop shortcut auto-created by dockur).
- Ports exposed on `0.0.0.0`: `8006` (web VNC), `3389/tcp+udp` (RDP), `2222` (SSH forward).
- Credentials: `smoodle / smoodle` — test-bed only; the README warns explicitly against running this compose on a public-internet host without rotating credentials and binding to `127.0.0.1`.
- Dev loop: `scripts/dev-sync-windows.sh` rsync's the smoodle tree to `th-dc:/root/smoodle-shared/`, the VM mounts it as `\\host.lan\Data`, the operator runs `install-windows.ps1` from the share inside the VM.

---

*Integration audit: 2026-05-08*
