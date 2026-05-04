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
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


SYSTEM_PROMPT = """You generate plausible English-letter romanizations of Thai words for a phonetic IME (input method) called smoodle. Users type romanized Thai approximations and select Thai script candidates, like Pinyin for Mandarin.

For each Thai word, output 1 to 3 distinct romanizations covering MEANINGFULLY DIFFERENT typings. The schema applies algebra rules at the speller layer that automatically accept these equivalences — DO NOT emit variants that differ only in:
  - Aspiration: kh ~ k, ph ~ p, th ~ t (e.g. for ครับ, emit 'krap' OR 'khrap', not both)
  - Vowel length: aa ~ a, ii ~ i, oo ~ o, uu ~ u, ee ~ e (e.g. for นาที, emit 'natee' or 'nati' but NOT both)
  - Final-stop voicing: word-final p ~ b and t ~ d (e.g. for ขอบ in ขอบคุณ, 'khop' and 'khob' are auto-equivalent)

Emit additional variants ONLY when they differ in:
  - Vowel choice (e.g. ครับ → 'krap' AND 'krub', because a/u are genuinely different)
  - Consonant choice that algebra can't derive (e.g. ใช่ → 'chai' AND 'chay' for the i/y final-glide ambiguity)
  - Substantively different romanization conventions (e.g. ผม → 'phom' AND 'pohm' — extra 'h' vowel marker)

Rules:
- Use only lowercase ASCII a-z. No spaces, no apostrophes, no numbers, no diacritics.
- Do NOT encode tones in the romanization. Tones live in the Thai output, not the input.
- For multi-syllable Thai words, output continuous lowercase Latin without internal spaces or hyphens. Like Pinyin: 'nihao' not 'ni hao' or 'ni-hao'.
- Pick the canonical form (weight 100) as the typing a non-native English-speaker is MOST likely to use first. The optional 2nd/3rd variants are weight 85-95.
- If only one truly-distinct typing exists for a word, emit just one entry — algebra fills in the rest.

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
  {"romanization": "krub", "weight": 90}
]}
(NOTE: 'khrap' is NOT emitted because algebra derives it from 'krap' via kh~k. 'khap' is NOT emitted because algebra derives it from 'krap' via dropping r — wait, r-dropping is NOT in algebra; emit 'khap' if you think it's a common typing variant. Use judgment per the "consonant choice that algebra can't derive" rule.)

Example for ขอบคุณ (thank you):
{"variants": [
  {"romanization": "khopkhun", "weight": 100}
]}
(Single variant because algebra handles kh~k AND p~b AND vowel-length: 'khopkhun' alone yields kopkhun, khobkhun, kobkhun, khopkun, kopkun, kobkun, khopkoon, etc. all automatically.)

Example for ใช่ (yes):
{"variants": [
  {"romanization": "chai", "weight": 100},
  {"romanization": "chay", "weight": 85}
]}
(Two variants because i/y at word-end is a real typing-convention split — algebra has no rule for it.)"""


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
    parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Number of parallel API workers in --words mode (default: 1). "
             "Try 4-6 against the relay; the SDK is thread-safe.",
    )
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

    # Pre-compute the skip set ONCE (the previous serial version reread output
    # for every word; that's O(N*output_size) IO and racy under threads).
    already_done: set[str] = set()
    if args.output and args.output.exists():
        with args.output.open(encoding="utf-8") as f:
            for line in f:
                if "\t" in line:
                    already_done.add(line.split("\t", 1)[0])

    todo = [w for w in words if w not in already_done]
    skipped = len(words) - len(todo)
    if skipped:
        print(f"# {skipped} words already in {args.output}, skipping", file=sys.stderr)

    write_lock = threading.Lock()
    counter = {"success": 0, "failed": 0, "done": 0}

    def process(word: str) -> None:
        try:
            variants = _generate_with_retry(
                client, word, model=args.model, use_thinking=use_thinking, debug=args.debug
            )
        except Exception as e:
            with write_lock:
                counter["failed"] += 1
                counter["done"] += 1
                i = counter["done"]
                print(f"# [{i:>4}/{len(todo)}] FAIL {word}: {type(e).__name__}: {e}",
                      file=sys.stderr)
            return

        with write_lock:
            counter["success"] += 1
            counter["done"] += 1
            i = counter["done"]
            if args.output:
                append_entries(args.output, word, variants)
            else:
                for v in variants:
                    print(f"{word}\t{v['romanization']}\t{v['weight']}")
                sys.stdout.flush()
            print(f"# [{i:>4}/{len(todo)}] {word} -> {len(variants)} variants",
                  file=sys.stderr)

    if args.workers <= 1:
        for w in todo:
            process(w)
    else:
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            futures = [ex.submit(process, w) for w in todo]
            for _ in as_completed(futures):
                pass

    print(
        f"# done. success={counter['success']} skipped={skipped} failed={counter['failed']}",
        file=sys.stderr,
    )
    return 1 if counter["failed"] else 0


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
