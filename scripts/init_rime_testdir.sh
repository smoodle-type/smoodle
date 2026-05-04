#!/usr/bin/env bash
# Initialize a Rime working directory for librime CLI testing.
# Copies smoodle's schema + dict alongside the preset configs that Squirrel
# ships (default.yaml, punctuation.yaml, symbols.yaml, key_bindings.yaml),
# patching default.yaml's schema_list to just thai_phonetic so we don't
# need the bundled Mandarin schemas.
#
# Usage: scripts/init_rime_testdir.sh [test_dir]   (default: /tmp/smoodle-rime-test)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="${1:-/tmp/smoodle-rime-test}"
SQUIRREL_SHARED="/Library/Input Methods/Squirrel.app/Contents/SharedSupport"

if [ ! -d "$SQUIRREL_SHARED" ]; then
  echo "ERROR: Squirrel.app not found at /Library/Input Methods/Squirrel.app" >&2
  exit 1
fi

mkdir -p "$TEST_DIR"

# smoodle schema + dict
cp -f "$REPO/schema/thai_phonetic.schema.yaml" \
      "$REPO/schema/thai_phonetic.dict.yaml" \
      "$TEST_DIR/"

# Preset configs from Squirrel (default.yaml gets schema_list trimmed below)
for f in default.yaml punctuation.yaml symbols.yaml key_bindings.yaml; do
  cp -f "$SQUIRREL_SHARED/$f" "$TEST_DIR/"
done

# Trim default.yaml's schema_list to just thai_phonetic. Drop the bundled
# Mandarin/Cantonese schemas that aren't installed in this test dir.
python3 - "$TEST_DIR/default.yaml" <<'PY'
import sys, re
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
text = re.sub(
    r'schema_list:\n(?:  - schema:.*\n)+',
    'schema_list:\n  - schema: thai_phonetic\n',
    text,
    count=1,
)
open(p, "w", encoding="utf-8").write(text)
PY

# Discard any stale prism/userdb compilation
rm -rf "$TEST_DIR/build" "$TEST_DIR"/*.userdb*

echo "Initialized $TEST_DIR with thai_phonetic schema and Squirrel preset configs."
echo "Test it: echo 'sawadee' | vendor/librime/build/bin/rime_api_console 2>/dev/null | grep -E '^[0-9]'"
