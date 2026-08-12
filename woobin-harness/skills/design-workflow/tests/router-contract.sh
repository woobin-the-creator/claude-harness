#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd -P)
SKILL="$ROOT/woobin-harness/skills/design-workflow/SKILL.md"
ROUTES="$ROOT/woobin-harness/skills/design-workflow/tests/fixtures/routes"

for fixture in established-first-use greenfield incremental review-only guard-promotion design-managed design-unmanaged; do
  test -s "$ROUTES/$fixture.md"
  for heading in '# Context' '# User request' '# Expected route' '# Must do' '# Must not do'; do
    grep -F "$heading" "$ROUTES/$fixture.md" >/dev/null
  done
done

grep -F 'system-evidence → implementation-contracts → review' "$ROUTES/established-first-use.md"
grep -F 'direction → system-evidence → implementation-contracts → review' "$ROUTES/greenfield.md"
grep -F 'review-only' "$ROUTES/review-only.md"
grep -F '파일을 수정' "$ROUTES/review-only.md"
grep -F 'CI failure gate' "$ROUTES/guard-promotion.md"
grep -F 'DESIGN_UNMANAGED' "$ROUTES/design-unmanaged.md"

for route in direction implementation review enforcement; do
  grep -F "$route" "$SKILL" >/dev/null
done

echo ALL-OK
