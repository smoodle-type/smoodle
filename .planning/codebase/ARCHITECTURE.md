<!-- refreshed: 2026-05-08 -->
# Architecture

**Analysis Date:** 2026-05-08

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         User-facing IME shell                        │
│  Squirrel.app (macOS)   Weasel (Win)   fcitx5 / ibus (Linux)         │
│  external — installed via Homebrew / winget / apt                    │
└────────────┬─────────────────┬────────────────────┬─────────────────┘
             │ loads YAML +    │ loads YAML +       │ loads YAML
             │ links librime   │ links rime.dll     │ system librime
             ▼                 ▼                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  Rime engine (C++)  —  libRime.dylib / .dll / .so    │
│  processors → segmentors → translators → filters                     │
│  macOS / Win: smoodle-type/librime fork (peek-sort patch)            │
│  Linux:       distro system librime (unpatched; ranking caveat)      │
│  source tree: `vendor/librime/`  (gitignored, fetched on demand)     │
└────────────┬────────────────────────────────────────────────────────┘
             │ reads three YAMLs from per-platform Rime user dir
             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  smoodle schema (the only artifact this repo owns)   │
│  `schema/thai_phonetic.schema.yaml`   speller.algebra + engine list  │
│  `schema/thai_phonetic.dict.yaml`     14893 words / 28239 TSV rows   │
│  `schema/default.custom.yaml`         registers schema_id globally   │
└────────────▲────────────────────────────────────────────────────────┘
             │ copied at install time by platform installers
             │
┌────────────┴────────────────────────────────────────────────────────┐
│                  Installer + dict-build scripts                      │
│  macOS:    `scripts/install.sh`  +  `scripts/install-librime-fork.sh`│
│  Linux:    `scripts/install-linux.sh`  (schema only, no dylib swap)  │
│  Windows:  `scripts/install-windows.ps1`  +                          │
│            `scripts/install-librime-fork.ps1`                        │
│  Bundle:   `scripts/build-macos-dmg.sh`  →  `dist/*.dmg`             │
│  Dict:     `scripts/generate_words.py` → `scripts/generate_dict.py`  │
│            → `scripts/merge_dict.py`  (TNC-frequency-weighted)       │
│  Tests:    `tests/test_dict.py`, `tests/test_installers.py`          │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Schema | Speller algebra rules + engine pipeline declaration | `schema/thai_phonetic.schema.yaml` |
| Dictionary | `<thai>\t<romanization>\t<weight>` TSV body with TNC-weighted variants | `schema/thai_phonetic.dict.yaml` |
| Schema patch | Registers `thai_phonetic` in Rime's global `schema_list` | `schema/default.custom.yaml` |
| macOS installer | Copies schemas to `~/Library/Rime/`, restarts Squirrel with timeout | `scripts/install.sh` |
| macOS librime swap | Downloads/builds patched dylib, swaps into `Squirrel.app/Contents/Frameworks/` | `scripts/install-librime-fork.sh` |
| Linux installer | Detects fcitx5/ibus, copies schemas to per-IM dir, reloads daemon | `scripts/install-linux.sh` |
| Windows installer | Copies schemas to `%APPDATA%\Rime\`, runs `WeaselDeployer.exe /deploy` | `scripts/install-windows.ps1` |
| Windows librime swap | Downloads pre-built `rime.dll` from CI artifact, swaps into Weasel install dir | `scripts/install-librime-fork.ps1` |
| DMG packager | Bundles schemas + installers + `Install Smoodle.command` into a UDZO image | `scripts/build-macos-dmg.sh` |
| Dev sync | rsyncs the working tree to the `th-dc` Lane B Win 11 VM | `scripts/dev-sync-windows.sh` |
| Test bootstrap | Initializes `/tmp/smoodle-rime-test` for `rime_api_console` runs | `scripts/init_rime_testdir.sh` |
| Word list generator | Calls Claude API to produce ~500 categorized common Thai words | `scripts/generate_words.py` |
| Dict variant generator | Calls Claude API for romanization variants per word; writes TSV | `scripts/generate_dict.py` |
| Dict merger | Merges generated TSV into Rime dict YAML; reweights by TNC freq | `scripts/merge_dict.py` |
| String-match dict test | Asserts `(thai, romanization)` pairs exist in the dict body | `tests/test_dict.py` |
| Engine-mode dict test | Drives same fixtures through `rime_api_console`, top-N candidate check | `tests/test_dict.py` (`--use-rime-api-console`) |
| Installer test suite | Sandboxed end-to-end exercise of `install.sh` + shape checks for all installers | `tests/test_installers.py` |
| Lane B test bed | Win 11 KVM VM via dockur/windows on the `th-dc` remote docker context | `infra/lane-b-windows/docker-compose.yml` |
| Lane C CI | GitHub Actions ubuntu-latest job that installs `ibus-rime` and runs the Linux installer | `.github/workflows/install-linux-e2e.yml` |

## Pattern Overview

**Overall:** Schema-and-scripts repo (no compiled artifacts owned). smoodle ships YAML configuration that is loaded and executed by an external C++ engine (Rime/librime) embedded in an external IME host (Squirrel/Weasel/fcitx5/ibus). The repo's job is to (a) author and weight the schema, (b) deliver it to platform-specific Rime user directories, and (c) on macOS+Windows, swap in a patched librime to fix one upstream ranking bug.

**Key Characteristics:**

- **No compiled artifacts in the repo.** `vendor/librime/` is gitignored (≈2 GB after build). `vendor/windows/rime.dll` is the one tracked binary (2.9 MB pre-built CI artifact, used as the offline-install fallback for Lane B). Build outputs land in `build/` and `dist/` (gitignored).
- **Three install layers, separable:** schema YAMLs (sudoless, user dir) vs. patched librime dylib/DLL (sudo/admin, system dir) vs. host IME (Homebrew/winget/apt). The two layers are independent installers so a user can re-run schema updates without re-elevating.
- **Per-platform divergence is in the installer scripts, not in the schema.** The schema YAMLs are platform-neutral; only the destination paths and deploy commands differ.
- **Schema is data + algebra, not code.** The "phonetic equivalence" logic that maps user input to dict entries is expressed as `derive/X/Y/` regex rules in `speller.algebra` (see `schema/thai_phonetic.schema.yaml:84-110`). No imperative code runs in the schema.
- **Reproducible dict build.** The dictionary YAML is regenerated from `scripts/words-tnc-full.txt` + `scripts/tnc_freq.txt` via the `generate_words.py` → `generate_dict.py` → `merge_dict.py` pipeline. The TSV outputs (`scripts/generated-*.tsv`) are checked in so the build is deterministic without re-running the LLM.
- **Tests run two depths:** fast string-match (`tests/test_dict.py`, no librime build needed) and engine-mode (drives `vendor/librime/build/bin/rime_api_console`, exercises full pipeline including algebra). Both share the same fixture YAML.

## Layers

**Schema layer (data):**
- Purpose: Declarative description of the IME's behavior (engine pipeline, speller algebra, dictionary lookup table).
- Location: `schema/`
- Contains: Three YAML files consumed by Rime — `thai_phonetic.schema.yaml`, `thai_phonetic.dict.yaml`, `default.custom.yaml`.
- Depends on: Rime engine semantics (processor/segmentor/translator/filter names; `derive/X/Y/` algebra DSL; native-dict TSV body format).
- Used by: All three platform installers; the test fixtures; the DMG bundler.

**Engine layer (external, vendored for build):**
- Purpose: Convert romanized input → ranked Thai candidates using the schema.
- Location: `vendor/librime/` (gitignored upstream checkout); patched fork at `https://github.com/smoodle-type/librime`, fork tag `1.16.0-smoodle.1`.
- Contains: The `DictEntryIterator::Peek` first-call-sort patch (originally `vendor/librime-1.16.0-peek-sort.patch`, now upstreamed into the fork).
- Depends on: brew deps `cmake boost leveldb marisa yaml-cpp opencc googletest pkg-config ninja glog` (declared in `scripts/install-librime-fork.sh:50`).
- Used by: `scripts/install-librime-fork.sh` (build + swap), `scripts/init_rime_testdir.sh` (`vendor/librime/build/bin/rime_api_console`), `tests/test_dict.py` engine mode.

**Installer layer (scripts):**
- Purpose: Move schema YAMLs into the right per-platform Rime user dir; trigger a deploy; optionally swap in the patched librime.
- Location: `scripts/`
- Contains: `install.sh` (macOS), `install-linux.sh` (Linux fcitx5/ibus), `install-windows.ps1` (Windows/Weasel), plus librime-swap counterparts.
- Depends on: Per-platform IME hosts (Squirrel/Weasel/fcitx5/ibus) being installed; admin/sudo for the librime swap; `gh` + 7-Zip on Windows when downloading CI artifacts.
- Used by: End users (macOS dogfood path; Lane B/C dogfood paths); `tests/test_installers.py`; `scripts/build-macos-dmg.sh`.

**Dict-build layer (scripts):**
- Purpose: Reproducibly generate `schema/thai_phonetic.dict.yaml` from a Thai word list + per-word LLM-generated romanization variants + TNC unigram frequencies.
- Location: `scripts/generate_words.py`, `scripts/generate_dict.py`, `scripts/merge_dict.py`
- Contains: Anthropic-API callers (curated word list; per-word JSON variants), TSV merger with TNC frequency reweighting.
- Depends on: `pip install anthropic`; `ANTHROPIC_API_KEY` env var; `scripts/tnc_freq.txt` (PyThaiNLP TNC unigram, CC0).
- Used by: Manually invoked when expanding the dict; outputs (`scripts/generated-*.tsv`, `scripts/words-*.txt`) are committed.

**Test layer:**
- Purpose: Catch romanization typos, missing variants, ranking regressions, installer drift.
- Location: `tests/`
- Contains: `test_dict.py` (string-match + engine mode), `test_installers.py` (shape + sandboxed E2E), fixtures `v001_fixture.yaml` and `v01_fixture.yaml`.
- Depends on: stdlib only for the dict test; `bash`/`perl` for the installer test; `vendor/librime/build/bin/rime_api_console` for engine mode.
- Used by: Manual local runs (per `README.md`); GitHub Actions Lane C job for the Linux installer.

**Packaging layer:**
- Purpose: Wrap schemas + installers into a single double-clickable DMG for non-CLI dogfood users.
- Location: `scripts/build-macos-dmg.sh`
- Contains: hdiutil UDZO build, generated `Install Smoodle.command` shim, generated `README.txt`.
- Depends on: `git describe` for the version stamp; `hdiutil` (macOS-only).
- Used by: Manual release runs; output lands in `dist/`.

## Data Flow

### Primary Request Path (user types romanized input → Thai candidate)

1. User types `sawadee` in any text field with the active IME set to `smoodle Thai phonetic`.
2. The IME shell (Squirrel / Weasel / fcitx5 / ibus) hands keystrokes to its embedded `librime` (link target: `Squirrel.app/Contents/Frameworks/librime.1.dylib` on macOS, `Rime\Weasel\rime.dll` on Windows, distro `librime.so` on Linux).
3. The Rime engine runs the schema pipeline declared at `schema/thai_phonetic.schema.yaml:53-73`:
   - `ascii_composer` / `recognizer` / `key_binder` / `speller` / `punctuator` / `selector` / `navigator` / `express_editor` (processors)
   - `ascii_segmentor` / `matcher` / `abc_segmentor` / `punct_segmentor` / `fallback_segmentor` (segmentors)
   - `punct_translator` / `table_translator` (translators)
   - `uniquifier` (filter)
4. The `speller` applies `algebra` derivations (`schema/thai_phonetic.schema.yaml:84-110`) so `sawadee` matches dict entries that store either `sawadee`, `sawadi`, `sawatdee`, or any aspiration/vowel-length/final-voicing variant.
5. `table_translator` looks up the matching syllabary entries in the compiled prism for `schema/thai_phonetic.dict.yaml`. Each candidate carries a weight = `tnc_freq * (variant_quality / 100)` (see comment block at `schema/thai_phonetic.dict.yaml:1-30` and the reweight code at `scripts/merge_dict.py:149-169`).
6. `initial_quality: 0` (`schema/thai_phonetic.schema.yaml:120`) lets the raw weights dictate rank — the `exp(log_weight)` from `dict_compiler.cc` is the only signal.
7. `uniquifier` collapses duplicate Thai-script candidates from algebra-derived collisions.
8. Top-N candidates (with `สวัสดี` ranked #1) are returned to the IME shell, which renders the candidate window.

### Install path (macOS dogfood)

1. User runs `bash scripts/install.sh` (`scripts/install.sh:8`).
2. Script verifies `Squirrel.app` exists at `/Library/Input Methods/Squirrel.app` (`scripts/install.sh:47-51`); fails loudly with the `brew install` line if missing.
3. Three YAMLs copied from `schema/` → `~/Library/Rime/` with timestamped backup of any prior copy that differs (`scripts/install.sh:56-70`).
4. Post-copy verify each file exists at the destination (`scripts/install.sh:73-78`).
5. `osascript` quits Squirrel; `open -b im.rime.inputmethod.Squirrel` restarts it. Each step is wrapped in a 10s perl-based `run_with_timeout` (`scripts/install.sh:22-38`, `:96-109`) — macOS does not ship GNU `timeout`.
6. User then runs `bash scripts/install-librime-fork.sh` to swap in the patched dylib (download from `https://github.com/smoodle-type/librime/releases/download/1.16.0-smoodle.1/librime-1.16.0-smoodle.1-macOS-universal.dylib` by default, source-build fallback on download failure). This step requires sudo because `/Library/Input Methods/Squirrel.app/Contents/Frameworks/` is in `/Library`.

### Install path (Windows dogfood)

1. `powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1`.
2. Probes for Weasel under `C:\Program Files\Rime\Weasel\` and `C:\Program Files\Rime\weasel-*` (`scripts/install-windows.ps1:62-76`); auto-installs via `winget install Rime.Weasel --interactive` if missing (single UAC prompt).
3. Copies three YAMLs to `%APPDATA%\Rime\`, SHA256-compared with timestamped backup (`scripts/install-windows.ps1:147-189`).
4. Touches every YAML's `LastWriteTime` to now and clears `%APPDATA%\Rime\build\thai_phonetic.*` so `WeaselDeployer.exe` can't silently skip recompilation.
5. Runs `WeaselDeployer.exe /deploy` with a 60s timeout (`scripts/install-windows.ps1:218-230`).
6. `install-librime-fork.ps1` is a separate admin-required step that downloads `rime.dll` from `smoodle-type/librime`'s `smoodle-build` CI artifact (or uses the vendored `vendor/windows/rime.dll`) and swaps it into the Weasel install dir.

### Install path (Linux dogfood)

1. `bash scripts/install-linux.sh`.
2. Detects which IM daemon is running (`pgrep -x fcitx5` then `pgrep -x ibus-daemon`; `SMOODLE_IM` env override) — `scripts/install-linux.sh:29-43`. Hard-fails if neither is up.
3. Per-IM destination + reload command — `scripts/install-linux.sh:63-76`:
   - fcitx5 → `~/.local/share/fcitx5/rime/`, reload via `fcitx5 -r`.
   - ibus → `~/.config/ibus/rime/`, reload via `ibus-daemon -drxR`.
4. Copies three YAMLs (same backup pattern as macOS).
5. Reloads the daemon under a 10s GNU `timeout`.
6. Prints a "Ranking limitation" notice — Linux distros' system librime lacks the peek-sort patch, so first-lookup ranking can be wrong on algebra-vs-direct collisions.

### Dict-build pipeline

1. `python3 scripts/generate_words.py --output scripts/words-500.txt` — Claude curates a categorized list of high-frequency Thai words.
2. `python3 scripts/generate_dict.py --words scripts/words-tnc-full.txt --output scripts/generated-tnc-full.tsv` — for each Thai word, asks Claude for 1-3 romanization variants (excluding any that algebra rules would derive automatically). Resumable: skips Thai words already represented in the output TSV.
3. `python3 scripts/merge_dict.py --base schema/thai_phonetic.dict.yaml --add scripts/generated-tnc-full.tsv --tnc-freq scripts/tnc_freq.txt --output schema/thai_phonetic.dict.yaml` — union-with-max-weight merge, reweight every variant to `tnc_freq * (q/100)`, write the Rime native dict YAML. Words not in TNC fall back to `--default-freq` (default 10).

**State Management:**

- No long-lived runtime state in the repo's code — every script is one-shot.
- Persistent state lives in three places: (a) the user's Rime user dir (`~/Library/Rime/`, `%APPDATA%\Rime\`, `~/.local/share/fcitx5/rime/`, `~/.config/ibus/rime/`); (b) the IME shell process (which holds the open librime context); (c) the patched librime dylib/DLL inside the IME shell's bundle.
- Reproducible build state is git-tracked: `schema/*.yaml`, `scripts/words-*.txt`, `scripts/generated-*.tsv`, `scripts/tnc_freq.txt`, `vendor/windows/rime.dll`, `vendor/librime-1.16.0-peek-sort.patch`.

## Key Abstractions

**Rime schema model:**
- Purpose: A Rime "schema" is a YAML document with a fixed shape (`schema:`, `switches:`, `engine:`, `speller:`, `translator:`, `punctuator:`, `key_binder:`, `recognizer:`) that wires up the engine pipeline. smoodle owns one schema, `thai_phonetic`.
- Examples: `schema/thai_phonetic.schema.yaml`.
- Pattern: Declarative engine pipeline + lookup table + speller algebra. No imperative code; Rime executes the named processors/segmentors/translators/filters in order.

**Speller algebra (`derive/X/Y/`):**
- Purpose: Express "user typed X is equivalent to dict entry's Y" as a one-line regex substitution rule. Lets the dict store 1-3 spelling variants per word and have the engine fan them out at input time.
- Examples: `schema/thai_phonetic.schema.yaml:84-110` (12 rules: aspiration kh~k, vowel-length aa~a, final-voicing p~b/t~d both directions).
- Pattern: Additive — dict spelling preserved AND alternative accepted at input time. Reference schemas: `terra_pinyin.schema.yaml` and `pinyin.yaml` from upstream Rime.

**Rime native dict format:**
- Purpose: Two-document YAML — frontmatter with `name`/`version`/`sort`/`columns` declarations, then `...` separator, then a TSV body of `<thai>\t<romanization>\t<weight>` rows.
- Examples: `schema/thai_phonetic.dict.yaml`; frontmatter constant at `scripts/merge_dict.py:42-86`.
- Pattern: Sort `by_weight`; weights are raw counts (not log-probs) because Rime's `dict_compiler.cc` applies `log()` at compile time and `table_translator.cc` applies `exp()` at query time (`scripts/merge_dict.py:155-162`).

**Schema-list patch (`default.custom.yaml`):**
- Purpose: Make `thai_phonetic` appear in Squirrel/Weasel's Ctrl+\` schema switcher.
- Examples: `schema/default.custom.yaml`.
- Pattern: Standard Rime "patch" — a sidecar YAML that overlays keys into Rime's compiled `default.yaml`.

**Per-platform Rime user dir:**
- Purpose: Single canonical destination per platform. Every installer writes to and only to this dir (and, optionally, swaps the dylib next to the IME shell). No registry edits, no PATH munging.
- Examples: `${HOME}/Library/Rime` (macOS), `${env:APPDATA}\Rime` (Windows), `${HOME}/.local/share/fcitx5/rime` or `${HOME}/.config/ibus/rime` (Linux).
- Pattern: Env-overridable in every installer (`SMOODLE_RIME_DIR`) so the test suite can sandbox the install into a temp dir.

**Fixture-driven dict test:**
- Purpose: One YAML file (`tests/v01_fixture.yaml`) holds every `(romanization, expected_thai, via?)` assertion. The same fixture drives both the fast string-match path and the slow engine-mode path.
- Examples: `tests/v001_fixture.yaml` (v0.0.1, ~50 entries), `tests/v01_fixture.yaml` (v0.1, 56 entries: 35 direct + 21 algebra-tagged).
- Pattern: `via:` field tags algebra-derived assertions so the string-match driver can `SKIP` them with a note (it cannot verify them without the engine), while engine mode runs both classes through `rime_api_console`.

## Entry Points

**Schema (data entry into Rime):**
- Location: `schema/thai_phonetic.schema.yaml`, `schema/thai_phonetic.dict.yaml`, `schema/default.custom.yaml`.
- Triggers: Rime engine deploy (Squirrel restart, `WeaselDeployer.exe /deploy`, `fcitx5 -r`, `ibus-daemon -drxR`).
- Responsibilities: Declare engine pipeline, supply lookup table, register in global schema list.

**Installer scripts (user-facing):**
- `scripts/install.sh` — macOS schema install (sudoless, ~/Library/Rime).
- `scripts/install-librime-fork.sh` — macOS dylib swap (sudo).
- `scripts/install-linux.sh` — Linux schema install (fcitx5/ibus autodetect; no dylib swap by design).
- `scripts/install-windows.ps1` — Windows schema install + WeaselDeployer auto-deploy.
- `scripts/install-librime-fork.ps1` — Windows DLL swap (admin).
- `scripts/build-macos-dmg.sh` — bundles the four artifacts above plus a generated `Install Smoodle.command` shim into `dist/smoodle-{version}-macOS.dmg`.
- Triggers: `bash` / `powershell` invocation by user or by the DMG's `.command` shim.

**Dict-build entry points (developer-facing):**
- `scripts/generate_words.py --output ...` — produces a curated word list.
- `scripts/generate_dict.py --words ... --output ...` — produces romanization-variant TSV.
- `scripts/merge_dict.py --base ... --add ... --tnc-freq ... --output ...` — produces the final dict YAML.

**Test entry points:**
- `python3 tests/test_dict.py [--use-rime-api-console] [--fixture ...]` — fixture-driven dict correctness.
- `python3 tests/test_installers.py` — installer shape + sandboxed E2E.
- `scripts/init_rime_testdir.sh [test_dir]` — bootstrap the working dir for engine-mode tests.

**CI entry point:**
- `.github/workflows/install-linux-e2e.yml` — runs on push/PR touching `scripts/install-linux.sh`, `schema/**`, or the workflow itself; installs `ibus-rime` on `ubuntu-latest`, runs the installer with `SMOODLE_AUTO_DEPLOY=0 SMOODLE_IM=ibus`, asserts the three YAMLs landed in `~/.config/ibus/rime/`.

## Architectural Constraints

- **Threading:** All scripts are single-threaded except `scripts/generate_dict.py`, which uses `concurrent.futures.ThreadPoolExecutor` to parallelize Anthropic-API calls. The Rime engine itself runs inside the IME shell process; smoodle owns no engine threads.
- **Global state:** No module-level singletons in Python scripts. Every script reads its inputs as arguments and writes outputs to declared paths. Persistent global state is exclusively in the user's Rime dir + the IME shell's library bundle.
- **Circular imports:** None. Test files import nothing from `scripts/`; both depend only on stdlib (plus `anthropic` for the dict-generation scripts).
- **Vendored librime is gitignored:** `vendor/librime/` is a ~2 GB upstream checkout (gitignored per `.gitignore:18-24`). The `install-librime-fork.sh` script clones it on demand. Only the historical `vendor/librime-1.16.0-peek-sort.patch` and the pre-built Windows DLL `vendor/windows/rime.dll` are tracked.
- **Schema YAML must be platform-neutral:** Per-platform divergence stays in the installers. The schema YAMLs themselves do not encode any path, build flag, or OS branch.
- **Dict body must be tab-separated, no spaces in romanization:** Rime's `table_translator` treats space as a commit delimiter, so multi-syllable Thai words use continuous Latin (`khopkhun` not `khop khun`) — see `schema/thai_phonetic.dict.yaml:7-8`.
- **Weight rescaling must produce raw counts, not log-probs:** Rime's `dict_compiler.cc:257` applies `log()` at compile time; `table_translator.cc:90` applies `exp()` at query time. Pre-logging would double-log and flatten ranks (`scripts/merge_dict.py:155-162`).
- **`initial_quality` must be 0:** Setting it to `1.0` makes the constant dominate the dynamic range of `exp(weight - log(1e8))`, masking frequency differences and causing rank ties (`schema/thai_phonetic.schema.yaml:118-120`).
- **Linux builds use the distro's unpatched system librime by design:** Lane C scope explicitly excludes shipping a forked librime on Linux. Algebra-vs-direct ranking collisions can mis-rank on first lookup; the workaround (commit and retype) is documented in the installer's tail notice (`scripts/install-linux.sh:160-176`).
- **Squirrel auto-update can clobber the patched dylib:** Sparkle updates of Squirrel rewrite `Contents/Frameworks/librime.1.dylib`. Re-running `install-librime-fork.sh` reapplies the swap (`scripts/install.sh:133-137`, `scripts/install-librime-fork.sh:193-195`).
- **Windows winget Weasel installer hangs on `--silent`:** The Inno Setup silent-mode handshake is incomplete. `install-windows.ps1` deliberately uses `--interactive` (`scripts/install-windows.ps1:110-117`).
- **PowerShell 5.1 cannot reference functions defined later in the same script:** Inline path-resolution code is required in `install-windows.ps1` and `install-librime-fork.ps1` (`scripts/install-windows.ps1:62-76`).

## Anti-Patterns

### Storing log-probabilities in the dict body

**What happens:** Pre-applying `log()` to weights in the dict YAML before Rime's compiler sees them.
**Why it's wrong:** Rime's `dict_compiler.cc:257` already applies `log()` at compile time and `table_translator.cc:90` applies `exp()` at query time. Pre-logging double-logs the value, flattens the dynamic range, and causes rank ties between high-frequency and low-frequency entries.
**Do this instead:** Store raw `tnc_freq * (variant_q / 100)` counts. See `scripts/merge_dict.py:149-169` for the reweight implementation and `scripts/merge_dict.py:155-162` for the explanatory comment.

### Setting `initial_quality` to a non-zero value

**What happens:** `translator: initial_quality: 1.0` (or any non-zero constant).
**Why it's wrong:** `initial_quality` is added to `exp(log_weight)` for every candidate. For raw-count weights with `log(1e8) ≈ 18.4`, `exp(weight - log(1e8))` is ~1e-3, so a constant of 1.0 dominates. Frequency differences get masked and ranking ties everywhere.
**Do this instead:** `initial_quality: 0` (`schema/thai_phonetic.schema.yaml:118-120`). Let the weights drive ranking.

### Using `make --silent` / `winget --silent` for the Weasel installer

**What happens:** `winget install Rime.Weasel --silent`.
**Why it's wrong:** Weasel ships an Inno Setup installer whose silent-mode handshake is incomplete; winget shows a spinner that never finishes (verified 2026-05-07 on the th-dc test bed).
**Do this instead:** `winget install --id Rime.Weasel --interactive --accept-source-agreements --accept-package-agreements` and let the user click through (`scripts/install-windows.ps1:110-117`).

### Probing for Weasel only at `C:\Program Files\Rime\Weasel\`

**What happens:** Hard-coding the unversioned path.
**Why it's wrong:** winget installs to a versioned subdirectory (e.g. `C:\Program Files\Rime\weasel-0.17.4\`); registry `InstallLocation` is blank; PATH is not modified. The unversioned path doesn't exist on a fresh Win 11 install.
**Do this instead:** Probe both `Program Files` and `Program Files (x86)` for `Rime\Weasel` and `Rime\weasel-*`, picking the newest versioned subdir. See `scripts/install-windows.ps1:62-76` and the same block in `scripts/install-librime-fork.ps1:75-89`.

### Relying on `WeaselDeployer.exe /deploy` to detect changed YAMLs by mtime alone

**What happens:** Copy schema YAMLs with rsync (preserves source mtime) and run `WeaselDeployer.exe /deploy`.
**Why it's wrong:** Rsync-preserved Mac timestamps can be older than the Weasel build dir's last build, so `WeaselDeployer` skips recompilation silently. The user sees "deploy succeeded" but the new dict isn't compiled.
**Do this instead:** After copying, set every `*.yaml` in `%APPDATA%\Rime\` to `LastWriteTime = now`, and when the schema content changed, also delete `%APPDATA%\Rime\build\thai_phonetic.*` to force a full rebuild (`scripts/install-windows.ps1:174-189`).

### Killing Squirrel without a timeout

**What happens:** `osascript -e 'tell application id "im.rime.inputmethod.Squirrel" to quit'` followed by `open -b im.rime.inputmethod.Squirrel`.
**Why it's wrong:** Either step can hang indefinitely (Squirrel can be in a state where it ignores the AppleEvent; `open` can race with the kill). The user's terminal locks up.
**Do this instead:** Wrap each step in `run_with_timeout 10` (perl-based, since macOS doesn't ship GNU `timeout`). On timeout, fall through to manual-Deploy instructions. See `scripts/install.sh:22-38` and `scripts/install.sh:96-117`.

### Distributing a forked librime on Linux

**What happens:** Shipping a patched `librime.so` alongside the schema for Linux.
**Why it's wrong:** Out of scope for Phase 1 — distros pin librime via apt/pacman; ABI compatibility across Ubuntu/Arch/Fedora is its own problem; the fork value (peek-sort patch) is one bug fix, not enough to justify the distribution surface.
**Do this instead:** Schema-only Linux install. Document the ranking caveat in the installer's trailing notice; revisit if Linux dogfood signal materializes (`scripts/install-linux.sh:160-176`).

## Error Handling

**Strategy:** Fail loudly with the exact remediation command. Every installer pre-flight check prints "ERROR: X is missing — install with: brew/winget/apt install Y" rather than degrading silently.

**Patterns:**
- `set -euo pipefail` at the top of every Bash installer (`scripts/install.sh:8`, `scripts/install-linux.sh:17`, `scripts/install-librime-fork.sh:31`, `scripts/build-macos-dmg.sh:16`).
- `$ErrorActionPreference = 'Stop'` at the top of every PowerShell installer (`scripts/install-windows.ps1:44`, `scripts/install-librime-fork.ps1:55`).
- Pre-flight checks before any filesystem mutation: host present, source files present, brew deps present (`scripts/install-librime-fork.sh:58-103`).
- Post-copy verification: re-stat every destination file to catch a silent `cp` failure (`scripts/install.sh:73-78`, `scripts/install-windows.ps1:194-200`).
- Timestamped backups before overwriting non-identical files (`scripts/install.sh:63-67`, `scripts/install-linux.sh:96-100`, `scripts/install-windows.ps1:156-168`).
- Auto-deploy steps are wrapped in OS-appropriate timeouts (10s perl on macOS, GNU `timeout` on Linux, `WaitForExit($ms)` on Windows) and degrade to manual-Deploy instructions on timeout, never block.
- `tests/test_dict.py` exits with `0`/`1`/`2` for pass/fail/setup-error (`tests/test_dict.py:30-33`).

## Cross-Cutting Concerns

**Logging:** Plain `echo` (Bash) / `Write-Host` (PowerShell) / `print` (Python) to stdout. No structured logging, no log files. Generation logs from `scripts/generate_*.py` go to stderr and are gitignored (`*.log` in `.gitignore`).

**Validation:**
- Bash syntax: `bash -n` on every installer in `tests/test_installers.py`.
- YAML shape: not validated programmatically — relies on Rime's deploy step to error.
- Dict body: `tests/test_dict.py` parses the TSV body line-by-line and asserts fixture pairs are present.
- Mach-O check: `install-librime-fork.sh` runs `file ... | grep -q "Mach-O"` before accepting a downloaded dylib (`scripts/install-librime-fork.sh:78-79`).
- SHA256: `install-windows.ps1` uses `Get-FileHash -Algorithm SHA256` to detect schema changes vs. mtime alone (`scripts/install-windows.ps1:157-158`).

**Authentication:**
- Anthropic API: `ANTHROPIC_API_KEY` env var, read by the `anthropic` SDK in `scripts/generate_words.py` and `scripts/generate_dict.py`.
- macOS sudo: prompted interactively in `install-librime-fork.sh` for the dylib swap; `SMOODLE_NONINTERACTIVE=1` skips the prompt for CI.
- Windows admin: `install-librime-fork.ps1` checks for elevation up front and bails with a copy-pasteable re-launch line if not elevated.
- GitHub: `gh` CLI used by `install-librime-fork.ps1` to download CI artifacts; user runs `gh auth login` once.

---

*Architecture analysis: 2026-05-08*
