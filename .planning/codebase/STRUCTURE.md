# Codebase Structure

**Analysis Date:** 2026-05-08

## Directory Layout

```
smoodle/
├── schema/                              # Rime YAML configuration (the only artifact this repo owns)
│   ├── thai_phonetic.schema.yaml        # Engine pipeline + speller.algebra (12 derive rules)
│   ├── thai_phonetic.dict.yaml          # 14893 words / 28239 TSV rows, TNC-weighted
│   └── default.custom.yaml              # Patches `schema_list` so thai_phonetic appears in switcher
│
├── scripts/                             # Installers, dict-build pipeline, dev helpers
│   ├── install.sh                       # macOS schema install (sudoless, ~/Library/Rime/)
│   ├── install-librime-fork.sh          # macOS librime dylib swap (sudo, /Library/Input Methods/Squirrel.app)
│   ├── install-linux.sh                 # Linux schema install (fcitx5/ibus autodetect)
│   ├── install-windows.ps1              # Windows schema install + WeaselDeployer auto-deploy
│   ├── install-librime-fork.ps1         # Windows rime.dll swap (admin)
│   ├── build-macos-dmg.sh               # Bundles installers into dist/smoodle-{ver}-macOS.dmg
│   ├── dev-sync-windows.sh              # rsync the working tree to th-dc Lane B Win 11 VM
│   ├── init_rime_testdir.sh             # Bootstrap /tmp/smoodle-rime-test for engine-mode tests
│   ├── generate_words.py                # Claude API → curated 500-word Thai list
│   ├── generate_dict.py                 # Claude API → romanization variant TSV (resumable)
│   ├── merge_dict.py                    # Union+max-weight merge, TNC-freq reweight, write Rime dict YAML
│   ├── tnc_freq.txt                     # PyThaiNLP Thai National Corpus unigram freqs (CC0)
│   ├── words-example.txt                # 50-word seed list (manual)
│   ├── words-500.txt                    # 500-word curated list (generate_words.py output)
│   ├── words-tnc.txt                    # 2k-word TNC-derived list
│   ├── words-tnc-full.txt               # 12k-word full TNC freq>=50 tail
│   ├── generated-example.tsv            # Variant TSV for words-example.txt
│   ├── generated-500.tsv                # Variant TSV for words-500.txt
│   ├── generated-tnc.tsv                # Variant TSV for words-tnc.txt
│   └── generated-tnc-full.tsv           # Variant TSV for words-tnc-full.txt
│
├── tests/                               # stdlib-only Python tests, no pytest dep
│   ├── test_dict.py                     # Dict correctness — string-match + engine mode
│   ├── test_installers.py               # 17 active + 5 stubbed installer cases
│   ├── v001_fixture.yaml                # v0.0.1 fixture (~50 entries)
│   └── v01_fixture.yaml                 # v0.1 fixture (56 entries: 35 direct + 21 algebra-tagged)
│
├── docs/                                # Long-form planning + per-lane execution docs
│   ├── PHASE1-PROMPT.md                 # Active execution plan (Phase 1)
│   ├── RESUME.md                        # Architecture, file map, librime patch internals, "don't do" list
│   ├── CI-REFACTOR-PROMPT.md            # CI workflow refactor plan
│   ├── LANE-B-WINDOWS.md                # Windows installer dogfood lane reference
│   ├── LANE-B-HARDENING-PROMPT.md       # Lane B hardening tasks
│   ├── LANE-C-LINUX.md                  # Linux installer dogfood lane reference
│   └── LANE-C-E2E-PROMPT.md             # Lane C end-to-end test plan
│
├── infra/                               # Test-bed infra (not shipped to users)
│   └── lane-b-windows/
│       ├── docker-compose.yml           # dockur/windows Win 11 KVM VM on th-dc
│       └── README.md                    # Lane B test-bed access + dev loop
│
├── vendor/                              # Vendored deps — gitignored except patches/README/windows binary
│   ├── README.md                        # How to clone librime + apply patch
│   ├── librime-1.16.0-peek-sort.patch   # Historical: now upstreamed into smoodle-type/librime
│   ├── librime/                         # gitignored upstream librime checkout (~2 GB after build)
│   └── windows/
│       └── rime.dll                     # Pre-built Weasel-compatible patched DLL (offline-install fallback)
│
├── .github/
│   └── workflows/
│       └── install-linux-e2e.yml        # ubuntu-latest job: ibus-rime + Linux installer + verify
│
├── build/                               # gitignored — Python build artifacts (currently empty)
├── dist/                                # gitignored — DMG output (smoodle-{version}-macOS.dmg)
├── .planning/                           # GSD planning docs (this file lives here)
├── .omc/                                # oh-my-claudecode runtime state, gitignored
├── .claude/                             # Claude Code session state, gitignored
│
├── README.md                            # Quick-start install + test commands; tracked
├── TODOS.md                             # Outstanding work outside the active milestone; tracked
├── LICENSE                              # MIT for smoodle's own code
└── .gitignore                           # Notably gitignores .env, .omc/, .claude/, vendor/* (with allowlist)
```

## Directory Purposes

**`schema/`:**
- Purpose: The only artifact this repo owns. Three Rime YAMLs that constitute the entire IME behavior.
- Contains: One schema, one dictionary, one schema-list patch.
- Key files: `thai_phonetic.schema.yaml` (engine pipeline + 12 algebra rules), `thai_phonetic.dict.yaml` (~1.2 MB Rime native dict), `default.custom.yaml` (510-byte schema_list patch).

**`scripts/`:**
- Purpose: Two distinct toolchains — (a) platform installers + DMG bundler, (b) the dict-build pipeline.
- Contains: 5 platform installers (3 Bash, 2 PowerShell), 2 helper Bash scripts (DMG bundler, dev-sync), 1 test bootstrap, 3 Python pipeline scripts (generate_words, generate_dict, merge_dict), 4 word lists, 4 generated variant TSVs, 1 TNC freq table.
- Key files: `install.sh`, `install-linux.sh`, `install-windows.ps1`, `install-librime-fork.sh`, `install-librime-fork.ps1`, `build-macos-dmg.sh`, `merge_dict.py`.

**`tests/`:**
- Purpose: Catch romanization typos, missing variants, ranking regressions, installer drift. Stdlib-only Python so it runs out-of-the-box on Python 3.10+ with no `pip install`.
- Contains: Two test scripts, two fixtures, no `__init__.py` (the scripts are invoked directly).
- Key files: `test_dict.py` (`--use-rime-api-console` flag toggles engine mode), `test_installers.py`, `v01_fixture.yaml` (current canonical fixture).

**`docs/`:**
- Purpose: Long-form planning + per-lane execution prompts. Not user-facing; consumed by humans + agents during planning sessions.
- Contains: One active execution plan (`PHASE1-PROMPT.md`), one architecture deep-dive (`RESUME.md`), one CI refactor plan, four per-lane docs (Lane B Windows, Lane C Linux, hardening, E2E).
- Key files: `PHASE1-PROMPT.md`, `RESUME.md`.

**`infra/`:**
- Purpose: Test-bed infrastructure (developer-facing only). Provisions the Win 11 VM that Lane B installer dogfood runs against.
- Contains: One `docker-compose.yml` for `dockur/windows` on the `th-dc` remote docker context, one README explaining access (Web VNC at `:8006`, RDP at `:3389`).
- Key files: `lane-b-windows/docker-compose.yml`.

**`vendor/`:**
- Purpose: Vendored upstream deps. Source trees are gitignored (huge); only patches, READMEs, and one pre-built binary are tracked.
- Contains: `librime/` (gitignored ~2 GB checkout, fetched on demand), the historical peek-sort patch, `windows/rime.dll` (2.9 MB, the offline-install fallback for Lane B).
- Key files: `librime-1.16.0-peek-sort.patch`, `windows/rime.dll`.

**`.github/workflows/`:**
- Purpose: GitHub Actions CI — currently only the Lane C Linux installer e2e job.
- Contains: One workflow.
- Key files: `install-linux-e2e.yml`.

**`build/`, `dist/`:**
- Purpose: Build outputs. `dist/` holds DMG releases, `build/` is reserved for future Python build artifacts.
- Contains: gitignored. `dist/` typically holds `smoodle-{version}-macOS.dmg` after `scripts/build-macos-dmg.sh` runs.

**`.planning/`:**
- Purpose: GSD (get-stuff-done) workflow planning artifacts. This file lives here.
- Contains: `codebase/` (codebase-mapping outputs).

**`.omc/`, `.claude/`:**
- Purpose: Local agent runtime state. Gitignored.

## Key File Locations

**Entry Points:**
- `scripts/install.sh`: macOS schema installer; reads `schema/`, writes `~/Library/Rime/`, restarts Squirrel under timeout.
- `scripts/install-librime-fork.sh`: macOS librime dylib downloader/builder + sudo swap.
- `scripts/install-linux.sh`: Linux schema installer; autodetects fcitx5/ibus, writes per-IM dir, reloads daemon.
- `scripts/install-windows.ps1`: Windows schema installer; auto-installs Weasel via winget, runs WeaselDeployer.
- `scripts/install-librime-fork.ps1`: Windows rime.dll downloader (gh CLI from CI artifact) + admin swap.
- `scripts/build-macos-dmg.sh`: DMG bundler for non-CLI dogfood users.
- `tests/test_dict.py`: Dict correctness test entry point.
- `tests/test_installers.py`: Installer test entry point.

**Configuration:**
- `schema/thai_phonetic.schema.yaml`: Engine pipeline, speller algebra, translator settings.
- `schema/default.custom.yaml`: Rime schema_list patch.
- `.gitignore`: Notably gitignores `vendor/*` with allowlist for `vendor/*.patch`, `vendor/README.md`, `vendor/windows/`.

**Core Logic:**
- `schema/thai_phonetic.dict.yaml`: 14893 Thai words / 28239 entries with TNC-weighted variants.
- `scripts/merge_dict.py`: Dict merge + TNC reweight; the canonical place where the weight formula `tnc_freq * (variant_q / 100)` is applied.
- `scripts/generate_dict.py`: Claude-API caller producing romanization variant TSVs; the only file that knows the LLM prompt and the algebra-equivalence rules to omit.

**Testing:**
- `tests/v01_fixture.yaml`: 56 (`romanization`, `expected_thai`, `via?`) assertions.
- `scripts/init_rime_testdir.sh`: Sets up `/tmp/smoodle-rime-test` with smoodle's schema + Squirrel preset configs (`default.yaml`, `punctuation.yaml`, `symbols.yaml`, `key_bindings.yaml`); patches `schema_list` to just `thai_phonetic`.

**Reference / Planning:**
- `README.md`: User-facing quick-start (macOS dogfood path).
- `docs/RESUME.md`: Long-form architecture, librime patch internals, "don't do" list. Most authoritative reference.
- `docs/PHASE1-PROMPT.md`: Active execution plan; Phase 1 sequencing + decision-gate criteria.
- `TODOS.md`: Outstanding work outside the active milestone.

## Naming Conventions

**Files:**

- **Schema YAMLs:** `<schema_id>.<kind>.yaml` → `thai_phonetic.schema.yaml`, `thai_phonetic.dict.yaml`. Mandated by Rime; the `schema_id` field at `schema/thai_phonetic.schema.yaml:10` matches the filename stem.
- **Schema patch:** `<target>.custom.yaml` → `default.custom.yaml`. Mandated by Rime: a `default.custom.yaml` patches the global `default.yaml`.
- **Bash installers:** `install[-<platform>].sh` → `install.sh` (macOS, the original), `install-linux.sh`, `install-librime-fork.sh`. Macros: kebab-case for the descriptor, lowercase.
- **PowerShell installers:** `install-<platform>.ps1` → `install-windows.ps1`, `install-librime-fork.ps1`. Same kebab-case, `.ps1` extension.
- **Helper scripts:** `<verb>-<thing>.sh` → `build-macos-dmg.sh`, `dev-sync-windows.sh`, `init_rime_testdir.sh` (the last one uses underscores because it predates the kebab-case convention).
- **Python pipeline scripts:** `<verb>_<thing>.py` → `generate_words.py`, `generate_dict.py`, `merge_dict.py`. snake_case.
- **Test scripts:** `test_<thing>.py` → `test_dict.py`, `test_installers.py`. snake_case, `test_` prefix.
- **Fixtures:** `v<version>_fixture.yaml` → `v001_fixture.yaml`, `v01_fixture.yaml`. Tracks the dict version they were authored against.
- **Generated word lists:** `words-<scope>.txt` → `words-example.txt`, `words-500.txt`, `words-tnc.txt`, `words-tnc-full.txt`. kebab-case scope tag.
- **Generated variant TSVs:** `generated-<scope>.tsv` → mirrors the word-list naming.
- **Generated logs:** `generated-<scope>.log`, `generation.log`, `generate-tnc-full.log`. Gitignored (`*.log`).
- **Docs:** `<TOPIC>[-<SUBTOPIC>].md` in SHOUT-CASE → `PHASE1-PROMPT.md`, `RESUME.md`, `LANE-B-WINDOWS.md`, `LANE-C-LINUX.md`, `CI-REFACTOR-PROMPT.md`. Top-level `README.md`, `TODOS.md`, `LICENSE` follow the same convention.
- **Patches:** `<package>-<version>-<topic>.patch` → `librime-1.16.0-peek-sort.patch`.
- **DMG output:** `smoodle-{version}-macOS.dmg` where `{version}` is `git describe --tags --always --dirty`.

**Directories:**

- All directories are lowercase, no underscores or hyphens, with one exception:
  - `lane-b-windows/` (kebab-case) inside `infra/` — matches the Lane name from `docs/LANE-B-WINDOWS.md`.
- Standard top-level dirs: `schema/`, `scripts/`, `tests/`, `docs/`, `infra/`, `vendor/`, `build/`, `dist/`.
- Tooling-private dirs are dotted: `.github/`, `.planning/`, `.omc/`, `.claude/`, `.pytest_cache/`.

**Variables and env overrides:**

- Every installer accepts an `SMOODLE_*` env override family. Conventions:
  - `SMOODLE_RIME_DIR` — schema destination dir.
  - `SMOODLE_SQUIRREL_PATH` / `SMOODLE_WEASEL_PATH` — IME host install dir.
  - `SMOODLE_AUTO_DEPLOY=0` — skip the deploy-and-restart block (used by tests).
  - `SMOODLE_DEPLOY_TIMEOUT_SECS` — bound the deploy step.
  - `SMOODLE_IM` — Linux IM autodetect override (`fcitx5` or `ibus`).
  - `SMOODLE_LIBRIME_FORK_TAG`, `SMOODLE_LIBRIME_FORK_URL`, `SMOODLE_LIBRIME_FORK_REPO`, `SMOODLE_LIBRIME_FORK_RUN_ID`, `SMOODLE_LIBRIME_VARIANT` — fork-build/download knobs.
  - `SMOODLE_SKIP_DOWNLOAD`, `SMOODLE_SKIP_BUILD`, `SMOODLE_SKIP_SWAP`, `SMOODLE_FORCE_REBUILD`, `SMOODLE_NONINTERACTIVE` — installer-stage toggles (string `"1"` for true).
  - `SMOODLE_TH_DC_HOST`, `SMOODLE_TH_DC_SHARE`, `SMOODLE_RSYNC_DRY_RUN` — `dev-sync-windows.sh` overrides.

## Where to Add New Code

**New Thai words / dict expansion:**
- Source list: append to `scripts/words-tnc-full.txt` (or create `scripts/words-<scope>.txt` for a new corpus).
- Generation: `python scripts/generate_dict.py --words scripts/words-<scope>.txt --output scripts/generated-<scope>.tsv`. Resumable.
- Merge: `python scripts/merge_dict.py --base schema/thai_phonetic.dict.yaml --add scripts/generated-<scope>.tsv --tnc-freq scripts/tnc_freq.txt --output schema/thai_phonetic.dict.yaml`.
- Test: `python3 tests/test_dict.py` (string-match) and `python3 tests/test_dict.py --use-rime-api-console` (engine mode).

**New algebra rule:**
- Edit `speller.algebra` in `schema/thai_phonetic.schema.yaml:84-110`. Order matters; rules apply left-to-right.
- Add an algebra-tagged fixture entry to `tests/v01_fixture.yaml` with `via: <rule-name>`.
- Run engine-mode test: `python3 tests/test_dict.py --use-rime-api-console`.
- Update `scripts/generate_dict.py`'s `SYSTEM_PROMPT` (search for "ALGEBRA" / "kh ~ k") so future LLM runs don't emit redundant variants.

**New platform installer:**
- Add `scripts/install-<platform>.sh` (or `.ps1`) following the existing shape:
  1. `set -euo pipefail` / `$ErrorActionPreference = 'Stop'` at top.
  2. Resolve repo dir from `BASH_SOURCE[0]` / `$MyInvocation.MyCommand.Path`.
  3. Read `SMOODLE_RIME_DIR` env override; default to platform-canonical user Rime dir.
  4. Pre-flight: assert host IME present; print `brew/winget/apt install` line on miss.
  5. Copy three YAMLs from `schema/` with timestamped backup of non-identical existing files.
  6. Post-copy verify each destination file exists.
  7. Auto-deploy under timeout; degrade to manual-Deploy instructions on failure.
  8. Print test instructions inline.
- Add a class to `tests/test_installers.py` with shape checks (file exists, syntax valid, declares the `SMOODLE_*` env overrides).
- Optionally add a CI workflow under `.github/workflows/install-<platform>-e2e.yml`.

**New helper script:**
- Place in `scripts/`. Use kebab-case for shell scripts (`scripts/<verb>-<thing>.sh`), snake_case for Python (`scripts/<verb>_<thing>.py`).
- Self-contained: stdlib + `bash`/`perl` only for shell, stdlib + `anthropic` only for the LLM scripts.
- Document the env overrides in the script's header comment.

**New test:**
- Place in `tests/`. Follow `test_<thing>.py` naming.
- stdlib only. No pytest, no PyYAML — `tests/test_dict.py:73-91` uses regex parsing for the fixture YAML to avoid the dep.
- Run via `python3 tests/test_<thing>.py` directly. Exit 0/1/2 for pass/fail/setup-error.

**New planning doc:**
- Place in `docs/<TOPIC>.md` in SHOUT-CASE. Use `<TOPIC>-PROMPT.md` for execution plans, plain `<TOPIC>.md` for reference docs.
- Cross-link from `README.md`'s "In-repo source-of-truth" list and from `docs/RESUME.md` if architecturally relevant.

**New CI workflow:**
- Place in `.github/workflows/<lane>-<scope>.yml` (e.g. `install-linux-e2e.yml`).
- Trigger on `push` and `pull_request` with `paths:` filters scoped to the relevant scripts/schema files.
- Use `SMOODLE_AUTO_DEPLOY=0` in CI to skip the daemon-restart block (no display in headless CI).

**Vendored binary (Windows only):**
- `vendor/windows/rime.dll` is the only tracked binary. Replace by overwriting and committing. Update the comment block in `scripts/install-librime-fork.ps1` describing where it came from (the `smoodle-build` CI run id).

## Special Directories

**`vendor/librime/`:**
- Purpose: Upstream librime checkout (or smoodle-type fork checkout).
- Generated: Yes — `scripts/install-librime-fork.sh` clones it on demand from `https://github.com/smoodle-type/librime.git` at tag `1.16.0-smoodle.1`.
- Committed: No — gitignored (`.gitignore:18-19`). Only `vendor/*.patch`, `vendor/README.md`, and `vendor/windows/` are allowlisted.

**`vendor/windows/`:**
- Purpose: Pre-built Weasel-compatible patched `rime.dll` for offline-install fallback in `scripts/install-librime-fork.ps1`.
- Generated: Built by the smoodle-type/librime `smoodle-build` CI workflow.
- Committed: Yes — explicitly allowlisted in `.gitignore:22-24` (`!vendor/windows/`, `vendor/windows/*` denied, `!vendor/windows/rime.dll` allowed).

**`build/`, `dist/`:**
- Purpose: Build outputs. `dist/` is the canonical DMG output dir.
- Generated: Yes (`scripts/build-macos-dmg.sh`).
- Committed: No — gitignored (`.gitignore:14-15`).

**`scripts/generated-*.tsv` and `scripts/words-*.txt`:**
- Purpose: Reproducible inputs to the dict-build pipeline. The full LLM run is expensive; the TSVs preserve it.
- Generated: Yes (`scripts/generate_words.py`, `scripts/generate_dict.py`).
- Committed: Yes — these are checked in so `merge_dict.py` can rebuild the dict deterministically without re-running the LLM.

**`scripts/tnc_freq.txt`:**
- Purpose: PyThaiNLP Thai National Corpus unigram frequencies (CC0-1.0). The frequency reweighting reads this.
- Generated: No (one-time download from PyThaiNLP).
- Committed: Yes — 1.6 MB tracked file.

**`scripts/*.log`, `.generation.log`:**
- Purpose: Raw stderr from `scripts/generate_*.py` runs.
- Generated: Yes.
- Committed: No — gitignored (`*.log` in `.gitignore:7`).

**`.planning/`:**
- Purpose: GSD codebase-mapping outputs (this file lives here at `.planning/codebase/STRUCTURE.md`).
- Generated: Yes (by codebase-mapper agent).
- Committed: Decided per-project; currently tracked.

**`.omc/`, `.claude/`, `.pytest_cache/`, `__pycache__/`, `.env`:**
- Purpose: Tooling-local state.
- Generated: Yes.
- Committed: No — gitignored.

---

*Structure analysis: 2026-05-08*
