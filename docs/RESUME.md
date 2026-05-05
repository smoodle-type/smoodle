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

Branch: `main`. **v0.0.3 committed and live in Squirrel.** Dict at 2101
Thai words / 4050 entries, TNC-frequency-weighted. Engine test passes
56/56. Required librime patch applied to vendored build AND swapped into
Squirrel.app. User confirmed `yai → ใหญ่ #1` in real Squirrel typing;
the previously-inverted ranking is fixed. Dogfood is live but no
substantive usage feedback collected yet beyond that one probe.

**The librime Peek-sort patch** fixes an upstream bug:
`DictEntryIterator::Peek()` returned `chunks[0]` without sorting on the
first call. Chunks were pushed in syllable-id order (alphabetical of
syllable strings). When an algebra-derived spelling like `yaai`→`yai`
shared input with a direct `yai` entry, the alphabetically-earlier
syllable's chunk won position #1 regardless of weight. The patch calls
`Sort()` once before the first Peek, gated by a `sorted_initial_` flag.
Saved as `vendor/librime-1.16.0-peek-sort.patch`. Worth filing upstream.

**Squirrel.app dylib swap.** Squirrel ships its own bundled
`librime.1.dylib` (universal x86_64+arm64, 7.2MB). We replaced it with
our patched arm64-only build (2.5MB) — Squirrel has the
`cs.disable-library-validation` entitlement, so it loads the
differently-signed dylib without complaint. Original is preserved at
`/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib.smoodle-backup`.
Two caveats:
  - Sparkle auto-update from Rime project could overwrite the patch.
    Watch for that. Reapply via:
    ```
    sudo cp /Users/lex/Dev/my_repos/experiment/smoodle/vendor/librime/build/lib/librime.1.16.0.dylib \
            "/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib"
    ```
  - This machine is Apple Silicon. The arm64-only swap-in would break
    Squirrel on Intel Macs (the bundled binary is universal; ours
    isn't). For shipping a release, either build universal librime or
    flip to a Path B dict (no algebra → no bug → no patch needed).

Recent commits (v0.0.3 series):
```
6eb359c RESUME.md: refresh for v0.0.3 + librime patch
666c745 v0.0.3: scale dict to 2101 Thai words, TNC-frequency-weighted ranking
f7153cf Pipeline: parallel romanization + TNC frequency reweighting
67bc08b Patch librime DictEntryIterator::Peek first-call sort
363d481 RESUME.md: note dogfood is live, awaiting feedback
3977246 RESUME.md: refresh after v0.1 fixture + librime CLI wiring
d2812ec Wire librime CLI test: end-to-end engine pipeline coverage (56/56 pass)
c454a6f Add v0.1 fixture (56 entries: 35 direct + 21 algebra-tagged)
6b68a99 v0.0.2: dict scaled to 601 Thai words / 1193 entries (Path A)
b405383 v0.0.2: speller/algebra for Thai phonemic equivalence (Path A)
```

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
- **Algebra rules replace ALL occurrences in one pass.** Earlier RESUME
  notes claimed "single-pass = first match only" — that was wrong.
  `boost::regex_replace` (calculus.cc) replaces every match. So
  `derive/kh/k/` against `khopkhun` yields `kopkun` (both kh's gone),
  not `kopkhun` or `khopkun`. Verified directly with rime_api_console.
- **Rime weights are log-frequencies.** `dict_compiler.cc:257`
  applies `log()` to the dict's raw weight at compile time;
  `table_translator.cc:90` applies `exp()` at query time. Store RAW
  counts in the dict YAML — pre-logging double-logs and flattens
  rank differences to noise. Reference dicts use percentages (`100%`,
  `50%`) which scale a preset_vocabulary's pre-logged weight.
- **DictEntryIterator first-Peek bug** (see "Required librime patch"
  in State above). Chunks are pushed in syllable-id order, sorted only
  on subsequent calls. When algebra-derived and direct spellings share
  an input, the alphabetically-earlier syllable wins #1 regardless of
  weight unless patched. We patch the vendored librime; upstream PR
  worth filing.

## File map

```
smoodle/
├── README.md
├── .gitignore                    # ignores vendor/, .env, .claude/, *.log
├── docs/
│   └── RESUME.md                 # this file
├── schema/
│   ├── thai_phonetic.schema.yaml # Rime schema, v0.0.3 (initial_quality: 0)
│   ├── thai_phonetic.dict.yaml   # 2101 Thai words / 4050 entries, TNC-weighted
│   └── default.custom.yaml       # registers schema in Squirrel's switcher
├── scripts/
│   ├── install.sh                # copies schema/ → ~/Library/Rime/
│   ├── init_rime_testdir.sh      # bootstraps /tmp/smoodle-rime-test for CLI test
│   ├── generate_dict.py          # Claude-API variant generator (slim prompt, --workers N)
│   ├── generate_words.py         # Claude-API one-off categorized word-list generator
│   ├── merge_dict.py             # merger with --tnc-freq reweighting (v0.0.3+)
│   ├── words-example.txt         # 30-word seed (still here for reference)
│   ├── words-500.txt             # 601-word categorized list (v0.0.2)
│   ├── words-tnc.txt             # top 1500 new words by TNC freq (v0.0.3)
│   ├── tnc_freq.txt              # PyThaiNLP TNC unigram (CC0, ~106k entries)
│   ├── generated-example.tsv     # raw LLM output for words-example.txt
│   ├── generated-500.tsv         # raw LLM output for words-500.txt
│   └── generated-tnc.tsv         # raw LLM output for words-tnc.txt (1500 words)
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
  git submodule update --init --recursive` if missing. **Then re-apply
  the Peek-sort patch** (see "Required librime patch" above): one block
  in `src/rime/dict/dictionary.cc` Peek + a `sorted_initial_` field in
  `dictionary.h`. Without it, ranking is wrong for any input where an
  algebra-derived spelling collides with a direct one.
- **Brew deps for librime build:** cmake, boost, leveldb, marisa,
  yaml-cpp, opencc, googletest, pkg-config, ninja, glog. All installed.
- **Don't archive Squirrel, agents, or environments.** Permanent.
- **Don't auto-merge generated dict output.** ~5% may need Thai-speaker review.

## What's likely next (pick one)

The primary bottleneck before more infrastructure work is **dogfood
feedback**. Squirrel is running the patched librime + 2101-word dict.
The user has confirmed `yai → ใหญ่` works; nothing else has been
typed in real use yet. **The next session should ask "how did the
dogfood go?" first** before picking from the list below.

1. **Triage dogfood feedback.** If the user reports OOV, romanization
   mismatches, or unexpected ranking, fix-now (dict edits, more LLM
   variants, manual weight bumps) vs defer (corpus replacement, v0.2
   scope). Concrete watch-fors:
   - OOV on names / slang / recent loanwords (TNC is formal-corpus-biased)
   - Wrong romanization (user types `kafe` but dict only has `kafae`)
   - Rankings that the user disagrees with despite TNC saying otherwise
     (e.g. `kao → เขา` over ข้าว — freq-correct but maybe intent-wrong)
2. **File upstream PR** for the librime `DictEntryIterator::Peek` bug.
   Repro is minimal (3 dict entries + 1 derive rule); we have the
   patch in `vendor/librime-1.16.0-peek-sort.patch`. Useful regardless
   of whether smoodle keeps Path A or flips to Path B.
3. **v0.2 Sub-task 1 (the eureka layer):** vendor/librime is built;
   `make` against its headers + dylib should produce a hello-world
   plugin dropped into Squirrel's `Frameworks/rime-plugins/`. The
   reference dylibs are `librime-lua.dylib`, `librime-octagram.dylib`,
   `librime-predict.dylib` — read their source for plugin ABI patterns.
   Also check `rime-llm-translator` on AUR (Linux); may be portable.
4. **Ship v0.0.3 milestone publicly.** Currently the patched dylib is
   only on this machine. For a public release, three options (open
   question 5 below):
   - Build universal librime locally + ship instructions to swap
   - Wait for upstream PR merge + Squirrel rebundle
   - Flip the public-release config to Path B (enumeration-fat dict,
     no algebra → no patch needed → ranking is freq-clean)
5. **Add more dict entries.** 13775 TNC words are above freq-50; we
   took the top 1500. Easy to scale further if dogfood shows OOV gaps.
   `bash scripts/install.sh` after merging is enough; no patch changes.
6. **Verify `kao → เขา` decision after typing.** TNC says เขา (142k)
   beats ข้าว (12k), but casual-chat-IME use might prefer rice. If
   dogfood agrees with TNC, leave it. If it doesn't, manual weight
   bump on ข้าว or wait for real-typing-frequency data.

## Open questions still on deck

1. ~~PyThaiNLP corpus license check~~ **DONE** — TNC unigram is CC0
   per `pythainlp-corpus/db.json`. Attribution noted in dict frontmatter.
2. Verify `librime-predict.dylib`'s actual async behavior.
3. v0.2 plugin must handle stale-result drop AND cooperative cancellation
   via `ggml_abort_callback`.
4. macOS Gatekeeper acceptance test on a clean machine before announcing.
5. **NEW**: Ship strategy when end users don't have the librime patch.
   Either upstream-merge first, or release a Path B config (no algebra)
   for v0.0.3, or accept that ranking will be slightly wrong on a
   handful of words for end users.

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

# Bulk generation against a word list (resumable, parallel)
python3 scripts/generate_dict.py \
  --words scripts/words-tnc.txt \
  --output scripts/generated-tnc.tsv \
  --workers 5

# Merge a TSV into the dict with TNC frequency reweighting (v0.0.3+)
python3 scripts/merge_dict.py \
  --base schema/thai_phonetic.dict.yaml \
  --add scripts/generated-tnc.tsv \
  --tnc-freq scripts/tnc_freq.txt \
  --default-freq 10 \
  --output schema/thai_phonetic.dict.yaml

# Re-pull TNC freq if scripts/tnc_freq.txt is missing (CC0)
curl -sL https://raw.githubusercontent.com/PyThaiNLP/pythainlp/dev/pythainlp/corpus/tnc_freq.txt \
  -o scripts/tnc_freq.txt
```

## Don't do

- Don't add `output_format` to API calls — deprecated. Use `output_config.format`.
- Don't add `temperature` / `top_p` / `budget_tokens` on Opus 4.7 — all 400.
- Don't add tone marks to romanization variants. Tones live in Thai output only.
- ~~Don't expect Rime's algebra to apply iteratively — it's single-pass per
  rule (first regex match only).~~ **CORRECTED:** algebra rules apply
  via `boost::regex_replace` which replaces ALL occurrences in a single
  rule application. Earlier RESUME claim about "first match only" was
  wrong. `derive/kh/k/` against `khopkhun` produces `kopkun` directly.
- Don't pre-log the dict weights. Rime's `dict_compiler` already applies
  `log()` at compile and `table_translator` applies `exp()` at query.
  Storing raw frequencies is correct; storing log-frequencies double-logs.
- Don't trust ranking from a fresh-cloned librime without applying the
  Peek-sort patch (`vendor/librime/src/rime/dict/dictionary.{cc,h}`).
  The first candidate will be wrong whenever an algebra-derived spelling
  shares a syllable with a direct one and sorts alphabetically earlier.
- Don't change the architecture from Rime/Squirrel without a Step 0
  scope challenge with the user. Flag concerns; user decides.
