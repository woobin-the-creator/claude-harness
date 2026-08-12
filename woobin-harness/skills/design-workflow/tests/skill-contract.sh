#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd -P)
WORKFLOW="$ROOT/woobin-harness/skills/design-workflow/SKILL.md"
LEGACY="$ROOT/woobin-harness/skills/design-rules/SKILL.md"

test -s "$WORKFLOW"
grep -F 'name: design-workflow' "$WORKFLOW"
grep -F 'DESIGN.md가 없어도 작업을 멈추지 않는다' "$WORKFLOW"
grep -F 'DESIGN_UNMANAGED' "$WORKFLOW"
grep -F '작업 유형:' "$WORKFLOW"
grep -F 'review-only' "$WORKFLOW"
grep -F 'CI failure gate' "$WORKFLOW"
grep -F 'references/direction.md' "$WORKFLOW"
grep -F 'references/system-evidence.md' "$WORKFLOW"
grep -F 'references/implementation-contracts.md' "$WORKFLOW"
grep -F 'references/review.md' "$WORKFLOW"
grep -F 'references/evolution.md' "$WORKFLOW"
grep -F 'scripts/validate-design-md.mjs' "$WORKFLOW"

grep -F 'name: design-rules' "$LEGACY"
grep -F '../design-workflow/references/system-evidence.md' "$LEGACY"
grep -F '../design-workflow/references/implementation-contracts.md' "$LEGACY"
grep -F '../design-workflow/references/review.md' "$LEGACY"
if grep -F '시안에서 무엇을 골라야 하는지 판단할 때' "$LEGACY"; then
  echo 'design-rules still owns workflow-level candidate selection trigger' >&2
  exit 1
fi

test "$(wc -l < "$WORKFLOW")" -le 150
test "$(wc -l < "$LEGACY")" -le 80

echo ALL-OK
