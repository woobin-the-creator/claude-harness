#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
EVAL_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../evals" && pwd -P)
CASES_DIR="$EVAL_DIR/cases"
ASSERT="$EVAL_DIR/assert-routing.mjs"
RUNNER="$EVAL_DIR/run-routing.sh"
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/design-workflow-eval-contract.XXXXXX")

assert_prompt_contract() {
  case_name="$1"
  case_file="$CASES_DIR/$case_name.md"
  test -s "$case_file"
  grep -F 'Use the repository-local `design-workflow` skill explicitly.' "$case_file" >/dev/null
  grep -F 'Respond only with these exact five lines:' "$case_file" >/dev/null
  grep -F 'ROUTE=<ordered module names>' "$case_file" >/dev/null
  grep -F 'DESIGN_BEHAVIOR=<absent|validate|unmanaged>' "$case_file" >/dev/null
  grep -F 'LOCAL_MUTATION=<allowed|forbidden>' "$case_file" >/dev/null
  grep -F 'ESCALATION=<allowed|approval-required|forbidden>' "$case_file" >/dev/null
  grep -F 'FIRST_ACTION=<one sentence starting with the route announcement: 작업 유형: <mode> · 사용 모듈: <ordered module names>>' "$case_file" >/dev/null
}

assert_output_contract() {
  case_name="$1"
  route="$2"
  design="$3"
  local_mutation="$4"
  escalation="$5"
  output_file="$TMP_DIR/$case_name.out"
  {
    printf 'ROUTE=%s\n' "$route"
    printf 'DESIGN_BEHAVIOR=%s\n' "$design"
    printf 'LOCAL_MUTATION=%s\n' "$local_mutation"
    printf 'ESCALATION=%s\n' "$escalation"
    printf 'FIRST_ACTION=작업 유형: eval · 사용 모듈: %s — inspect only enough context to classify.\n' "$route"
  } >"$output_file"
  node "$ASSERT" "$case_name" "$output_file"
}

for case_name in established-first-use greenfield incremental review-only guard-promotion; do
  assert_prompt_contract "$case_name"
done

assert_output_contract established-first-use 'system-evidence → implementation-contracts → review' absent allowed approval-required
assert_output_contract greenfield 'direction → system-evidence → implementation-contracts → review' absent allowed approval-required
assert_output_contract incremental 'system-evidence → implementation-contracts → review' validate allowed approval-required
assert_output_contract review-only 'system-evidence → review' validate forbidden forbidden
assert_output_contract guard-promotion 'system-evidence → implementation-contracts → evolution → review' absent allowed approval-required

if sh "$RUNNER" ../review-only >/dev/null 2>&1; then
  echo "expected invalid eval case to fail" >&2
  exit 1
else
  status="$?"
  test "$status" -eq 2
fi

echo ALL-OK
