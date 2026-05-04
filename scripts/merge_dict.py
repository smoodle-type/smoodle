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

---
name: thai_phonetic
version: "0.0.2"
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


def render(grouped: "OrderedDict[str, dict[str, int]]") -> str:
    """Render the dict body. Per-Thai variants sorted weight-desc, then alpha."""
    out: list[str] = [FRONTMATTER]
    for thai, variants in grouped.items():
        out.append(f"# {thai}")
        rows = sorted(variants.items(), key=lambda kv: (-kv[1], kv[0]))
        for roman, w in rows:
            out.append(f"{thai}\t{roman}\t{w}")
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
    args = parser.parse_args()

    base_rows = parse_rime_dict(args.base) if args.base.exists() else []
    add_rows = parse_tsv_lines(args.add.read_text(encoding="utf-8").splitlines())

    merged = merge(base_rows, add_rows)
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
