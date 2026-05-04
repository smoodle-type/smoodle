#!/usr/bin/env python3
"""Generate Thai phonetic romanization variants for smoodle's Rime dictionary.

For each Thai word, calls the Claude API and asks for 3-5 plausible
romanizations a non-native English-speaker might type. Outputs Rime
native dict format (`<thai>\\t<romanization>\\t<weight>`) ready to append
to `schema/thai_phonetic.dict.yaml`.

Resume: if --output already exists, Thai words already represented in it
are skipped. Safe to ctrl-C and re-run.

Requirements:
  pip install anthropic
  export ANTHROPIC_API_KEY=...

Usage:
  # Single-word debug
  python scripts/generate_dict.py --word สวัสดี --debug

  # Bulk generation, append to a fresh dict body
  python scripts/generate_dict.py \\
      --words scripts/words-example.txt \\
      --output schema/thai_phonetic.dict.body

  # Cost-tuned (use Haiku for cheaper, faster generation)
  python scripts/generate_dict.py \\
      --words words.txt \\
      --output dict.body \\
      --model claude-haiku-4-5 \\
      --no-thinking
"""

from __future__ import annotations

import anthropic
import argparse
import json
import sys
from pathlib import Path


SYSTEM_PROMPT = """You generate plausible English-letter romanizations of Thai words for a phonetic IME (input method) called smoodle. Users type romanized Thai approximations and select Thai script candidates, like Pinyin for Mandarin.

For each Thai word, output 3 to 5 distinct romanizations that a non-native English-speaker might plausibly type if they wanted that Thai word, ordered most-common-typing-pattern first.

Rules:
- Use only lowercase ASCII a-z. No spaces, no apostrophes, no numbers, no diacritics.
- Do NOT encode tones in the romanization. Tones live in the Thai output, not the input.
- Reflect natural typing variation: aspirated vs. unaspirated consonants (kh/k, ph/p, th/t), vowel length (a/aa, i/ii), and Thai final-consonant simplification (b/p, t/d, s as final t in spoken Thai).
- For multi-syllable Thai words, output continuous lowercase Latin without internal spaces or hyphens. Like Pinyin: 'nihao' not 'ni hao' or 'ni-hao'.
- Skip romanizations that are nearly identical (within 1 character of another variant) unless they meaningfully differ in pronunciation pattern.
- Weights: 100 for the canonical/most-common variant, decreasing in steps of 5-10 for less-common variants. Stay between 70 and 100.

Output schema (JSON only, no markdown, no commentary):
{
  "variants": [
    {"romanization": "<lowercase ASCII>", "weight": <integer 70-100>},
    ...
  ]
}

Example for ครับ (the male polite particle):
{"variants": [
  {"romanization": "krap", "weight": 100},
  {"romanization": "khrap", "weight": 95},
  {"romanization": "kub", "weight": 90},
  {"romanization": "khap", "weight": 85},
  {"romanization": "krub", "weight": 80}
]}"""


VARIANTS_SCHEMA = {
    "type": "object",
    "properties": {
        "variants": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "romanization": {"type": "string"},
                    "weight": {"type": "integer"},
                },
                "required": ["romanization", "weight"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["variants"],
    "additionalProperties": False,
}


def generate_variants(
    client: anthropic.Anthropic,
    thai_word: str,
    model: str,
    use_thinking: bool,
) -> list[dict]:
    """Call the Claude API for one Thai word; return a deduped variant list.

    The LLM occasionally emits the same romanization twice with different
    weights (observed: ดื่ม → deum at both 100 and 80). This dedupes by
    romanization, keeping the highest weight, then sorts weight-desc.
    """
    response = client.messages.create(
        model=model,
        max_tokens=1024,
        system=[{"type": "text", "text": SYSTEM_PROMPT}],
        cache_control={"type": "ephemeral"},
        thinking={"type": "adaptive"} if use_thinking else {"type": "disabled"},
        output_config={
            "format": {"type": "json_schema", "schema": VARIANTS_SCHEMA},
        },
        messages=[
            {"role": "user", "content": f"Thai word: {thai_word}\n\nOutput the JSON now."}
        ],
    )
    text_block = next(b for b in response.content if b.type == "text")
    payload = json.loads(text_block.text)

    # Dedup by romanization, keep highest weight
    by_roman: dict[str, int] = {}
    for v in payload["variants"]:
        r, w = v["romanization"], v["weight"]
        if r not in by_roman or w > by_roman[r]:
            by_roman[r] = w
    deduped = [{"romanization": r, "weight": w} for r, w in by_roman.items()]
    deduped.sort(key=lambda x: -x["weight"])
    return deduped


def already_in_output(output_path: Path, thai_word: str) -> bool:
    """True if `thai_word` already has any entry in the output dict body."""
    if not output_path.exists():
        return False
    needle = f"{thai_word}\t"
    with output_path.open(encoding="utf-8") as f:
        for line in f:
            if line.startswith(needle):
                return True
    return False


def append_entries(output_path: Path, thai_word: str, variants: list[dict]) -> None:
    with output_path.open("a", encoding="utf-8") as f:
        for v in variants:
            f.write(f"{thai_word}\t{v['romanization']}\t{v['weight']}\n")


def read_words(words_path: Path) -> list[str]:
    """One Thai word per line. `#`-prefixed lines and blank lines are ignored."""
    out: list[str] = []
    with words_path.open(encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            out.append(line)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--words", type=Path, help="File with one Thai word per line")
    target.add_argument("--word", type=str, help="Single Thai word to test")

    parser.add_argument(
        "--output",
        type=Path,
        help="Append-mode dict body file. If omitted, lines go to stdout.",
    )
    parser.add_argument(
        "--model",
        default="claude-opus-4-7",
        help="Claude model ID (default: claude-opus-4-7). Use claude-haiku-4-5 for cheaper bulk runs.",
    )
    parser.add_argument(
        "--no-thinking",
        action="store_true",
        help="Disable adaptive thinking. Cheaper and faster; quality may dip on harder words.",
    )
    parser.add_argument("--debug", action="store_true", help="Print raw responses to stderr")
    args = parser.parse_args()

    client = anthropic.Anthropic()
    use_thinking = not args.no_thinking

    if args.word:
        variants = _generate_with_retry(
            client, args.word, model=args.model, use_thinking=use_thinking, debug=args.debug
        )
        for v in variants:
            print(f"{args.word}\t{v['romanization']}\t{v['weight']}")
        return 0

    words = read_words(args.words)
    print(
        f"# {len(words)} Thai words queued. model={args.model} thinking={use_thinking}",
        file=sys.stderr,
    )

    success = 0
    skipped = 0
    failed = 0
    for i, word in enumerate(words, 1):
        if args.output and already_in_output(args.output, word):
            skipped += 1
            print(f"# [{i:>4}/{len(words)}] skip {word}  (already in output)", file=sys.stderr)
            continue

        try:
            variants = _generate_with_retry(
                client, word, model=args.model, use_thinking=use_thinking, debug=args.debug
            )
        except Exception as e:
            failed += 1
            print(f"# [{i:>4}/{len(words)}] FAIL {word}: {type(e).__name__}: {e}", file=sys.stderr)
            continue

        if args.output:
            append_entries(args.output, word, variants)
        else:
            for v in variants:
                print(f"{word}\t{v['romanization']}\t{v['weight']}")
                sys.stdout.flush()

        success += 1
        print(f"# [{i:>4}/{len(words)}] {word} -> {len(variants)} variants", file=sys.stderr)

    print(
        f"# done. success={success} skipped={skipped} failed={failed}",
        file=sys.stderr,
    )
    return 1 if failed else 0


def _generate_with_retry(
    client: anthropic.Anthropic,
    thai_word: str,
    model: str,
    use_thinking: bool,
    debug: bool,
) -> list[dict]:
    """The Anthropic SDK already retries 429s and 5xxs with backoff (max_retries=2 default).
    Catch the typed exceptions here so one failed word doesn't kill a 500-word run."""
    try:
        variants = generate_variants(client, thai_word, model, use_thinking)
    except anthropic.RateLimitError:
        # SDK already retried twice; surface to caller for run-level handling.
        raise
    except anthropic.BadRequestError as e:
        # Schema validation failure or invalid model — re-raise so the user sees it.
        if debug:
            print(f"# DEBUG BadRequest for {thai_word}: {e}", file=sys.stderr)
        raise

    if debug:
        print(
            f"# DEBUG {thai_word}: {json.dumps(variants, ensure_ascii=False)}",
            file=sys.stderr,
        )
    return variants


if __name__ == "__main__":
    raise SystemExit(main())
