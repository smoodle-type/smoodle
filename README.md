# smoodle

Pinyin-style phonetic Thai input method. Type `sawadee`, get `สวัสดี`. Type
`khrap` / `krap` / `kub`, get `ครับ`.

Built as a [Rime](https://rime.im/) schema running inside Squirrel on macOS.
Cross-platform support (Windows via Weasel, Linux via fcitx5/ibus) is the
Phase 1 target. Phase 1.5 adds an `smoodle_llm_translator` C++ plugin
(local `llama.cpp` + Qwen 1.8B Q4) for tone disambiguation on
out-of-dictionary input.

## Status

**v0.0.6** — schema covers 100% of the Thai National Corpus freq≥50 tail
(14,893 Thai words / 28,239 entries), TNC-frequency-weighted ranking. The
`DictEntryIterator::Peek` first-call-sort fix ships via the
[LoneExile/librime](https://github.com/LoneExile/librime) soft-fork at tag
`1.16.0-smoodle.1` until upstream merges.

Phase 1 status: `APPROVED-PENDING-PHASE-0`. macOS dogfood install path is
end-to-end. Windows / Linux installers land in Lane B / Lane C.

In-repo source-of-truth:
- [`docs/PHASE1-PROMPT.md`](docs/PHASE1-PROMPT.md) — active execution plan
- [`TODOS.md`](TODOS.md) — outstanding work outside the active milestone
- [`docs/RESUME.md`](docs/RESUME.md) — architecture, file map, librime
  patch internals, "don't do" list

## Install (macOS dogfood)

```bash
brew install --cask squirrel-app             # one-time host install

bash scripts/install.sh                      # ~/Library/Rime/ schema YAMLs (sudoless)
bash scripts/install-librime-fork.sh         # build patched librime + dylib swap (sudo)

osascript -e 'tell application id "im.rime.inputmethod.Squirrel" to quit'
open -b im.rime.inputmethod.Squirrel
```

Then press `Ctrl+\`` in any text field to open Squirrel's schema switcher
and pick **smoodle Thai phonetic**. Type `sawadee` → expect `สวัสดี`.

The librime build needs Homebrew deps (`cmake`, `boost`, `leveldb`,
`marisa`, `yaml-cpp`, `opencc`, `googletest`, `pkg-config`, `ninja`,
`glog`); the script fails loudly with the exact `brew install ...` line
on missing deps.

## Test

```bash
# String-match (fast, no librime build needed)
python3 tests/test_dict.py --fixture tests/v01_fixture.yaml

# Engine mode (drives librime via rime_api_console)
bash scripts/init_rime_testdir.sh                                       # one-time
python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml

# Installer suite (17 active + 5 skipped stubs for Lane B/C/E2E)
python3 tests/test_installers.py
```

Engine fixture target: 56/56 PASS (35 direct + 21 algebra-tagged).

## Repo layout

```
smoodle/
├── schema/                          # Rime YAML config: schema, dict, default.custom.yaml
├── scripts/
│   ├── install.sh                   # schema YAMLs → ~/Library/Rime/ (sudoless)
│   ├── install-librime-fork.sh      # build patched librime + dylib swap (sudo)
│   ├── init_rime_testdir.sh         # /tmp/smoodle-rime-test bootstrap for engine tests
│   ├── generate_dict.py             # Claude-API romanization variant generator
│   ├── merge_dict.py                # TNC-frequency-weighted dict builder
│   ├── tnc_freq.txt                 # PyThaiNLP TNC unigram (CC0)
│   └── words-*.txt + generated-*.tsv  # dict-build inputs (reproducible via merge_dict.py)
├── tests/
│   ├── test_dict.py                 # 56-entry fixture (string-match + engine mode)
│   ├── test_installers.py           # 17 active + 5 stub installer cases
│   └── v01_fixture.yaml             # (romanization, expected_thai) assertions
├── docs/
│   ├── PHASE1-PROMPT.md             # active execution plan
│   └── RESUME.md                    # long-form architecture context
├── TODOS.md                         # tracked work outside the active milestone
├── vendor/                          # gitignored — librime fork checkout (~2GB after build)
└── vendor/librime-1.16.0-peek-sort.patch   # historical fallback (fork tag is canonical)
```

## Roadmap

- **Phase 1** *(current)* — Cross-platform unsigned dogfood installers,
  dict-only. Wedge: Thai language learners on physical Latin keyboards.
  macOS dogfood live; Windows + Linux installers next.
- **Phase 1.5** *(conditional, ~4-8 wk)* — Add `smoodle_llm_translator`
  C++ plugin: local llama.cpp with Qwen 1.8B Q4 for tone disambiguation
  on OOV input. Privacy-by-construction (all inference on-device).
- **Phase 2** *(gated by Phase 1 validation signal)* — Native IME
  shells per OS, license-clean rewrite of the engine in Rust or C++.

See [`docs/PHASE1-PROMPT.md`](docs/PHASE1-PROMPT.md) for sequencing
details and the Decision Gate criteria.

## License

[MIT](LICENSE) for smoodle's own code (schema, dict, scripts, tests, docs).

The patched librime distribution at
[LoneExile/librime](https://github.com/LoneExile/librime) is BSD-3
(inherited from upstream). Squirrel itself is GPLv3 and is **not
bundled** — installers configure Squirrel rather than redistributing
it; users obtain Squirrel via Homebrew (`brew install --cask
squirrel-app`).

