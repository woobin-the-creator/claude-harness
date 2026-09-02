#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd -P)
REFS="$ROOT/woobin-harness/skills/design-workflow/references"

for file in principles direction system-evidence implementation-contracts review evolution sources; do
  test -s "$REFS/$file.md"
done

# R21 — principles carries mechanisms and questions, never prescriptions or the
# published constants. These greps are what keeps a later edit from quietly
# turning it back into a rule sheet.
grep -F '## Load this module when' "$REFS/principles.md"
grep -F 'lenses, not rules' "$REFS/principles.md"
grep -F 'never convert one into a number' "$REFS/principles.md"
grep -F 'the local authority wins' "$REFS/principles.md"
grep -F 'Weakens when:' "$REFS/principles.md"
grep -F 'lawsofux.com' "$REFS/principles.md"
for law in Proximity 'Common Region' Similarity 'Uniform Connectedness' Prägnanz "Fitts's Law" 'Doherty Threshold' "Hick's Law" "Jakob's Law" Chunking 'Von Restorff' 'Serial Position' 'Selective Attention' "Postel's Law" "Tesler's Law" 'Peak-End' 'Goal-Gradient' Zeigarnik 'Aesthetic-Usability' 'Mental Model' 'Paradox of the Active User'; do
  grep -F "$law" "$REFS/principles.md" >/dev/null
done

grep -F '## Load this module when' "$REFS/direction.md"
grep -F '## Do not load this module when' "$REFS/direction.md"
grep -F '실제 사용자' "$REFS/direction.md"
grep -F 'signature' "$REFS/direction.md"
grep -F 'focal point' "$REFS/direction.md"

grep -F 'user-decision' "$REFS/system-evidence.md"
grep -F 'external-precedent' "$REFS/system-evidence.md"
grep -F '실제로 잘렸을 때만' "$REFS/system-evidence.md"
# The prescriptions were removed under R21, but the incidents that produced them
# are the part a later session cannot recover from the code. Keep them pinned.
grep -F 'Observed: a mockup rendered KPI labels' "$REFS/system-evidence.md"
grep -F '08-11 > 08-12' "$REFS/system-evidence.md"

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
