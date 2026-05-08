# Technology Stack

**Analysis Date:** 2026-05-08

## Languages

**Primary:**
- Bash (POSIX-ish, `set -euo pipefail`) - Installer + bootstrap scripts: `scripts/install.sh`, `scripts/install-librime-fork.sh`, `scripts/install-linux.sh`, `scripts/init_rime_testdir.sh`, `scripts/build-macos-dmg.sh`, `scripts/dev-sync-windows.sh`. All scripts use `#!/usr/bin/env bash` and require `bash` on PATH.
- PowerShell 5.1+ - Windows installers: `scripts/install-windows.ps1`, `scripts/install-librime-fork.ps1`. Targets default Win 11 PowerShell (5.1 inline-function constraint explicitly noted in `install-windows.ps1` lines 60-62). Scripts run under `-ExecutionPolicy Bypass`.
- Python 3.10+ - Test runners and dict-build pipeline: `tests/test_dict.py`, `tests/test_installers.py`, `scripts/generate_dict.py`, `scripts/generate_words.py`, `scripts/merge_dict.py`. `test_dict.py` line 25 explicitly requires Python 3.10+ (uses `match` statement); test files use stdlib only.
- YAML - Rime IME config files: `schema/thai_phonetic.schema.yaml` (engine + speller + algebra rules), `schema/thai_phonetic.dict.yaml` (~28239 entries; two-document YAML with TSV body), `schema/default.custom.yaml` (schema_list patch). Test fixtures: `tests/v01_fixture.yaml`, `tests/v001_fixture.yaml` (custom inline-mapping format, not full PyYAML).
- Perl - Embedded `run_with_timeout` helper inside `scripts/install.sh` (lines 22-38). Used because macOS does not ship GNU `timeout`; Perl is preinstalled on macOS.

**Secondary:**
- TSV (tab-separated) - Dict generator output format: `<thai>\t<romanization>\t<weight>` lines emitted by `scripts/generate_dict.py` and merged by `scripts/merge_dict.py`. Also used for `scripts/generated-*.tsv` and `scripts/tnc_freq.txt`.
- Lua - Not detected in this repo (Rime supports Lua plugins but smoodle's schema does not register any).
- C++ (forthcoming) - Phase 1.5 `smoodle_llm_translator` plugin is mentioned in `README.md` lines 8-10 but no source lives in this repo today; it would be a librime plugin against `vendor/librime/`.

## Runtime

**Environment:**
- CPython 3.10+ - For the test suite and dict-build scripts. No virtualenv tooling checked in; the dict-generation flow expects `pip install anthropic` against the user's system Python or whatever venv they activate.
- librime (Rime engine) - The runtime that consumes `schema/*.yaml`. Smoodle ships a soft-fork at `1.16.0-smoodle.1` (`scripts/install-librime-fork.sh` line 35), distributed as:
  - macOS: pre-built universal `librime.1.dylib` swapped into `/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib` (or built from source via `make release` in `vendor/librime/`).
  - Windows: pre-built `rime.dll` swapped into `C:\Program Files\Rime\weasel-*\rime.dll`, fetched from the fork's `smoodle-build` CI artifact (`scripts/install-librime-fork.ps1` lines 222-288).
  - Linux: distro-provided system librime (apt's `ibus-rime` / `fcitx5-rime`); fork is **not** swapped on Linux (`scripts/install-linux.sh` lines 9-13, 161-176).
- Squirrel.app (macOS) - Rime IME host. Required at `/Library/Input Methods/Squirrel.app`. Installed via `brew install --cask squirrel-app`.
- Weasel (Windows) - Rime IME host. Required under `C:\Program Files\Rime\weasel-*\` or the `(x86)` equivalent. Installed via `winget install Rime.Weasel`.
- ibus-daemon / fcitx5 (Linux) - IME daemons. Detected by `pgrep` in `scripts/install-linux.sh` lines 29-43.
- Bash 3.2+ (macOS default) - The shell scripts avoid bash 4-only features like associative arrays.

**Package Manager:**
- pip (Python) - Used for `anthropic` SDK install in `scripts/generate_dict.py` and `scripts/generate_words.py`. No `requirements.txt` or `pyproject.toml` checked in — dependency installs are documented inline in script docstrings.
- Homebrew (macOS) - `brew install --cask squirrel-app` for the host IM, `brew install cmake boost leveldb marisa yaml-cpp opencc googletest pkg-config ninja glog` when source-building librime (`scripts/install-librime-fork.sh` line 50).
- winget (Windows) - `winget install Rime.Weasel`, `winget install GitHub.cli`, `winget install 7zip.7zip` from `scripts/install-windows.ps1` line 117 and `scripts/install-librime-fork.ps1` lines 130-156.
- apt (Debian/Ubuntu) - `sudo apt-get install -y ibus-rime` (and implicitly `fcitx5-rime` — not exercised in CI). See `.github/workflows/install-linux-e2e.yml` lines 24-27.
- Lockfile: None present. There is no `package-lock.json`, `Pipfile.lock`, `poetry.lock`, or `requirements.txt`. Dependencies are pinned by tag (`SMOODLE_LIBRIME_FORK_TAG=1.16.0-smoodle.1`) and by SDK-default semver (`anthropic`).

## Frameworks

**Core:**
- Rime IME framework - Schema lives in `schema/`. `schema/thai_phonetic.schema.yaml` declares the engine pipeline (`engine.processors`, `engine.segmentors`, `engine.translators`, `engine.filters`), the `speller` (with algebra rules for kh~k / ph~p / vowel-length / final-voicing equivalences), and the `translator` config. `schema/thai_phonetic.dict.yaml` is a two-document Rime native dict (`sort: by_weight`, `columns: [text, code, weight]`).
- Anthropic Python SDK (`anthropic`) - `scripts/generate_dict.py` line 35 imports `anthropic`, `scripts/generate_words.py` likewise. Used to call Claude (default model `claude-opus-4-7` per `scripts/generate_dict.py` line 198) for romanization variant generation. The SDK provides built-in retry on 429/5xx (`max_retries=2`); script wraps `anthropic.RateLimitError` and `anthropic.BadRequestError` explicitly.

**Testing:**
- `unittest` (Python stdlib) - `tests/test_installers.py` line 44 imports unittest; uses `TestCase` subclasses and runs via `python3 tests/test_installers.py` (no `pytest` dep).
- Custom assertion harness - `tests/test_dict.py` is a stdlib-only fixture-driven runner with hand-rolled YAML parsing (line 60-75: regex-based parser, deliberate stdlib-only choice to avoid PyYAML).
- `rime_api_console` (librime CLI) - Engine-mode test driver invoked by `tests/test_dict.py --use-rime-api-console` against `vendor/librime/build/bin/rime_api_console` (default path `tests/test_dict.py` line 49). Test directory bootstrapped by `scripts/init_rime_testdir.sh` to `/tmp/smoodle-rime-test`.

**Build/Dev:**
- `make release` - librime source build entry point, invoked by `scripts/install-librime-fork.sh` line 140 against `vendor/librime/`. Underlying build is CMake + Ninja (per the brew deps list: `cmake`, `ninja`).
- `hdiutil create` (macOS) - DMG packaging in `scripts/build-macos-dmg.sh` lines 133-138. Output: `dist/smoodle-{version}-macOS.dmg`, format UDZO.
- `git describe --tags --always --dirty` - Version stamp source in `scripts/build-macos-dmg.sh` line 19.
- `rsync` - Dev-loop sync to the Lane B Windows VM (`scripts/dev-sync-windows.sh` lines 33-43).
- `gh` (GitHub CLI) - Used by `scripts/install-librime-fork.ps1` lines 227-251 to discover and download CI artifacts from the librime fork's `smoodle-build` workflow.
- `7z` (7-Zip) - Extracts the inner librime artifact archive on Windows (`scripts/install-librime-fork.ps1` line 266).
- Docker / docker-compose - Lane B Windows test bed runs `dockurr/windows:latest` via `docker --context th-dc compose -f infra/lane-b-windows/docker-compose.yml up -d` (`infra/lane-b-windows/README.md` lines 30-34, `infra/lane-b-windows/docker-compose.yml` line 25).

## Key Dependencies

**Critical:**
- `anthropic` (Python, no version pin) - Required by `scripts/generate_dict.py` and `scripts/generate_words.py` for dict-build only. Not needed for runtime IME usage or for installer tests. Uses `client.messages.create` with `output_config.format.type == "json_schema"` (structured output) and `thinking={"type": "adaptive"}`.
- `librime` fork at tag `1.16.0-smoodle.1` from `https://github.com/smoodle-type/librime` - Carries the `DictEntryIterator::Peek` first-call sort fix (see `schema/thai_phonetic.schema.yaml` lines 27-34 and `README.md` line 14-18). Without the fork, algebra-derived spellings collide with direct dict entries and rank wrong on first lookup.
- Squirrel.app / Weasel / ibus-rime - Host IMEs that load the schema. Smoodle does not bundle them; installers verify presence and bail with `brew install --cask squirrel-app` / `winget install Rime.Weasel` / `apt install ibus-rime` hints.

**Infrastructure:**
- librime brew deps (macOS source builds only) - `cmake`, `boost`, `leveldb`, `marisa`, `yaml-cpp`, `opencc`, `googletest`, `pkg-config`, `ninja`, `glog` (`scripts/install-librime-fork.sh` line 50).
- `gh` + `7zip.7zip` (Windows) - For the CI-artifact download path in `scripts/install-librime-fork.ps1`.
- `dockur/windows` Docker image - Lane B test-bed VM image (`infra/lane-b-windows/docker-compose.yml` line 25).
- TNC unigram corpus (CC0-1.0) - `scripts/tnc_freq.txt` shipped via PyThaiNLP. Powers dict weight ranking; loaded by `scripts/merge_dict.py` for `weight = tnc_freq * (variant_q / 100)`.

## Configuration

**Environment:**
- `.env` file present at repo root (gitignored — see `.gitignore` line 33). Contents not inspected per security policy.
- `ANTHROPIC_API_KEY` - Read from environment by `anthropic.Anthropic()` default constructor in `scripts/generate_dict.py` line 216 and `scripts/generate_words.py`. Required only for dict-build runs.
- Installer env overrides (read by all installers; no defaults in `.env`):
  - `SMOODLE_RIME_DIR` - destination dir for schema YAMLs.
  - `SMOODLE_SQUIRREL_PATH` / `SMOODLE_WEASEL_PATH` - host install dir.
  - `SMOODLE_AUTO_DEPLOY` - `0` to skip kill+restart (test mode).
  - `SMOODLE_DEPLOY_TIMEOUT_SECS` - timeout for deploy step (10s macOS/Linux, 60s Windows).
  - `SMOODLE_LIBRIME_FORK_TAG` (default `1.16.0-smoodle.1`), `SMOODLE_RELEASE_URL`, `SMOODLE_LIBRIME_FORK_URL`, `SMOODLE_SKIP_DOWNLOAD`, `SMOODLE_SKIP_BUILD`, `SMOODLE_SKIP_SWAP`, `SMOODLE_FORCE_REBUILD`, `SMOODLE_NONINTERACTIVE`.
  - `SMOODLE_LIBRIME_FORK_REPO` (default `smoodle-type/librime`), `SMOODLE_LIBRIME_FORK_RUN_ID`, `SMOODLE_LIBRIME_VARIANT` (`msvc-x64` default), `SMOODLE_DLL_CACHE_DIR` (default `$LOCALAPPDATA\smoodle\librime`).
  - `SMOODLE_IM` - override Linux IM autodetect (`fcitx5` or `ibus`).
  - `SMOODLE_TH_DC_HOST`, `SMOODLE_TH_DC_SHARE`, `SMOODLE_RSYNC_DRY_RUN` - for `scripts/dev-sync-windows.sh`.

**Build:**
- No `tsconfig.json`, `.eslintrc`, `pyproject.toml`, `Cargo.toml`, `go.mod`, or other top-level project config.
- `LICENSE` - MIT (`README.md` lines 104-113).
- `.gitignore` - excludes `.omc/`, `.claude/`, `*.log`, `.DS_Store`, `build/`, `dist/`, `*.dylib`, `*.o`, `vendor/*` (allowlists `vendor/*.patch`, `vendor/README.md`, `vendor/windows/rime.dll`), `models/`, `*.gguf`, `.pytest_cache/`, `__pycache__/`, `.env`.
- `.github/workflows/install-linux-e2e.yml` - Single CI workflow, runs the Linux schema installer on `ubuntu-latest`.

## Platform Requirements

**Development:**
- macOS - For dogfood / Lane A. Requires Xcode CLT, Homebrew, Squirrel via cask. Source-building librime needs ~2 GB disk and 5-15 min on Apple Silicon.
- Windows 11 - For Lane B installer testing (real machine OR `dockur/windows` VM on `th-dc`). Requires PowerShell 5.1+, winget, optionally `gh` + 7-Zip for the librime fork install.
- Linux - For Lane C. Requires either fcitx5 or ibus running, plus the distro's `*-rime` package. Schema-only install (`scripts/install-linux.sh`); no librime swap.
- Python 3.10+ on PATH for any test runs and dict-generation.

**Production:**
- End-user macOS install path: download `dist/smoodle-{version}-macOS.dmg`, double-click `Install Smoodle.command`. Pulls schema YAMLs into `~/Library/Rime/`, downloads pre-built librime dylib from GitHub Releases, swaps into Squirrel.app (one sudo prompt). No Xcode required.
- End-user Windows install path: clone repo (or open share via dev loop), run `install-windows.ps1` then `install-librime-fork.ps1` (admin). Schema goes to `%APPDATA%\Rime\`; DLL is fetched from CI artifacts on `smoodle-type/librime`.
- End-user Linux install path: `bash scripts/install-linux.sh` — schema only; uses distro librime with the documented "first-lookup ranking" caveat.

---

*Stack analysis: 2026-05-08*
