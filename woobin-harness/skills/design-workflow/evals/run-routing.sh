#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: run-routing.sh <case-name|all>" >&2
  exit 2
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found on PATH" >&2
  exit 127
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd -P)
PLUGIN_DIR="$ROOT/woobin-harness"
CASES_DIR="$SCRIPT_DIR/cases"
ASSERT="$SCRIPT_DIR/assert-routing.mjs"
REQUESTED="$1"
OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/design-workflow-routing.XXXXXX")

if [ "$REQUESTED" = all ]; then
  CASES="established-first-use greenfield incremental review-only guard-promotion"
else
  CASES="$REQUESTED"
fi

for case_name in $CASES; do
  case_file="$CASES_DIR/$case_name.md"
  output_file="$OUT_DIR/$case_name.out"
  test -s "$case_file"
  echo "EVAL case=$case_name"
  claude -p "$(cat "$case_file")" \
    --plugin-dir "$PLUGIN_DIR" \
    --output-format text \
    >"$output_file"
  node "$ASSERT" "$case_name" "$output_file"
  echo "EVAL_OK case=$case_name"
done
