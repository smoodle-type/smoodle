#!/usr/bin/env python3
"""Structural lint for smoodle Rime schema YAMLs (Phase 1, REQ LINT-01 + LINT-02).

Validates STRUCTURE only -- key allowlist, weight integrality, import_preset
reference resolution, algebra rule shape. Runs yamllint as a subprocess for
YAML-syntax/style checks.

SCOPE BOUNDARY (CP-5 from .planning/research/PITFALLS.md):
  This module does NOT import Python's `re` module for algebra body checks.
  Python's `re` module diverges from boost::regex on \\<, \\>, [[:alpha:]],
  \\Q\\E, and variable-width lookbehind. Compiling rule bodies in Python
  would produce false positives that block legitimate Rime regex.

  The regex oracle is the engine-mode test:
    python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml

  We validate algebra rule SHAPE (op + slash-separated parts) only.
  TestRegexBodyNotCompiled enforces this boundary via a tokenizer-level check.

Usage:
  python3 tests/test_schema_lint.py
  python3 -m unittest tests.test_schema_lint

Requirements:
  - PyYAML (pip install PyYAML==6.0.2)
  - yamllint (pip install yamllint==1.38.0) -- if missing, the yamllint
    TestCase auto-skips with a clear message.

Exit codes: 0 success, 1 lint failure, 2 environment / setup error.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import unittest
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip install PyYAML==6.0.2",
          file=sys.stderr)
    sys.exit(2)

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = REPO_ROOT / "schema"
SCHEMA_FILE = SCHEMA_DIR / "thai_phonetic.schema.yaml"
DICT_FILE = SCHEMA_DIR / "thai_phonetic.dict.yaml"
CUSTOM_FILE = SCHEMA_DIR / "default.custom.yaml"
YAMLLINT_CONFIG = REPO_ROOT / ".yamllint"
FIXTURES_DIR = REPO_ROOT / "tests" / "fixtures"

ALLOWED_TOP_KEYS = frozenset({
    "schema", "switches", "engine", "speller", "translator",
    "punctuator", "key_binder", "recognizer", "menu", "page_size",
})
ALLOWED_ALGEBRA_OPS = frozenset({
    "xform", "derive", "xlit", "erase", "abbrev", "fuzz",
})
ALLOWED_IMPORT_PRESETS = frozenset({
    "default", "symbols", "key_bindings", "punctuation",
})


# ---------------------------------------------------------------------------
# Validator functions — return (ok: bool, error_message: str)
# ---------------------------------------------------------------------------

def validate_schema_structure(path: Path) -> tuple[bool, str]:
    """Validate the structural constraints of a Rime .schema.yaml file.

    Checks:
    - schema.schema_id is a non-empty string
    - schema.version is a non-empty string
    - top-level keys are a subset of ALLOWED_TOP_KEYS
    - every speller.algebra entry is a string with the right shape:
        <op>/<pattern>/<replacement>[/<flags>] where op in ALLOWED_ALGEBRA_OPS
        and the rule has >= 3 slash-separated parts

    CP-5 NOTE: We validate rule SHAPE only. We do NOT call re.compile() on the
    pattern or replacement fields. Python re != boost::regex.
    """
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        return False, f"YAML parse error in {path.name}: {exc}"

    if not isinstance(data, dict):
        return False, f"{path.name}: top-level document is not a mapping"

    # Top-level key allowlist
    unknown = set(data.keys()) - ALLOWED_TOP_KEYS
    if unknown:
        return False, (
            f"{path.name}: unknown top-level keys: {sorted(unknown)!r}. "
            f"Allowed: {sorted(ALLOWED_TOP_KEYS)!r}"
        )

    # schema.schema_id
    schema_block = data.get("schema")
    if not isinstance(schema_block, dict):
        return False, f"{path.name}: 'schema' block is missing or not a mapping"
    schema_id = schema_block.get("schema_id")
    if not schema_id or not isinstance(schema_id, str):
        return False, (
            f"{path.name}: schema.schema_id is missing or empty. "
            "Required key per Rime convention."
        )

    # schema.version
    version = schema_block.get("version")
    if not version or not isinstance(version, str):
        return False, f"{path.name}: schema.version is missing or empty"

    # speller.algebra rule shape
    speller = data.get("speller")
    if isinstance(speller, dict):
        algebra = speller.get("algebra")
        if algebra is not None:
            if not isinstance(algebra, list):
                return False, f"{path.name}: speller.algebra must be a list"
            for i, rule in enumerate(algebra):
                if not isinstance(rule, str):
                    return False, (
                        f"{path.name}: speller.algebra[{i}] is not a string: {rule!r}"
                    )
                parts = rule.split("/")
                if len(parts) < 3:
                    return False, (
                        f"{path.name}: speller.algebra[{i}] '{rule}' has only "
                        f"{len(parts)} slash-separated part(s); valid rules have "
                        f">= 3 parts: <op>/<pattern>/<replacement>/[<flags>]"
                    )
                op = parts[0]
                if op not in ALLOWED_ALGEBRA_OPS:
                    return False, (
                        f"{path.name}: speller.algebra[{i}] '{rule}' starts with "
                        f"unknown op '{op}'. Allowed ops: {sorted(ALLOWED_ALGEBRA_OPS)!r}"
                    )

    return True, ""


def validate_dict_structure(path: Path) -> tuple[bool, str]:
    """Validate the structural constraints of a Rime .dict.yaml file.

    The dict file is two-document format:
    - YAML frontmatter (terminated by `...`) parsed with yaml.safe_load
    - TSV body (after `...`): one row per non-blank non-comment line,
      exactly 3 tab-separated columns: <thai>\\t<romanization>\\t<weight>
      where weight is a non-negative integer.

    Parse pattern mirrors tests/test_dict.py and scripts/merge_dict.py.
    """
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        return False, f"Cannot read {path.name}: {exc}"

    # Split at the YAML end-of-document marker `...` on its own line
    # The frontmatter ends at the first `\n...\n` (or `\n...` at EOF)
    BODY_SEP = "\n...\n"
    sep_pos = raw.find(BODY_SEP)
    if sep_pos == -1:
        # Try `\n...` at end of file
        if raw.rstrip().endswith("\n..."):
            frontmatter_raw = raw.rstrip()[: raw.rstrip().rfind("\n...")]
            body_raw = ""
        else:
            return False, f"{path.name}: no YAML end-document marker '...' found"
    else:
        frontmatter_raw = raw[:sep_pos]
        body_raw = raw[sep_pos + len(BODY_SEP):]

    # Parse frontmatter
    try:
        fm = yaml.safe_load(frontmatter_raw)
    except yaml.YAMLError as exc:
        return False, f"{path.name}: YAML parse error in frontmatter: {exc}"

    if not isinstance(fm, dict):
        return False, f"{path.name}: frontmatter is not a mapping"

    # name
    name = fm.get("name")
    if not name or not isinstance(name, str):
        return False, f"{path.name}: frontmatter 'name' is missing or empty"

    # version
    version = fm.get("version")
    if not version or not isinstance(version, str):
        return False, f"{path.name}: frontmatter 'version' is missing or empty"

    # columns
    columns = fm.get("columns")
    if not isinstance(columns, list):
        return False, f"{path.name}: frontmatter 'columns' is missing or not a list"
    expected_cols = ["text", "code", "weight"]
    if columns != expected_cols:
        return False, (
            f"{path.name}: frontmatter 'columns' is {columns!r}, "
            f"expected {expected_cols!r}"
        )

    # Body: line-by-line TSV validation
    for lineno, line in enumerate(body_raw.splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 3:
            return False, (
                f"{path.name}: body line {lineno} has {len(parts)} tab-separated "
                f"column(s), expected exactly 3. Line: {line!r}"
            )
        weight_str = parts[2].strip()
        try:
            weight = int(weight_str)
        except ValueError:
            return False, (
                f"{path.name}: body line {lineno} weight column is not an integer: "
                f"{weight_str!r}"
            )
        if weight < 0:
            return False, (
                f"{path.name}: body line {lineno} has negative weight {weight} "
                f"(value: {weight_str!r}). Weight must be >= 0. "
                f"Row: {line!r}"
            )

    return True, ""


def validate_custom_structure(path: Path) -> tuple[bool, str]:
    """Validate the structural constraints of default.custom.yaml.

    Checks:
    - Top-level keys are exactly {'patch'}
    - patch.schema_list is a list
    - Every entry in schema_list is a dict with key 'schema' (string)
    - 'thai_phonetic' is one of the listed schemas
    """
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        return False, f"YAML parse error in {path.name}: {exc}"

    if not isinstance(data, dict):
        return False, f"{path.name}: top-level document is not a mapping"

    if set(data.keys()) != {"patch"}:
        return False, (
            f"{path.name}: top-level keys are {set(data.keys())!r}, "
            f"expected exactly {{'patch'}}"
        )

    patch = data["patch"]
    if not isinstance(patch, dict):
        return False, f"{path.name}: 'patch' value is not a mapping"

    schema_list = patch.get("schema_list")
    if not isinstance(schema_list, list):
        return False, f"{path.name}: patch.schema_list is missing or not a list"

    for i, entry in enumerate(schema_list):
        if not isinstance(entry, dict):
            return False, (
                f"{path.name}: patch.schema_list[{i}] is not a mapping: {entry!r}"
            )
        if "schema" not in entry:
            return False, (
                f"{path.name}: patch.schema_list[{i}] is missing required key 'schema'"
            )
        if not isinstance(entry["schema"], str):
            return False, (
                f"{path.name}: patch.schema_list[{i}].schema is not a string: "
                f"{entry['schema']!r}"
            )

    listed_schemas = [e["schema"] for e in schema_list if isinstance(e, dict)]
    if "thai_phonetic" not in listed_schemas:
        return False, (
            f"{path.name}: 'thai_phonetic' not found in patch.schema_list. "
            f"Listed schemas: {listed_schemas!r}"
        )

    return True, ""


def _walk_yaml_tree(node: object):
    """Depth-first walk of a YAML tree; yields every dict found."""
    if isinstance(node, dict):
        yield node
        for v in node.values():
            yield from _walk_yaml_tree(v)
    elif isinstance(node, list):
        for item in node:
            yield from _walk_yaml_tree(item)


def validate_import_preset_resolution(path: Path) -> tuple[bool, str]:
    """Walk the YAML tree; for every import_preset value found, assert it is
    in ALLOWED_IMPORT_PRESETS = {default, symbols, key_bindings, punctuation}.

    Valid presets are those shipped with standard Rime/Squirrel/Weasel installs.
    An unknown preset name causes a Rime deploy error at runtime.
    """
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        return False, f"YAML parse error in {path.name}: {exc}"

    for node in _walk_yaml_tree(data):
        if "import_preset" in node:
            preset = node["import_preset"]
            if preset not in ALLOWED_IMPORT_PRESETS:
                return False, (
                    f"{path.name}: import_preset '{preset}' is not a known Rime "
                    f"preset. Valid presets: {sorted(ALLOWED_IMPORT_PRESETS)!r}. "
                    f"Unknown preset: '{preset}'"
                )

    return True, ""


# ---------------------------------------------------------------------------
# TestCase classes
# ---------------------------------------------------------------------------

class TestSchemaStructure(unittest.TestCase):
    """Structural validation of schema/thai_phonetic.schema.yaml (v0.0.6 baseline)."""

    def test_baseline_schema_passes(self):
        ok, msg = validate_schema_structure(SCHEMA_FILE)
        self.assertTrue(ok, msg=f"baseline schema failed validation: {msg}")

    def test_missing_schema_id_rejected(self):
        """validate_schema_structure must reject a schema missing schema.schema_id."""
        fixture = FIXTURES_DIR / "broken_schema_missing_schema_id.yaml"
        ok, msg = validate_schema_structure(fixture)
        self.assertFalse(ok, msg="expected failure for missing schema_id but got ok=True")
        self.assertIn("schema_id", msg,
                      msg=f"error message should mention 'schema_id'; got: {msg!r}")

    def test_malformed_algebra_rejected(self):
        """validate_schema_structure must reject a schema with too-few slash parts."""
        fixture = FIXTURES_DIR / "broken_schema_malformed_algebra.yaml"
        ok, msg = validate_schema_structure(fixture)
        self.assertFalse(ok, msg="expected failure for malformed algebra but got ok=True")
        # Either the rule text or the word "slash" or "parts" must appear in the message
        self.assertTrue(
            "derive/ph" in msg or "slash" in msg or "parts" in msg,
            msg=f"error message should reference 'derive/ph' or slash/parts; got: {msg!r}",
        )


class TestDictStructure(unittest.TestCase):
    """Structural validation of schema/thai_phonetic.dict.yaml (v0.0.6 baseline)."""

    def test_baseline_dict_passes(self):
        ok, msg = validate_dict_structure(DICT_FILE)
        self.assertTrue(ok, msg=f"baseline dict failed validation: {msg}")

    def test_negative_weight_rejected(self):
        """validate_dict_structure must reject a dict body row with negative weight."""
        fixture = FIXTURES_DIR / "broken_schema_negative_weight.yaml"
        ok, msg = validate_dict_structure(fixture)
        self.assertFalse(ok, msg="expected failure for negative weight but got ok=True")
        self.assertTrue(
            "weight" in msg and ("-50" in msg or "negative" in msg),
            msg=(
                f"error message should mention 'weight' and '-50' or 'negative'; "
                f"got: {msg!r}"
            ),
        )


class TestCustomStructure(unittest.TestCase):
    """Structural validation of schema/default.custom.yaml (v0.0.6 baseline)."""

    def test_baseline_custom_passes(self):
        ok, msg = validate_custom_structure(CUSTOM_FILE)
        self.assertTrue(ok, msg=f"baseline custom file failed validation: {msg}")


class TestImportPresetResolution(unittest.TestCase):
    """import_preset reference resolution against the known-preset allowlist."""

    def test_baseline_schema_import_presets_pass(self):
        """v0.0.6 schema uses only known presets (symbols, default)."""
        ok, msg = validate_import_preset_resolution(SCHEMA_FILE)
        self.assertTrue(
            ok,
            msg=f"baseline schema has unexpected import_preset value: {msg}",
        )

    def test_bad_import_preset_rejected(self):
        """validate_import_preset_resolution must reject an unknown preset name."""
        fixture = FIXTURES_DIR / "broken_schema_bad_import_preset.yaml"
        ok, msg = validate_import_preset_resolution(fixture)
        self.assertFalse(ok,
                         msg="expected failure for bad import_preset but got ok=True")
        self.assertIn(
            "nonexistent_preset_xyz", msg,
            msg=f"error message should name the unknown preset; got: {msg!r}",
        )


class TestYamllintBaseline(unittest.TestCase):
    """yamllint style/syntax checks on the v0.0.6 baseline schema files.

    The dict file (thai_phonetic.dict.yaml) is excluded from yamllint via
    the `ignore` rule in .yamllint because its TSV body contains tab characters
    that cannot be parsed as YAML tokens. Its frontmatter is validated by
    TestDictStructure via PyYAML instead.
    """

    @unittest.skipUnless(shutil.which("yamllint"), "yamllint not installed")
    def test_baseline_yamllint_passes(self):
        """yamllint against all three baseline files exits 0."""
        result = subprocess.run(
            [
                "yamllint",
                "-c", str(YAMLLINT_CONFIG),
                str(SCHEMA_FILE),
                str(DICT_FILE),
                str(CUSTOM_FILE),
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(
            result.returncode, 0,
            msg=(
                f"yamllint exited {result.returncode}\n"
                f"stdout:\n{result.stdout}\n"
                f"stderr:\n{result.stderr}"
            ),
        )


class TestNegativeFixtures(unittest.TestCase):
    """Each broken-schema fixture must provoke a specific, named failure mode."""

    def test_negative_weight_rejected(self):
        """Fixture with negative dict weight must fail validate_dict_structure."""
        fixture = FIXTURES_DIR / "broken_schema_negative_weight.yaml"
        self.assertTrue(fixture.is_file(), f"fixture missing: {fixture}")
        ok, msg = validate_dict_structure(fixture)
        self.assertFalse(ok, msg="expected (False, msg) for negative weight fixture")
        self.assertTrue(
            "weight" in msg and ("-50" in msg or "negative" in msg),
            msg=f"error message should name 'weight' and '-50'/'negative'; got: {msg!r}",
        )

    def test_bad_import_preset_rejected(self):
        """Fixture with unknown import_preset must fail validate_import_preset_resolution."""
        fixture = FIXTURES_DIR / "broken_schema_bad_import_preset.yaml"
        self.assertTrue(fixture.is_file(), f"fixture missing: {fixture}")
        ok, msg = validate_import_preset_resolution(fixture)
        self.assertFalse(ok, msg="expected (False, msg) for bad import_preset fixture")
        self.assertIn(
            "nonexistent_preset_xyz", msg,
            msg=f"error message should name the bad preset; got: {msg!r}",
        )

    def test_missing_schema_id_rejected(self):
        """Fixture missing schema.schema_id must fail validate_schema_structure."""
        fixture = FIXTURES_DIR / "broken_schema_missing_schema_id.yaml"
        self.assertTrue(fixture.is_file(), f"fixture missing: {fixture}")
        ok, msg = validate_schema_structure(fixture)
        self.assertFalse(ok, msg="expected (False, msg) for missing schema_id fixture")
        self.assertIn(
            "schema_id", msg,
            msg=f"error message should mention 'schema_id'; got: {msg!r}",
        )

    def test_malformed_algebra_rejected(self):
        """Fixture with too-few slash parts in algebra must fail validate_schema_structure."""
        fixture = FIXTURES_DIR / "broken_schema_malformed_algebra.yaml"
        self.assertTrue(fixture.is_file(), f"fixture missing: {fixture}")
        ok, msg = validate_schema_structure(fixture)
        self.assertFalse(ok, msg="expected (False, msg) for malformed algebra fixture")
        self.assertTrue(
            "derive/ph" in msg or "slash" in msg or "parts" in msg,
            msg=f"error message should reference 'derive/ph' or slash/parts; got: {msg!r}",
        )


class TestRegexBodyNotCompiled(unittest.TestCase):
    """CP-5 guard: this lint module must NEVER call re.compile() on algebra rule bodies.

    Python's `re` module diverges from boost::regex on:
      - \\< \\> word boundaries (not in Python re)
      - [[:alpha:]] POSIX character classes (not in Python re)
      - \\Q...\\E literal blocks (not in Python re)
      - variable-width lookbehind (Python re rejects; boost::regex allows)

    Compiling algebra rule bodies in Python would produce false positives that
    block legitimate Rime regex. The engine-mode test is the regex oracle:
      python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml

    This test reads its own source and asserts no re.compile() call appears on a
    line that also references algebra or derive (the proxies for "operating on a
    rule body"). Enforced as CP-5 in .planning/research/PITFALLS.md.
    """

    def test_no_regex_compilation_of_algebra_bodies(self):
        """CP-5: lint must NOT call re.compile() on algebra rule bodies.

        Implementation-level guard: this module must not import Python's `re`
        module at all for algebra body compilation. If `import re` (or
        `from re import`) appears in the executable source, a future contributor
        may inadvertently call re.compile() on a rule body, producing false
        positives (Python re != boost::regex for \\<, \\>, [[:alpha:]], \\Q\\E).

        We enforce this at the import level: no `import re` / `from re import`
        in this file means re.compile() on algebra bodies is structurally
        impossible. The engine-mode test is the regex oracle.
        """
        import tokenize
        import io

        src = Path(__file__).read_text(encoding="utf-8")

        # Walk tokens and collect NAME tokens with value 're' that appear in
        # import statements (i.e., preceded by 'import' or 'from').
        # This correctly skips re.compile() inside string literals/docstrings.
        tokens = list(tokenize.generate_tokens(io.StringIO(src).readline))
        import_re_found = False
        for i, tok in enumerate(tokens):
            if tok.type == tokenize.NAME and tok.string in ("import", "from"):
                # Check if any of the next few tokens is 're'
                window = tokens[i + 1: i + 4]
                if any(t.type == tokenize.NAME and t.string == "re" for t in window):
                    import_re_found = True
                    break

        self.assertFalse(
            import_re_found,
            msg=(
                "CP-5 violation: 'import re' or 'from re import' found in "
                "test_schema_lint.py. This module must NOT import Python's re "
                "module for algebra body compilation -- Python re != boost::regex. "
                "Use the engine-mode test (test_dict.py --use-rime-api-console) "
                "as the regex oracle instead."
            ),
        )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    for required in (SCHEMA_FILE, DICT_FILE, CUSTOM_FILE, YAMLLINT_CONFIG):
        if not required.is_file():
            print(f"FAIL  required file missing: {required}", file=sys.stderr)
            return 2
    for f in (
        "broken_schema_negative_weight.yaml",
        "broken_schema_bad_import_preset.yaml",
        "broken_schema_missing_schema_id.yaml",
        "broken_schema_malformed_algebra.yaml",
    ):
        if not (FIXTURES_DIR / f).is_file():
            print(f"FAIL  fixture missing: {FIXTURES_DIR / f}", file=sys.stderr)
            return 2
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    for cls in (
        TestSchemaStructure,
        TestDictStructure,
        TestCustomStructure,
        TestImportPresetResolution,
        TestYamllintBaseline,
        TestNegativeFixtures,
        TestRegexBodyNotCompiled,
    ):
        suite.addTests(loader.loadTestsFromTestCase(cls))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
