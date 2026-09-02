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

assert_fixture_route() {
  fixture="$1"
  expected="$2"
  actual=$(
    awk '
      $0 == "# Expected route" { capture = 1; next }
      capture && $0 != "" { print; exit }
    ' "$ROUTES/$fixture.md"
  )
  test "$actual" = "$expected"
}

grep -F '작업 유형: <mode> · 사용 모듈: <ordered modules>' "$SKILL" >/dev/null
grep -F '| Existing project, first explicit use | principles → system-evidence → implementation-contracts → review | Scope inspection to current work; propose DESIGN.md only after durable value appears |' "$SKILL" >/dev/null
grep -F '| Greenfield | principles → direction → system-evidence → implementation-contracts → review | Obtain approval for direction before adoption |' "$SKILL" >/dev/null
grep -F '| Established incremental UI | principles → system-evidence → implementation-contracts → review | Skip direction |' "$SKILL" >/dev/null
grep -F '| Large redesign | principles → direction → system-evidence → implementation-contracts → review → evolution | Keep new direction candidate until approved |' "$SKILL" >/dev/null
grep -F '| Review-only | principles → system-evidence → review | Do not edit files |' "$SKILL" >/dev/null
grep -F '| Recurring failure/enforce | principles → system-evidence → implementation-contracts → evolution → review | Choose lowest effective guard; respect approval boundary |' "$SKILL" >/dev/null
grep -F '| Render-invariant logic | none | State that this skill does not apply and continue normal engineering work |' "$SKILL" >/dev/null

assert_fixture_route established-first-use 'principles → system-evidence → implementation-contracts → review'
assert_fixture_route greenfield 'principles → direction → system-evidence → implementation-contracts → review'
assert_fixture_route incremental 'principles → system-evidence → implementation-contracts → review'
assert_fixture_route review-only 'principles → system-evidence → review'
assert_fixture_route guard-promotion 'principles → system-evidence → implementation-contracts → evolution → review'
assert_fixture_route design-managed 'principles → system-evidence → implementation-contracts → review'
assert_fixture_route design-unmanaged 'principles → system-evidence → implementation-contracts → review'

grep -F 'principles → system-evidence → implementation-contracts → review' "$ROUTES/established-first-use.md"
grep -F 'principles → direction → system-evidence → implementation-contracts → review' "$ROUTES/greenfield.md"
grep -F 'review-only' "$ROUTES/review-only.md"
grep -F '파일을 수정' "$ROUTES/review-only.md"
grep -F 'CI failure gate' "$ROUTES/guard-promotion.md"
grep -F 'DESIGN_UNMANAGED' "$ROUTES/design-unmanaged.md"

for route in direction implementation review enforcement; do
  grep -F "$route" "$SKILL" >/dev/null
done

echo ALL-OK
