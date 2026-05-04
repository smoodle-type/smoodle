# smoodle — session handoff

Paste / read this at the start of a new Claude Code session to resume work
on smoodle. The long-form context lives in the design doc and the eng-review
test plan; this file is a map, not a full re-explanation.

## What smoodle is

A Pinyin-style phonetic input method for typing Thai on macOS. Type
`sawadee` → see candidate `สวัสดี` → press space to commit. v0.0.x ships as
a Rime schema running inside Squirrel; v0.2 will add a custom librime C++
translator plugin that calls a local LLM (llama.cpp, Qwen 1.8B Q4) for
out-of-dictionary disambiguation and tone synthesis.

User intent: builder/learning project. The technical challenge — librime
plugin development + the LLM-as-translator integration — is the explicit
draw, not shipping speed.

## Where the long-form context lives — READ THESE FIRST

- **Design doc:** `~/.gstack/projects/smoodle/lex-main-design-20260503-163327.md`
  Revision 4 (post Rime/Squirrel pivot). 1217 lines. Has architecture
  diagrams, milestone breakdowns with sub-tasks, key technical decisions,
  success criteria, distribution plan, and reviewer concerns.
- **Eng review test plan:** `~/.gstack/projects/smoodle/lex-main-eng-review-test-plan-20260503.md`
- **Commit history:** `git log --oneline` — each commit message is verbose
  on purpose. Read them in order to understand evolution of the dict, the
  algebra layer, the test infrastructure.

## State as of last session

Branch: `main`. v0.0.2 milestone (algebra + 600-word dict + librime
CLI test) committed. v0.1 fixture exists with 56 entries; engine test
runs end-to-end in ~2s.

```
d2812ec Wire librime CLI test: end-to-end engine pipeline coverage (56/56 pass)
c454a6f Add v0.1 fixture (56 entries: 35 direct + 21 algebra-tagged)
6b68a99 v0.0.2: dict scaled to 601 Thai words / 1193 entries (Path A)
b405383 v0.0.2: speller/algebra for Thai phonemic equivalence (Path A)
824691e Add docs/RESUME.md for cross-session handoff
390688b v0.0.1 dict expanded to 30 Thai words / 125 entries
ee0b678 v0.0.1 stub: thai_phonetic schema + 10-word dict + install script
```

The v0.0.1 sub-tasks 0-7 are all complete (manual Squirrel verification
included). Sub-tasks 1-3 of v0.1 (algebra rules + 50-entry fixture +
librime-driven acceptance test) are also complete.

## Architecture (do not relitigate without strong reason)

- **Foundation: Rime/Squirrel, NOT a McBopomofo Swift IMK fork.**
- **Library validation: not a blocker** (verified). Squirrel.app has
  `com.apple.security.cs.disable-library-validation: true`.
- **librime version pinned: 1.16.0** (matches Squirrel 1.1.2). Built
  locally at `vendor/librime/` (gitignored). Plugin (v0.2) must compile
  against this exact version.
- **Multi-syllable Thai uses continuous Latin (no internal spaces):**
  `khobkhun` not `khob khun` — Rime's `table_translator` treats space
  as commit delimiter. See commit 4b54bc3.
- **Path A (algebra-thin dict):** speller.algebra rules collapse common
  phonemic equivalence (kh~k, ph~p, th~t, vowel length, p~b/t~d at end)
  so the dict carries 1-3 variants per Thai word instead of 4-5. Confirmed
  end-to-end via librime CLI.
- **Algebra is single-pass.** Each `derive/X/Y/` rule applies to the
  FIRST regex match per dict spelling. So `derive/kh/k/` against
  `khopkhun` yields `kopkhun` (not `khopkun` or `kopkun`); to reach
  `kopkun` Rime needs another dict entry whose single-pass derivation
  gets there. Worked example: `khopkun` is NOT in the prism, but
  `kopkun` reaches ขอบคุณ via `kobkun` (dict) + algebra. Document this
  before adding new derive rules so you don't expect iterative behavior.

## File map

```
smoodle/
├── README.md
├── .gitignore                    # ignores vendor/, .env, .claude/, *.log
├── docs/
│   └── RESUME.md                 # this file
├── schema/
│   ├── thai_phonetic.schema.yaml # Rime schema + speller.algebra rules
│   ├── thai_phonetic.dict.yaml   # 601 Thai words / 1193 entries
│   └── default.custom.yaml       # registers schema in Squirrel's switcher
├── scripts/
│   ├── install.sh                # copies schema/ → ~/Library/Rime/
│   ├── init_rime_testdir.sh      # bootstraps /tmp/smoodle-rime-test for CLI test
│   ├── generate_dict.py          # Claude-API per-word variant generator (slim prompt)
│   ├── generate_words.py         # Claude-API one-off categorized word-list generator
│   ├── merge_dict.py             # union-with-max-weight merger (TSV → dict YAML)
│   ├── words-example.txt         # 30-word seed (still here for reference)
│   ├── words-500.txt             # 601-word categorized list (16 categories)
│   ├── generated-example.tsv     # raw LLM output for words-example.txt
│   └── generated-500.tsv         # raw LLM output for words-500.txt
├── tests/
│   ├── v001_fixture.yaml         # original 30-entry v0.0.1 acceptance fixture
│   ├── v01_fixture.yaml          # 56 entries (35 direct + 21 algebra-tagged)
│   └── test_dict.py              # dual-mode driver: string-match OR engine
└── vendor/                       # gitignored; clone librime here
    └── librime/                  # 1.16.0 source + build/
```

## Test infrastructure

```bash
# String-match mode (fast, no librime needed)
python3 tests/test_dict.py --fixture tests/v001_fixture.yaml
python3 tests/test_dict.py --fixture tests/v01_fixture.yaml

# Engine mode (drives librime via rime_api_console; ~2s for 56 entries)
bash scripts/init_rime_testdir.sh           # one-time setup of /tmp/smoodle-rime-test
python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml
```

The engine test refreshes /tmp/smoodle-rime-test from the repo on every
run, so iteration is just edit-fixture → re-run.

## Critical caveats

- **`.env` contains relay credentials** (`ANTHROPIC_CUSTOM_BASE_URL` +
  `ANTHROPIC_CUSTOM_AUTH_TOKEN` for `crs.0dl.me/api`). Gitignored.
  Token can be rotated at the relay's admin panel. The generator scripts
  read `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL` from env — must
  re-export from `ANTHROPIC_CUSTOM_*` (see Quick start below).
- **vendor/librime/ is ~2 GB** after build. Gitignored. Re-clone with
  `git clone --recurse-submodules https://github.com/rime/librime.git
  vendor/librime && cd vendor/librime && git checkout 1.16.0 &&
  git submodule update --init --recursive` if missing.
- **Brew deps for librime build:** cmake, boost, leveldb, marisa,
  yaml-cpp, opencc, googletest, pkg-config, ninja, glog. All installed.
- **Don't archive Squirrel, agents, or environments.** Permanent.
- **Don't auto-merge generated dict output.** ~5% may need Thai-speaker review.

## What's likely next (pick one)

1. **Deploy + dogfood the 1193-entry dict.** Click Squirrel's Deploy,
   type Thai for a few days, report OOV / weird candidates / weak
   spots. The dict has been engine-tested but has not seen real human
   typing yet.
2. **Sample-mine the dict for more algebra-only test cases.** Run
   the prober against more rule combinations, expand v01_fixture beyond
   56 entries, find dict entries that fail the engine test (e.g. words
   where the LLM-generated romanization disagrees with how a typer
   would actually spell it).
3. **v0.2 Sub-task 1 (the eureka layer):** vendor/librime is built;
   `make` against its headers + dylib should produce a hello-world
   plugin dropped into Squirrel's `Frameworks/rime-plugins/`. The
   reference dylibs are `librime-lua.dylib`, `librime-octagram.dylib`,
   `librime-predict.dylib` — read their source for plugin ABI patterns.
   Also check `rime-llm-translator` on AUR (Linux); may be portable.
4. **Ship v0.0.2 milestone:** push to GitHub, post a release with
   `smoodle-config-0.0.2.zip` (just the schema/ dir), gather first
   external feedback.
5. **Frequency-tune dict weights.** Currently every "canonical" variant
   is weight 100, so candidate ranking ties on alphabetical order. Real
   word-frequency data would let high-frequency words rank above
   homographs. PyThaiNLP TNC is Apache 2.0-adjacent (license check
   pending — see Open Question 1 in design doc).
6. **Address candidate-ordering edge cases surfaced by engine test:**
   - `yai` → ยาย (1) vs ใหญ่ (2) — both are common; user wants "big"
     to outrank "grandma" or vice versa? Real-typing-frequency would
     fix this.
   - `pi` → พี่ (1) vs ปี (2)
   - `mu` → หมู (1) vs มือ (2)

## Open questions still on deck (from design doc)

1. PyThaiNLP corpus license check before shipping a frequency-aware dict.
2. Verify `librime-predict.dylib`'s actual async behavior.
3. v0.2 plugin must handle stale-result drop AND cooperative cancellation
   via `ggml_abort_callback`.
4. macOS Gatekeeper acceptance test on a clean machine before announcing.

## Quick start commands

```bash
cd /Users/lex/Dev/my_repos/experiment/smoodle

# Run all fixture tests (string + engine)
python3 tests/test_dict.py --fixture tests/v001_fixture.yaml
python3 tests/test_dict.py --fixture tests/v01_fixture.yaml
bash scripts/init_rime_testdir.sh
python3 tests/test_dict.py --fixture tests/v01_fixture.yaml --use-rime-api-console

# Re-install schema to ~/Library/Rime/ (then click Squirrel's Deploy)
bash scripts/install.sh

# Generate variants for a single Thai word (debug)
set -a; . ./.env; set +a
export ANTHROPIC_API_KEY="$ANTHROPIC_CUSTOM_AUTH_TOKEN"
export ANTHROPIC_BASE_URL="$ANTHROPIC_CUSTOM_BASE_URL"
python3 scripts/generate_dict.py --word "ขอบคุณ" --debug

# Bulk generation against a word list (resumable)
python3 scripts/generate_dict.py \
  --words scripts/words-500.txt \
  --output scripts/generated-500.tsv

# Merge a TSV into the live dict
python3 scripts/merge_dict.py \
  --base schema/thai_phonetic.dict.yaml \
  --add scripts/generated-500.tsv \
  --output schema/thai_phonetic.dict.yaml
```

## Don't do

- Don't add `output_format` to API calls — deprecated. Use `output_config.format`.
- Don't add `temperature` / `top_p` / `budget_tokens` on Opus 4.7 — all 400.
- Don't add tone marks to romanization variants. Tones live in Thai output only.
- Don't expect Rime's algebra to apply iteratively — it's single-pass per
  rule (first regex match only). Add explicit dict entries OR additional
  derive rules with different anchoring if you need multi-position cover.
- Don't change the architecture from Rime/Squirrel without a Step 0
  scope challenge with the user. Flag concerns; user decides.
