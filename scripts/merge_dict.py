#!/usr/bin/env python3
"""Merge a generated TSV into smoodle's Rime dictionary.

The output of `generate_dict.py` is one `<thai>\\t<romanization>\\t<weight>`
line per variant. This script merges that TSV with the existing dict
(or another TSV) using a union-with-max-weight strategy, preserves
first-seen Thai-word ordering, and writes a Rime-format dict YAML.

Usage:
  # Merge generated variants into the existing dict (in place)
  python scripts/merge_dict.py \\
      --base schema/thai_phonetic.dict.yaml \\
      --add  scripts/generated-500.tsv \\
      --output schema/thai_phonetic.dict.yaml

  # Dry-run: preview output to stdout without writing
  python scripts/merge_dict.py \\
      --base schema/thai_phonetic.dict.yaml \\
      --add  scripts/generated-500.tsv

Merge rules:
  - Same (thai, romanization) pair from both sources -> keep max weight.
  - Within a Thai word, variants sorted weight-desc.
  - Thai-word ordering: first-seen wins (base file's order, then any
    NEW Thai words from the add-file appended in their TSV order).
"""

from __future__ import annotations

import argparse
import math
import sys
from collections import OrderedDict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DICT = REPO_ROOT / "schema" / "thai_phonetic.dict.yaml"

# Yaml frontmatter that prefixes a Rime native dict body. Kept in sync with
# the existing thai_phonetic.dict.yaml; bump version here when shipping.
FRONTMATTER = """\
# Rime dictionary
# encoding: utf-8
#
# smoodle Thai phonetic dictionary
#
# Multi-syllable Thai words use continuous Latin (no internal spaces) per
# commit 4b54bc3 — Rime's table_translator treats space as commit delimiter.
# v0.0.2 algebra rules in thai_phonetic.schema.yaml automatically accept
# kh~k / ph~p / th~t / vowel-length / final-voicing variation, so dict
# entries carry only 1-3 spelling variants per Thai word (Path A).
#
# v0.0.3 weights = tnc_freq * (variant_q / 100), raw counts. Rime's
# dict_compiler logs them at build time and table_translator exp()s at
# query time, so storing raw counts (not log-probabilities) gives the
# right ranking. TNC = Chulalongkorn Thai National Corpus unigram freq
# (CC0-1.0, via PyThaiNLP `tnc_freq.txt`). Per-variant LLM quality
# (q in 70-100) becomes a proportional multiplier on the count. Words
# not in TNC use freq = `--default-freq` (default 10).
#
# v0.0.4 dict expanded to cover the top of TNC freq>=50. Same weight
# scheme as v0.0.3 (raw tnc_freq * q/100). Generation was paused at
# 65% of the freq>=50 tail to conserve API quota; remaining ~4500
# words queue for v0.0.5.
#
# v0.0.5 finishes the freq>=50 tail. Coverage 12767/12792 = 99.8%;
# 25 words deferred to a future run (relay 500 on opus-4-7 capacity).

---
name: thai_phonetic
version: "0.0.5"
sort: by_weight
use_preset_vocabulary: false
columns:
  - text
  - code
  - weight
encoder:
  exclude_patterns:
    - '^[^\\x00-\\x7f]+$'
...
"""


def parse_tsv_lines(lines: list[str]) -> list[tuple[str, str, int]]:
    """Parse `<thai>\\t<romanization>\\t<weight>` rows. Skip blanks/comments."""
    out: list[tuple[str, str, int]] = []
    for raw in lines:
        line = raw.rstrip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        thai = parts[0].strip()
        roman = parts[1].strip()
        weight = int(parts[2]) if len(parts) >= 3 and parts[2].strip() else 100
        out.append((thai, roman, weight))
    return out


def parse_rime_dict(path: Path) -> list[tuple[str, str, int]]:
    """Parse a Rime native dict YAML; return body rows (frontmatter skipped)."""
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    body_start: int | None = None
    for i, line in enumerate(lines):
        if line.strip() == "...":
            body_start = i + 1
            break
    if body_start is None:
        sys.exit(f"ERROR: no '...' frontmatter terminator in {path}")
    return parse_tsv_lines(lines[body_start:])


def merge(
    base_rows: list[tuple[str, str, int]],
    add_rows: list[tuple[str, str, int]],
) -> "OrderedDict[str, dict[str, int]]":
    """Union by (thai, romanization), max weight; preserve first-seen Thai order."""
    grouped: OrderedDict[str, dict[str, int]] = OrderedDict()
    for thai, roman, w in base_rows + add_rows:
        if thai not in grouped:
            grouped[thai] = {}
        prior = grouped[thai].get(roman)
        if prior is None or w > prior:
            grouped[thai][roman] = w
    return grouped


def load_tnc_freqs(path: Path) -> dict[str, int]:
    """Parse `<thai>\\t<freq>` lines from PyThaiNLP's tnc_freq.txt."""
    freqs: dict[str, int] = {}
    with path.open(encoding="utf-8") as f:
        for raw in f:
            parts = raw.strip().split("\t")
            if len(parts) >= 2:
                try:
                    freqs[parts[0]] = int(parts[1])
                except ValueError:
                    continue
    return freqs


def reweight_by_freq(
    grouped: "OrderedDict[str, dict[str, int]]",
    freqs: dict[str, int],
    default_freq: int,
) -> "OrderedDict[str, dict[str, int]]":
    """Rescale each variant to freq * (variant_quality / 100), as a raw count.

    Rime's `dict_compiler.cc` applies log() to the dict weight at compile time
    (line 257: `e->weight = log(r->weight)`), and `table_translator.cc`
    applies exp() at query time (line 90: `set_quality(std::exp(e->weight))`).
    So we store RAW frequencies; pre-logging would double-log and flatten
    rank differences. Per-variant LLM quality (q in 70-100) scales the
    effective frequency: canonical (q=100) keeps the full TNC count;
    secondary (q=85) gets 85% of it.
    """
    out: OrderedDict[str, dict[str, int]] = OrderedDict()
    for thai, variants in grouped.items():
        f = freqs.get(thai, default_freq)
        rescaled = {r: max(1, round(f * q / 100)) for r, q in variants.items()}
        out[thai] = rescaled
    return out


def render(grouped: "OrderedDict[str, dict]") -> str:
    """Render the dict body. Per-Thai variants sorted weight-desc, then alpha.

    Weights may be ints (raw or quality-only) or floats (log-frequencies
    from --tnc-freq). `:g` formats both compactly.
    """
    out: list[str] = [FRONTMATTER]
    for thai, variants in grouped.items():
        out.append(f"# {thai}")
        rows = sorted(variants.items(), key=lambda kv: (-kv[1], kv[0]))
        for roman, w in rows:
            out.append(f"{thai}\t{roman}\t{w:g}")
        out.append("")
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", type=Path, default=DEFAULT_DICT,
                        help=f"Existing dict YAML (default: {DEFAULT_DICT.relative_to(REPO_ROOT)})")
    parser.add_argument("--add", type=Path, required=True,
                        help="TSV from generate_dict.py to merge in")
    parser.add_argument("--output", type=Path,
                        help="Where to write merged dict (omit to dry-run to stdout)")
    parser.add_argument("--tnc-freq", type=Path,
                        help="Path to PyThaiNLP tnc_freq.txt. If supplied, every "
                             "variant is rescaled to weight = tnc_freq * (q/100), "
                             "preserving per-variant quality ordering.")
    parser.add_argument("--default-freq", type=int, default=10,
                        help="Frequency assigned to dict words not in TNC "
                             "(default: 10). Compounds split by TNC's tokenizer "
                             "fall here.")
    args = parser.parse_args()

    base_rows = parse_rime_dict(args.base) if args.base.exists() else []
    add_rows = parse_tsv_lines(args.add.read_text(encoding="utf-8").splitlines())

    merged = merge(base_rows, add_rows)

    if args.tnc_freq:
        freqs = load_tnc_freqs(args.tnc_freq)
        merged = reweight_by_freq(merged, freqs, args.default_freq)
        in_tnc = sum(1 for thai in merged if thai in freqs)
        print(f"# reweighted {in_tnc}/{len(merged)} Thai words by TNC freq "
              f"(default={args.default_freq} for the {len(merged) - in_tnc} not in TNC)",
              file=sys.stderr)

    rendered = render(merged)

    total_thai = len(merged)
    total_entries = sum(len(v) for v in merged.values())
    new_thai = sum(1 for thai in merged if thai not in {r[0] for r in base_rows})

    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
        print(f"# wrote {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(rendered)

    print(f"# {total_thai} Thai words ({new_thai} new), {total_entries} entries total",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
