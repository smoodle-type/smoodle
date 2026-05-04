# smoodle — session handoff

Paste / read this at the start of a new Claude Code session to resume work
on smoodle. The long-form context lives in the design doc and the eng-review
test plan; this file is a map, not a full re-explanation.

## What smoodle is

A Pinyin-style phonetic input method for typing Thai on macOS. Type
`sawadee` → see candidate `สวัสดี` → press space to commit. v0.0.1 ships as
a Rime schema running inside Squirrel; v0.2 will add a custom librime C++
translator plugin that calls a local LLM (llama.cpp, Qwen 1.8B Q4) for
out-of-dictionary disambiguation and tone synthesis.

User intent: builder/learning project. The technical challenge — librime
plugin development + the LLM-as-translator integration — is the explicit
draw, not shipping speed.

## Where the long-form context lives — READ THESE FIRST

- **Design doc:** `~/.gstack/projects/smoodle/lex-main-design-20260503-163327.md`
  Revision 4 (post Rime/Squirrel pivot). 1217 lines. Has architecture
  diagrams, milestone breakdowns with sub-tasks, key technical decisions
  (schema YAML, dict format, threading model, LLM call shape, llama.cpp vs
  MLX-Swift, librime version pinning), success criteria, distribution plan,
  reviewer concerns, and the "What I noticed about how you think" section.
- **Eng review test plan:** `~/.gstack/projects/smoodle/lex-main-eng-review-test-plan-20260503.md`
  What to test where, edge cases, critical paths.
- **Commit history:** `git log --oneline` — each commit message is verbose
  on purpose. Read them in order to understand how the dict and tests grew.

## State as of last session

Branch: `main`. Last commit: dict expansion to 30 Thai words / 125 entries.

```
390688b v0.0.1 dict expanded to 30 Thai words / 125 entries
2d4c007 v0.0.1 Sub-task 6: 30-entry test fixture + Python driver
bb2649e Add Claude-API dict generator script + 30-word example seed
4b54bc3 fix(stub): drop space from ขอบคุณ romanizations
ee0b678 v0.0.1 stub: thai_phonetic schema + 10-word dict + install script
d80c16a Initial commit: README + .gitignore
```

v0.0.1 sub-tasks 0–6 are done. Sub-task 7 (deploy + acceptance) is partially
done — last installed dict is in `~/Library/Rime/`, but the user hasn't
clicked Squirrel's Deploy after the latest install yet. Test fixture
(30 assertions) passes against the merged dict.

## Architecture (do not relitigate without strong reason)

- **Foundation: Rime/Squirrel, NOT a McBopomofo Swift IMK fork.** This was a
  major Step 0 scope challenge in the eng review — Rime is the boring-default
  for macOS phonetic IMEs, used by millions for Mandarin/Cantonese/Japanese.
  The McBopomofo path is documented as a fallback in the design doc's
  Kill Criteria section if Rime hits a wall.
- **Library validation: not a blocker** (verified). Squirrel.app has
  `com.apple.security.cs.disable-library-validation: true`, so v0.2 third-
  party plugin dylibs can load. Plugin install dir:
  `/Library/Input Methods/Squirrel.app/Contents/Frameworks/rime-plugins/`.
- **librime version pinned: 1.16.0** (the version Squirrel 1.1.2 ships). v0.2
  plugin must compile against this exact version.
- **Multi-syllable Thai words use continuous Latin (no internal spaces):**
  `khobkhun` not `khob khun`. Rime's `table_translator` treats space as a
  commit delimiter — see commit 4b54bc3 for the rationale.

## File map

```
smoodle/
├── README.md
├── .gitignore                    # includes .env (relay creds, do NOT commit)
├── docs/
│   └── RESUME.md                 # this file
├── schema/
│   ├── thai_phonetic.schema.yaml # Rime schema config
│   ├── thai_phonetic.dict.yaml   # 30 Thai words / 125 entries
│   └── default.custom.yaml       # registers schema in Squirrel's switcher
├── scripts/
│   ├── install.sh                # copies schema/ → ~/Library/Rime/
│   ├── generate_dict.py          # Claude-API LLM dict generator
│   ├── words-example.txt         # 30-word seed list (test scale)
│   └── generated-example.tsv     # raw LLM output (kept as reference)
└── tests/
    ├── v001_fixture.yaml         # 30 (romanization, expected_thai) assertions
    └── test_dict.py              # stdlib-only driver, exit 0/1
```

## Critical caveats

- **`.env` contains relay credentials** (`ANTHROPIC_CUSTOM_BASE_URL` +
  `ANTHROPIC_CUSTOM_AUTH_TOKEN` for `crs.0dl.me/api`). It's gitignored.
  Never commit it. The token can be rotated at the relay's admin panel.
- **Don't archive Squirrel, agents, or environments without confirming**
  with the user — archiving is permanent and breaks new sessions.
- **Don't auto-merge generated dict output without spot-checking.** The LLM
  produces ~95% useful variants but ~5% need a Thai-speaker pass. Last
  session flagged: `ใช่/chi`, `ฉัน/shan`, `กาแฟ/gafae`, `วัน/won`, `น้ำ/num`.
  Left in dict for now.
- **Macros around the SDK:** `scripts/generate_dict.py` reads
  `ANTHROPIC_API_KEY` and `ANTHROPIC_BASE_URL` from env. The `.env` file
  uses `ANTHROPIC_CUSTOM_*` names — must be re-exported under standard names
  before invoking the script (see Quick start below).

## What's likely next (pick one)

1. **Deploy + dogfood the merged dict.** User clicks Squirrel's Deploy,
   types Thai for a few days using only smoodle, reports OOV-failure rate
   and which flagged variants felt wrong.
2. **Scale dict from 30 to ~500 words.** Source a real Thai frequency list
   (PyThaiNLP `thai_words()` is the documented option, license check per
   Open Question 1 in the design doc), run `scripts/generate_dict.py`,
   merge with the existing dict using the same union-with-max-weight logic
   (inline Python in commit `390688b`'s message, or extract to a helper).
   Realistic budget: ~4–6 hours of focused work for dict curation +
   spot-check, NOT one evening.
3. **Prune the 5 flagged variants** if the user reports them as confusing.
4. **Start v0.0.1 milestone exit** — write up README install instructions,
   create a GitHub repo, post `smoodle-config-0.0.1.zip` somewhere visible
   (Hacker News, r/Thailand, Mastodon), wait for first feedback.
5. **Begin v0.1 milestone** — expand dict toward 3000 words; investigate
   Rime's `algebra` rules for permissive matching (kh~k, ph~p, vowel-length
   collapsing) at the speller level instead of variant enumeration.
6. **v0.2 Sub-task 1 (the eureka layer):** clone librime 1.16.0, build a
   hello-world C++ plugin that adds a literal "PLUGIN_HELLO" candidate,
   drop the dylib into `/Library/Input Methods/Squirrel.app/Contents/Frameworks/rime-plugins/`,
   verify it loads. Reference: `librime-lua.dylib`,
   `librime-octagram.dylib`, `librime-predict.dylib` already shipped by
   Squirrel — read their source for plugin ABI patterns. Also check
   `rime-llm-translator` on AUR (Linux); may be portable.

## Open questions still on deck (from design doc)

1. PyThaiNLP corpus license check before shipping a 500-word seed.
2. Verify `librime-predict.dylib`'s actual async behavior (the eng review
   flagged this as an unverified claim — the doc says "next-keystroke render
   pattern" reuses librime-predict, but no one has confirmed the source
   actually does that).
3. v0.2 plugin must handle stale-result drop AND cooperative cancellation
   via `ggml_abort_callback` (NOT `llama_token_eos()` — that was a wrong
   citation corrected in Revision 4).
4. macOS Gatekeeper acceptance test on a clean machine before announcing
   v0.0.1 to non-developer users.

## Quick start commands

```bash
cd /Users/lex/Dev/my_repos/experiment/smoodle

# Run the fixture test
python3 tests/test_dict.py

# Re-install schema to ~/Library/Rime/ (then click Squirrel's Deploy)
bash scripts/install.sh

# Generate dict variants for a single Thai word (test path)
set -a; . .env; set +a
export ANTHROPIC_API_KEY="$ANTHROPIC_CUSTOM_AUTH_TOKEN"
export ANTHROPIC_BASE_URL="$ANTHROPIC_CUSTOM_BASE_URL"
python3 scripts/generate_dict.py --word "ขอบคุณ" --debug

# Bulk run from a words file (resumable; --output appends)
python3 scripts/generate_dict.py \
  --words scripts/words-example.txt \
  --output scripts/generated-example.tsv \
  --no-thinking

# Inspect a Thai word's entries in the merged dict
grep $'^สวัสดี\t' schema/thai_phonetic.dict.yaml

# Verify Squirrel-bundled librime version (must match v0.2 plugin pin)
otool -L "/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib" \
  | head -3
```

## Skills that were used last session (in invocation order)

`/oh-my-claudecode:office-hours` → `/oh-my-claudecode:plan-eng-review` →
`claude-api` (for the dict generator). Future sessions might use:
`/oh-my-claudecode:plan-design-review` (if the candidate window UX needs
work), `/oh-my-claudecode:ship` (when v0.0.1 is ready to push to GitHub),
`/oh-my-claudecode:investigate` (for v0.2 plugin debugging).

## Don't do

- Don't add `output_format` to API calls — deprecated. Use `output_config.format`.
- Don't add `temperature` / `top_p` / `budget_tokens` on Opus 4.7 — all 400.
- Don't add tone marks to romanization variants. Tones live in Thai output only.
- Don't use Levenshtein edit-distance over a `marisa-trie` — `marisa-trie`
  doesn't expose it. v0.1 plan is hand-enumerated variants (Path B in the
  design doc's Dictionary format section).
- Don't change the architecture from Rime/Squirrel without a Step 0
  scope challenge with the user. Flag concerns; user decides.
