# smoodle

Pinyin-style phonetic Thai input method for macOS.

Type `sawadee`, get `สวัสดี`. Type `krap` / `kub` / `khrap`, get `ครับ`.
Built as a Rime schema for [Squirrel](https://rime.im/), the official Rime
input method engine for macOS. v0.2 will add a custom librime translator
plugin that uses a local LLM (`llama.cpp`, Qwen 1.8B Q4) to disambiguate
out-of-dictionary input and synthesize tone marks for Thai names and
neologisms.

Status: pre-v0.0.1. Design doc and engineering review live in `~/.gstack/projects/smoodle/`.

## Roadmap

- **v0.0.1** — Thai phonetic Rime schema (~500 words) + 30-entry test
  fixture. Ships as a `smoodle-config.zip` for users who already have
  Squirrel installed.
- **v0.1** — Expanded dictionary (~3000 words), permissive romanization
  variants, install script.
- **v0.2** — `smoodle_llm_translator` C++ plugin. LLM disambiguation +
  tone-mark synthesis for OOV input.
- **v0.3** — Per-user adaptation (Rime built-in user dictionary).

## License

MIT.
