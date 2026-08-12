#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd -P)
SKILL="$ROOT/woobin-harness/skills/design-workflow"
CLI="$SKILL/scripts/validate-design-md.mjs"
FIXTURES="$SKILL/tests/fixtures"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/design-workflow-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

output=$(node "$CLI" "$FIXTURES/design-absent")
printf '%s\n' "$output" | grep -F 'DESIGN_ABSENT path='

output=$(node "$CLI" "$FIXTURES/design-unmanaged")
printf '%s\n' "$output" | grep -F 'DESIGN_UNMANAGED path='

output=$(node "$CLI" "$FIXTURES/design-valid-minimal")
test "$output" = 'DESIGN_OK schema=1 decisions=0'

cp -R "$FIXTURES/design-valid-full/." "$TMP_ROOT/"
output=$(node "$CLI" "$TMP_ROOT/DESIGN.md")
test "$output" = 'DESIGN_OK schema=1 decisions=2'

if node "$CLI" "$FIXTURES/design-invalid-json" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
  echo 'invalid JSON unexpectedly passed' >&2
  exit 1
fi
grep -F 'DESIGN_E_JSON' "$TMP_ROOT/err"

if node "$CLI" "$FIXTURES/design-invalid-schema" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
  echo 'unsupported managed schema unexpectedly passed' >&2
  exit 1
fi
grep -F 'DESIGN_E_FRONTMATTER_SCHEMA' "$TMP_ROOT/err"

if node "$CLI" "$FIXTURES/design-invalid-external-adopted" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
  echo 'unverified external adoption unexpectedly passed' >&2
  exit 1
fi
grep -F 'DESIGN_E_EXTERNAL_NEEDS_LOCAL_EVIDENCE' "$TMP_ROOT/err"

if node "$CLI" "$FIXTURES/design-invalid-enforcement" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
  echo 'missing enforcement unexpectedly passed' >&2
  exit 1
fi
grep -F 'DESIGN_E_ENFORCEMENT_REQUIRED' "$TMP_ROOT/err"

echo ALL-OK
