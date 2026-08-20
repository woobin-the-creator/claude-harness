#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: run-routing.sh <case-name|all>" >&2
  exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd -P)
PLUGIN_DIR="$ROOT/woobin-harness"
CASES_DIR="$SCRIPT_DIR/cases"
ASSERT="$SCRIPT_DIR/assert-routing.mjs"
TIMEOUT_RUNNER="$SCRIPT_DIR/run-with-timeout.mjs"
REQUESTED="$1"
ROUTING_TIMEOUT_SECONDS="${ROUTING_TIMEOUT_SECONDS:-120}"
CLAUDE_MAX_BUDGET_USD="${CLAUDE_MAX_BUDGET_USD:-0.05}"

ALL_CASES="established-first-use greenfield incremental review-only guard-promotion"
case "$REQUESTED" in
  all)
    CASES="$ALL_CASES"
    ;;
  established-first-use|greenfield|incremental|review-only|guard-promotion)
    CASES="$REQUESTED"
    ;;
  *)
    echo "unknown routing eval case: $REQUESTED" >&2
    exit 2
    ;;
esac

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found on PATH" >&2
  exit 127
fi

OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/design-workflow-routing.XXXXXX")
cleanup() {
  rm -rf "$OUT_DIR"
}
trap cleanup EXIT HUP INT TERM

for case_name in $CASES; do
  case_file="$CASES_DIR/$case_name.md"
  output_file="$OUT_DIR/$case_name.out"
  test -s "$case_file"
  echo "EVAL case=$case_name"
  node "$TIMEOUT_RUNNER" "$ROUTING_TIMEOUT_SECONDS" "$output_file" "EVAL_TIMEOUT case=$case_name seconds=$ROUTING_TIMEOUT_SECONDS" -- \
    claude -p "$(cat "$case_file")" \
    --plugin-dir "$PLUGIN_DIR" \
    --max-budget-usd "$CLAUDE_MAX_BUDGET_USD" \
    --no-session-persistence \
    --permission-mode plan \
    --tools "" \
    --output-format text \
    || exit "$?"
  node "$ASSERT" "$case_name" "$output_file"
  echo "EVAL_OK case=$case_name"
done
