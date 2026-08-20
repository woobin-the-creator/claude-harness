# Task 2: Progressively Disclosed Workflow Modules

**Files:**
- Create: `woobin-harness/skills/design-workflow/references/direction.md`
- Create: `woobin-harness/skills/design-workflow/references/system-evidence.md`
- Create: `woobin-harness/skills/design-workflow/references/implementation-contracts.md`
- Create: `woobin-harness/skills/design-workflow/references/review.md`
- Create: `woobin-harness/skills/design-workflow/references/evolution.md`
- Create: `woobin-harness/skills/design-workflow/references/sources.md`
- Create: `woobin-harness/skills/design-workflow/tests/module-contract.sh`

**Interfaces:**
- Consumes: the route names `direction`, `system-evidence`, `implementation-contracts`, `review`, and `evolution`.
- Produces: five independently readable references with no Router logic and one provenance reference.
- Later tasks consume: exact headings and load conditions asserted by `module-contract.sh`.

- [ ] **Step 1: Write the failing module contract test**

Create `tests/module-contract.sh`:

```sh
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

echo ALL-OK
```

- [ ] **Step 2: Run the contract and verify the missing-module failure**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/module-contract.sh
```

Expected: non-zero exit because the reference files do not exist.

- [ ] **Step 3: Write `direction.md` as a conditional decision protocol**

Use exactly these top-level sections:

```markdown
# Direction
## Load this module when
## Do not load this module when
## Inputs to inspect before asking
## Decisions that require the user
## Direction brief
## Candidate comparison
## Exit criteria
```

The module must require, only for greenfield or redesign:

- actual user and primary task verbs;
- intended feeling and operational risk;
- at least five domain concepts and five domain-natural color/material associations as exploration, not mandatory final tokens;
- one concrete signature and one focal point;
- three defaults to avoid;
- two or three candidates only when the direction is materially ambiguous or expensive to reverse;
- user selection before a candidate becomes adopted.

Explicitly skip the module for established-system incremental changes, bug fixes, review-only work with an adopted direction, and render-invariant logic changes. Do not copy `interface-design` prose, fixed palettes, named fonts, 60/30/10 ratios, or a universal one-accent rule.

- [ ] **Step 4: Write `system-evidence.md` by migrating the durable `design-rules` logic**

Use these sections:

```markdown
# System and evidence
## Load this module when
## Authority order
## Scope the repository read
## Classify what you find
## Tone and foundations
## Content-derived dimensions
## Information density and truth
## Accessibility evidence
## Self-comparison
## Record durable evidence
```

Preserve and consolidate the current `design-rules` behaviors:

- project values beat skill defaults;
- inspect real component/token sources, not screenshots alone;
- use actual minimum/maximum content before deciding dimensions;
- distinguish `user-decision`, `local-code`, `local-incident`, and `external-precedent`;
- measure light/dark contrast rather than infer it;
- compare against the no-discipline default and state the useful difference;
- do not turn a local observation into adopted policy.

Preserve the useful craft rules from #7 without making them universal taste laws:

- type hierarchy uses size, weight, and color together;
- dynamic numeric columns may use `tabular-nums`;
- nested surfaces use concentric radii when the project depth strategy calls for radii;
- headings and body copy define long-text wrapping behavior;
- optical alignment may override naive geometric centering with an explicit reason;
- `transition: all` and layout-property animation are not defaults;
- the project's adopted depth strategy beats generic border/shadow preferences.

Port the accepted `17994e0` outcomes without copying its old ownership structure:

- KPI labels and table headers require sufficient size/weight/color contrast, but do not blindly enlarge all labels;
- table cells default to a compact single line with explicit multiline exceptions;
- ellipsis communicates truncation and `title`/tooltip is attached **실제로 잘렸을 때만**;
- a rule record keeps wrong form, replacement, and observed consequence compact; long evidence moves to a reference.

Retain accessibility numbers accurately: WCAG 2.2 AA target-size minimum is 24×24 CSS px with exceptions; 44×44 is AAA enhanced or a product recommendation, not AA.

- [ ] **Step 5: Write `implementation-contracts.md` as portable patterns, not Carbon APIs**

Use these sections:

```markdown
# Implementation contracts
## Load this module when
## Choose the lowest effective enforcement layer
## Input normalization contract
## Measured overflow contract
## Overlay lifecycle contract
## Async state contract
## Formatting and semantic-state contract
## Portable pattern catalog
## Project-stack adaptation
## Verification before promotion
```

Include these exact conceptual contracts:

```text
input → validate → normalize → render | refuse
measure → reserve affordance → prefix-fit → stable update
open → initial focus → presence/close → launcher focus return
idle → pending → success | error, with label + icon + action state synchronized
```

Correct the IBM overgeneralizations:

- warning, normalization, and render refusal are separate choices;
- destructive confirmation starts on input or cancel, never the danger action;
- actual item/margin/action/overflow-trigger widths are measured instead of `slice(0, 3)`;
- invalid/missing/zero states get distinct representations;
- `Intl.NumberFormat(locale, { notation: 'compact' })` is preferred over hand-built K/M/B;
- severity uses shape/text and color, not color alone.

Give React, Vue, and CSS examples only as short adaptation maps; do not ship framework runtime code in the skill.

Start enforcement selection with this reuse order, unless the established project has a stricter order:

```text
existing design system → native HTML → accessible primitive → custom implementation
```

The portable pattern catalog must explicitly classify every #8 candidate instead of silently dropping it:

| Source observation | Portable treatment |
|---|---|
| Raw color/spacing/type/easing | Prefer the project's existing token-aware Stylelint/ESLint rule; add no Carbon dependency by default |
| Data column width | Include header and representative cells in measurement; reserve sort/action affordances; use project-derived min/max rather than universal 58/400 values |
| Truncation tooltip | Attach `title` or tooltip only after actual overflow measurement |
| Action groups | Validate count/kinds separately from order normalization and render refusal; vertical order may differ only when the project's reading/action order requires it |
| Destructive confirmation | Initial focus goes to confirmation input or cancel, never danger; pending state prevents duplicate submit |
| Tag/filter overflow | Measure item margins, trigger width, and persistent action width; use prefix fit rather than a fixed slice |
| Loading existing data | Preserve stable data while refreshing when stale content is still truthful; do not universally append skeleton rows |
| Compact numbers | Use locale-aware `Intl.NumberFormat`; avoid redundant equal numerator/denominator display |
| Missing/unknown/zero | Use distinct semantic states and copy |
| Severity | Convey with shape/text and color, not color alone |
| Numeric alignment | Align numeric headers and body cells together |
| Panel Escape behavior | Derive Escape from modality and dismissibility, not the component name `SidePanel` |
| Clipped actions | Preserve access by relocating or pinning controls when scroll clipping would remove them |
| Nested overlays | Define a project maximum and refuse/warn beyond it; do not universalize IBM's depth of three |
| Overflow ladder | Inline → overflow disclosure → searchable surface when measured volume/cost crosses a project threshold |
| Saving feedback | Keep label/icon/action state synchronized and suppress status before the first dirty input |
| Search vs filter | Search locates matching results; filters constrain attributes, including attributes not rendered as columns; batch apply is a product choice, not a universal default |

For each adopted pattern, state whether it belongs in prose, a shared component/API, a static scanner, a unit/a11y/browser test, or a CI gate. Carbon-specific values and APIs remain external examples.

- [ ] **Step 6: Write `review.md` with a strict read-only default**

Use these sections:

```markdown
# Review
## Load this module when
## Establish scope and authority
## Render matrix
## Craft tests
## Interaction and accessibility
## Findings format
## Review-only boundary
## Unverified output
```

Require the smallest material render matrix, expanding for risky changes:

- desktop/mobile;
- shortest/longest representative values;
- loading/empty/error;
- light/dark when both themes exist;
- focus/keyboard/reduced-motion for interactions;
- clipping, overlap, layout shift.

Define Squint, Swap, Signature, and Token tests. Report findings as `blocker`, `should-fix`, or `note`, cite a reproducible state, filter intentional adopted decisions, and never mutate code in `review-only` mode.

- [ ] **Step 7: Write `evolution.md` with lifecycle and authority boundaries**

Use these sections:

```markdown
# Evolution
## Load this module when
## Decision lifecycle
## Promotion evidence
## Enforcement ladder
## Automatic actions
## Approval-required actions
## Waivers and expiry
## Retirement and migration
```

Include this lifecycle verbatim:

```text
observed → candidate → adopted → component-enforced → ci-enforced → retired
```

State that three related incidents trigger a generalization review, not an automatic promotion. Require a common cause, a false-positive estimate, a lowest-effective-layer choice, and a rollback path. Temporary waivers require `reason`, `owner`, and `expires`. CI failure gate activation and public API changes require approval.

- [ ] **Step 8: Write `sources.md` with source boundaries and corrections**

Record:

- `interface-design` commit `2f9be3206855bcb2d1d0af262c8bae25cba6658d`, MIT, and links to its skill/review/deslop/system template;
- `ibm-products` commit `eeff1e98ac8332f60a90d015dea2ba7c38edd26d`, Apache-2.0, and links to ActionSet, `useOverflowItems`, RemoveModal, status definitions, Stylelint, achecker/Playwright, and CI;
- the three #8 corrections from the design spec;
- local `design-rules`, issue #5–#8, `17994e0`, and `a61a9ab` provenance;
- a rule that substantial copied text/code requires notice preservation, while this release paraphrases mechanisms.

- [ ] **Step 9: Run the module contract and a prose-size check**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/module-contract.sh
wc -l woobin-harness/skills/design-workflow/references/*.md
```

Expected: `ALL-OK`. Each operational module should remain below 220 lines; `sources.md` should remain below 160 lines. If one exceeds the limit, remove duplicate explanations rather than create another summary file.

- [ ] **Step 10: Commit Task 2**

```bash
git add woobin-harness/skills/design-workflow/references \
        woobin-harness/skills/design-workflow/tests/module-contract.sh
git commit -m "Define modular design operating contracts

Constraint: Load direction, evidence, implementation, review, and evolution only when routed
Confidence: medium
Scope-risk: medium
Tested: module ownership and provenance contract"
```
