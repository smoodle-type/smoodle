#!/usr/bin/env python3
"""smoodle v0.0.1 dictionary correctness test.

Reads `tests/v001_fixture.yaml` (a list of (romanization, expected_thai)
assertions) and `schema/thai_phonetic.dict.yaml`, then verifies every
fixture pair is present as a `<thai>\\t<romanization>` line in the dict.

This catches:
  - Romanization typos (`khrap` was meant but `khrip` got typed).
  - Wrong tone marks on the Thai output (`สวัสดี` vs `สวัสดิ`, `ครับ` vs `ครับฺ`).
  - Missing variants (an entry for `khrap` got dropped during a refactor).

This does NOT exercise the full Rime pipeline — for that you need
`rime_api_console`, which Squirrel does not bundle. To run the full
pipeline test, compile librime locally:

    git clone https://github.com/rime/librime
    cd librime && make && make install
    # rime_api_console is now on PATH
    # then re-run with --use-rime-api-console

Until then, this contents-check is the v0.0.1 acceptance test.

Requirements:
  Python 3.10+ (uses `match` statement).
  No third-party deps — uses stdlib only. The dict YAML body is parsed
  line-by-line because the Rime native dict format is two-document YAML
  with a tab-separated body that PyYAML doesn't handle cleanly.

Exit codes:
  0 — all assertions pass
  1 — at least one assertion failed
  2 — fixture or dict file missing / malformed
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FIXTURE = REPO_ROOT / "tests" / "v001_fixture.yaml"
DEFAULT_DICT = REPO_ROOT / "schema" / "thai_phonetic.dict.yaml"
DEFAULT_RIME_CLI = REPO_ROOT / "vendor" / "librime" / "build" / "bin" / "rime_api_console"
DEFAULT_RIME_TESTDIR = Path("/tmp/smoodle-rime-test")


class Assertion(NamedTuple):
    romanization: str
    expected_thai: str
    via: str | None  # algebra rule label if this is an algebra-derived case, else None


def parse_fixture(fixture_path: Path) -> list[Assertion]:
    """Parse the fixture YAML manually.

    Recognized inline-mapping shapes (one per line):
      - {romanization: "...", expected_thai: "..."}
      - {romanization: "...", expected_thai: "...", via: "<rule>"}

    A regex-based parser is simpler than pulling in PyYAML. This script
    deliberately stays stdlib-only so it runs out-of-the-box on any
    Python 3.10+ install.
    """
    if not fixture_path.exists():
        sys.exit(f"ERROR: fixture not found: {fixture_path}")

    direct_pat = re.compile(
        r'^\s*-\s*\{\s*romanization:\s*"([^"]+)"\s*,'
        r'\s*expected_thai:\s*"([^"]+)"\s*\}\s*$'
    )
    via_pat = re.compile(
        r'^\s*-\s*\{\s*romanization:\s*"([^"]+)"\s*,'
        r'\s*expected_thai:\s*"([^"]+)"\s*,'
        r'\s*via:\s*"([^"]+)"\s*\}\s*$'
    )
    out: list[Assertion] = []
    for raw in fixture_path.read_text(encoding="utf-8").splitlines():
        m = via_pat.match(raw)
        if m:
            out.append(Assertion(m.group(1), m.group(2), m.group(3)))
            continue
        m = direct_pat.match(raw)
        if m:
            out.append(Assertion(m.group(1), m.group(2), None))
    return out


def parse_dict_entries(dict_path: Path) -> set[tuple[str, str]]:
    """Read Rime native dict YAML; return the set of (thai, romanization) pairs.

    Rime's dict format is:
        ---
        <YAML frontmatter>
        ...
        <thai>\\t<romanization>[\\t<weight>]
        <thai>\\t<romanization>[\\t<weight>]
        ...

    We skip the frontmatter (everything up to and including the `...` line),
    then parse the body line-by-line.
    """
    if not dict_path.exists():
        sys.exit(f"ERROR: dict not found: {dict_path}")

    pairs: set[tuple[str, str]] = set()
    in_body = False
    for raw in dict_path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if not in_body:
            if line == "...":
                in_body = True
            continue
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        pairs.add((parts[0], parts[1]))
    return pairs


_CANDIDATE_LINE = re.compile(r"^\s*\d+\.\s+\[?(.+?)\]?(?:\s+~\S+)?\s*$")


def query_rime(roman: str, cli: Path, test_dir: Path, top_n: int) -> list[str]:
    """Spawn rime_api_console once, feed `roman`, return the top-N candidates.

    `print_menu` in tools/rime_api_console.cc emits one line per candidate as
    `<n>. [<top1>]` for the highlighted entry and `<n>.  <other>` for the rest,
    with optional ` ~<remainder>` suffix when the input is a prefix match.
    """
    proc = subprocess.run(
        [str(cli)],
        cwd=test_dir,
        input=roman + "\n",
        text=True,
        capture_output=True,
        timeout=15,
    )
    candidates: list[str] = []
    for line in proc.stdout.splitlines():
        m = _CANDIDATE_LINE.match(line)
        if m:
            candidates.append(m.group(1).strip())
            if len(candidates) >= top_n:
                break
    return candidates


def run_engine_mode(
    direct: list[Assertion],
    algebra: list[Assertion],
    cli: Path,
    test_dir: Path,
    top_n: int,
) -> int:
    """Drive each assertion through rime_api_console; check expected_thai
    appears in the top-N candidate list. Both direct and algebra-tagged
    assertions are exercised end-to-end."""
    if not cli.is_file():
        sys.exit(f"ERROR: rime_api_console not built. Expected at {cli}\n"
                 f"       Build it first: cd vendor/librime && make release")
    if not (test_dir / "default.yaml").exists():
        sys.exit(f"ERROR: Rime test working dir not initialized at {test_dir}\n"
                 f"       Run: scripts/init_rime_testdir.sh {test_dir}")

    # Refresh test dir's schema + dict in case the repo's changed since init
    for f in ("thai_phonetic.schema.yaml", "thai_phonetic.dict.yaml"):
        src = REPO_ROOT / "schema" / f
        dst = test_dir / f
        if src.read_bytes() != (dst.read_bytes() if dst.exists() else b""):
            dst.write_bytes(src.read_bytes())
            # Force re-deploy by removing the compiled prism
            for stale in test_dir.glob("build"):
                if stale.is_dir():
                    import shutil
                    shutil.rmtree(stale)

    failures: list[str] = []
    all_assertions = [(a, "direct") for a in direct] + [(a, f"via {a.via}") for a in algebra]
    print(f"smoodle dict test (engine mode): driving {len(all_assertions)} entries "
          f"through {cli.name}, checking top-{top_n} candidates...")
    for a, label in all_assertions:
        try:
            candidates = query_rime(a.romanization, cli, test_dir, top_n)
        except subprocess.TimeoutExpired:
            failures.append(f"  TIMEOUT  [{label}]  {a.romanization!r:<14} -> {a.expected_thai}")
            continue
        if a.expected_thai not in candidates:
            top1 = candidates[0] if candidates else "(no candidates)"
            failures.append(f"  MISS     [{label}]  {a.romanization!r:<14} -> "
                            f"{a.expected_thai}  (top1: {top1})")

    if failures:
        print(f"\n{len(failures)} failure(s):")
        for line in failures:
            print(line)
        print(f"\nFAIL  {len(failures)}/{len(all_assertions)} entries missing from candidate list.")
        return 1

    print(f"PASS  all {len(all_assertions)} entries produced expected Thai in top-{top_n}.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fixture", type=Path, default=DEFAULT_FIXTURE,
                        help=f"Fixture YAML (default: {DEFAULT_FIXTURE.relative_to(REPO_ROOT)})")
    parser.add_argument("--dict", dest="dict_path", type=Path, default=DEFAULT_DICT,
                        help=f"Rime dict YAML to test (default: {DEFAULT_DICT.relative_to(REPO_ROOT)})")
    parser.add_argument("--use-rime-api-console", action="store_true",
                        help="Drive each assertion through librime via rime_api_console. "
                             "Exercises both direct and algebra-tagged entries end-to-end.")
    parser.add_argument("--rime-cli", type=Path, default=DEFAULT_RIME_CLI,
                        help=f"Path to rime_api_console (default: {DEFAULT_RIME_CLI.relative_to(REPO_ROOT)})")
    parser.add_argument("--rime-test-dir", type=Path, default=DEFAULT_RIME_TESTDIR,
                        help=f"Rime working directory (default: {DEFAULT_RIME_TESTDIR}). "
                             f"Initialize with scripts/init_rime_testdir.sh.")
    parser.add_argument("--top-n", type=int, default=5,
                        help="In engine mode, accept expected_thai if present in top-N "
                             "candidates (default: 5).")
    args = parser.parse_args()

    assertions = parse_fixture(args.fixture)
    if not assertions:
        sys.exit(f"ERROR: no assertions parsed from {args.fixture}")

    direct = [a for a in assertions if a.via is None]
    algebra = [a for a in assertions if a.via is not None]

    if args.use_rime_api_console:
        return run_engine_mode(direct, algebra, args.rime_cli, args.rime_test_dir, args.top_n)

    # String-match mode (default)
    dict_pairs = parse_dict_entries(args.dict_path)
    if not dict_pairs:
        sys.exit(f"ERROR: no entries parsed from {args.dict_path}")

    failures: list[str] = []
    for a in direct:
        if (a.expected_thai, a.romanization) not in dict_pairs:
            failures.append(f"  MISSING  {a.romanization!r:<14} -> {a.expected_thai}")

    print(f"smoodle dict test: {len(direct)} direct + {len(algebra)} algebra-tagged "
          f"assertions, {len(dict_pairs)} dict entries scanned")

    if algebra:
        # Sanity-check: an algebra-tagged entry MUST NOT also be in the dict
        # directly — if it is, the test is mistagged and we'd be giving the
        # algebra rule false credit.
        mistagged: list[str] = []
        for a in algebra:
            if (a.expected_thai, a.romanization) in dict_pairs:
                mistagged.append(f"  MISTAGGED  {a.romanization!r:<14} -> {a.expected_thai}  "
                                 f"(via: {a.via!r}, but is also a direct dict entry)")
        if mistagged:
            print("\n" + "\n".join(mistagged))
            print(f"\nFAIL  {len(mistagged)} mistagged: tagged as algebra-derived but "
                  f"also direct dict entries.")
            return 1
        print(f"NOTE  {len(algebra)} algebra-tagged assertions SKIPPED "
              f"(string-match cannot verify; run with --use-rime-api-console "
              f"to exercise them end-to-end).")

    if failures:
        print(f"\n{len(failures)} failure(s):")
        for line in failures:
            print(line)
        print(f"\nFAIL  {len(failures)}/{len(direct)} direct assertions missing from dict.")
        return 1

    print(f"PASS  all {len(direct)} direct assertions present in dict.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
