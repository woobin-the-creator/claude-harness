#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd -P)
REFS="$ROOT/woobin-harness/skills/design-workflow/references"

for file in direction system-evidence implementation-contracts review evolution sources; do
  test -s "$REFS/$file.md"
done

grep -F '## Load this module when' "$REFS/direction.md"
grep -F '## Do not load this module when' "$REFS/direction.md"
grep -F '실제 사용자' "$REFS/direction.md"
grep -F 'signature' "$REFS/direction.md"
grep -F 'focal point' "$REFS/direction.md"

grep -F 'user-decision' "$REFS/system-evidence.md"
grep -F 'external-precedent' "$REFS/system-evidence.md"
grep -F '실제로 잘렸을 때만' "$REFS/system-evidence.md"
grep -F '한 줄' "$REFS/system-evidence.md"

grep -F 'validate → normalize → render' "$REFS/implementation-contracts.md"
grep -F 'measure → reserve affordance' "$REFS/implementation-contracts.md"
grep -F 'launcher focus' "$REFS/implementation-contracts.md"
grep -F 'existing design system → native HTML → accessible primitive → custom implementation' "$REFS/implementation-contracts.md"
grep -F 'header and body together' "$REFS/implementation-contracts.md"
grep -F 'dirty input' "$REFS/implementation-contracts.md"

grep -F 'blocker' "$REFS/review.md"
grep -F 'should-fix' "$REFS/review.md"
grep -F 'review-only' "$REFS/review.md"

grep -F 'observed → candidate → adopted' "$REFS/evolution.md"
grep -F 'CI failure gate' "$REFS/evolution.md"
grep -F 'owner' "$REFS/evolution.md"
grep -F 'expires' "$REFS/evolution.md"

grep -F '2f9be3206855bcb2d1d0af262c8bae25cba6658d' "$REFS/sources.md"
grep -F 'eeff1e98ac8332f60a90d015dea2ba7c38edd26d' "$REFS/sources.md"
grep -F 'Apache-2.0' "$REFS/sources.md"
grep -F 'MIT' "$REFS/sources.md"
grep -F 'packages/ibm-products/src/components/ActionSet/ActionSet.tsx' "$REFS/sources.md"
grep -F 'packages/ibm-products/src/global/js/hooks/useOverflowItems/useOverflowItems.ts' "$REFS/sources.md"
grep -F 'packages/ibm-products/src/components/RemoveModal/RemoveModal.tsx' "$REFS/sources.md"
grep -F 'packages/ibm-products/src/components/StatusIndicator/StatusIndicator.jsx' "$REFS/sources.md"
grep -F '.stylelintrc.js' "$REFS/sources.md"
grep -F 'achecker.js' "$REFS/sources.md"
grep -F 'playwright.config.js' "$REFS/sources.md"
grep -F '.github/workflows/ci.yml' "$REFS/sources.md"
grep -F '.avt/baseline' "$REFS/sources.md"
grep -F '.avt/' "$REFS/sources.md"
grep -F 'root typecheck gap' "$REFS/sources.md"
grep -F 'denylist' "$REFS/sources.md"
grep -F 'test.skip' "$REFS/sources.md"
grep -F 'owner, reason, and expiry' "$REFS/sources.md"

echo ALL-OK
