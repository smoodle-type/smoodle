#!/usr/bin/env python3
"""Generate a categorized list of ~500 common Thai words for smoodle's dict.

One-off helper. Asks Claude for a curated list biased toward conversational/
messaging usage (what people TYPE), not academic-corpus frequency. Output is
written in the same format as `scripts/words-example.txt`: `# CATEGORY`
headers + one Thai word per line. The output file is consumed by
`generate_dict.py --words ...` to produce romanization variants.

Requirements:
  pip install anthropic
  export ANTHROPIC_API_KEY=...

Usage:
  python scripts/generate_words.py --output scripts/words-500.txt
"""

from __future__ import annotations

import anthropic
import argparse
import sys
from pathlib import Path


PROMPT = """You are curating a list of the most common Thai words for a phonetic input method (IME) called smoodle. Users will TYPE romanized approximations and select Thai script candidates, like Pinyin for Mandarin.

Goal: a categorized list of ~500 high-frequency Thai words that everyday users are most likely to type in messaging, social media, and casual writing. Bias toward conversational usage — NOT academic-corpus frequency, NOT formal Royal Thai vocabulary.

Cover these categories (counts approximate; adjust for natural distribution):
- Greetings, politeness, particles (~20)
- Pronouns (~12)
- Numbers and counting (~30)
- Time and calendar (~30)
- Family and relationships (~25)
- Body, health, hygiene (~25)
- Food and drink (~50)
- Common verbs — daily activities, motion, perception, communication (~80)
- Common adjectives — size, quality, emotion, color (~50)
- Places, directions, prepositions (~40)
- Transport and travel (~25)
- Home, objects, clothing (~40)
- Work, school, money (~30)
- Emotions and mental states (~20)
- Communication and technology (~20)

Rules:
- One Thai word per line. No romanization, no English glosses, no parenthetical notes.
- Output `# Category Name` as section headers between groups.
- Use the canonical Thai spelling (the form a typer would commit to). Don't list spelling variants of the same word (e.g. only ครับ, not ครับ + ค้าบ + คับ).
- Skip multi-word phrases (anything with a space).
- Skip very rare or formal-only words.
- Include common compound/multi-syllable words (ขอบคุณ, สวัสดี).
- Include both formal and casual register pronouns (ผม, ฉัน, กู, มึง are all valid).
- Aim for ~500 total. Quality > exact count.

Output: plain text only, just the categorized list, no preamble or commentary.
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, required=True,
                        help="File to write the categorized word list")
    parser.add_argument("--model", default="claude-opus-4-7",
                        help="Claude model ID (default: claude-opus-4-7)")
    args = parser.parse_args()

    client = anthropic.Anthropic()

    print(f"# generating ~500 Thai words via {args.model} (adaptive thinking)...",
          file=sys.stderr)

    with client.messages.stream(
        model=args.model,
        max_tokens=8192,
        thinking={"type": "adaptive"},
        messages=[{"role": "user", "content": PROMPT}],
    ) as stream:
        msg = stream.get_final_message()

    text_blocks = [b.text for b in msg.content if b.type == "text"]
    output = "\n".join(text_blocks).strip() + "\n"

    args.output.write_text(output, encoding="utf-8")

    word_lines = [ln for ln in output.splitlines()
                  if ln.strip() and not ln.startswith("#")]
    category_lines = [ln for ln in output.splitlines() if ln.startswith("#")]

    print(f"# wrote {args.output}: {len(word_lines)} words across "
          f"{len(category_lines)} categories", file=sys.stderr)
    print(f"# usage: {msg.usage.input_tokens} in, {msg.usage.output_tokens} out",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
