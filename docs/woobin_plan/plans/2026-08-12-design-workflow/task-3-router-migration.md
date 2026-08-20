# Task 3: Router and `design-rules` Compatibility Migration

**Files:**
- Create: `woobin-harness/skills/design-workflow/SKILL.md`
- Modify: `woobin-harness/skills/design-rules/SKILL.md`
- Modify: `woobin-harness/skills/design-rules/references/instance-guide.md`
- Create: `woobin-harness/skills/design-workflow/tests/skill-contract.sh`

**Interfaces:**
- Consumes: all Task 1–2 paths and lifecycle names.
- Produces: one implicit/explicit Router entry and one backward-compatible `design-rules` direct entry.
- Later tasks consume: the route announcement format `작업 유형: <mode> · 사용 모듈: <ordered modules>` and the exact route matrix below.

- [ ] **Step 1: Write the failing Router and compatibility contract test**

Create `tests/skill-contract.sh`:

```sh
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
```

- [ ] **Step 2: Run the test and verify the missing-Router failure**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/skill-contract.sh
```

Expected: non-zero exit because `design-workflow/SKILL.md` does not exist.

- [ ] **Step 3: Create the thin Router frontmatter and startup contract**

Create `design-workflow/SKILL.md` with the standard four-line frontmatter. Use this description, quoted so YAML cannot reinterpret the colon:

```yaml
---
name: design-workflow
description: "Route product UI work through conditional direction, project evidence, implementation contracts, render review, and rule evolution. Use explicitly for first adoption, redesign, design review, or recurring UI failures; also use implicitly for UI work when a managed DESIGN.md enables design_workflow."
---
```

The first body section must say:

```markdown
`DESIGN.md`가 없어도 작업을 멈추지 않는다. 파일은 디자인 기억을 영속화하는 선택적 장치다.
```

At startup:

1. Inspect only enough project context to classify the task.
2. If `DESIGN.md` is absent, continue and use code/tokens/adjacent UI as temporary authority.
3. If it exists without the managed marker, treat it as `DESIGN_UNMANAGED`; do not overwrite it.
4. If managed, run the Task 1 validator before trusting its lifecycle data.
5. Announce the route once in commentary using the exact route format.
6. Read only the references listed for that route.

- [ ] **Step 4: Encode the route matrix without copying module content**

Add this table to `SKILL.md`:

| Situation | Ordered modules | Required behavior |
|---|---|---|
| Existing project, first explicit use | system-evidence → implementation-contracts → review | Scope inspection to current work; propose DESIGN.md only after durable value appears |
| Greenfield | direction → system-evidence → implementation-contracts → review | Obtain approval for direction before adoption |
| Established incremental UI | system-evidence → implementation-contracts → review | Skip direction |
| Large redesign | direction → system-evidence → implementation-contracts → review → evolution | Keep new direction candidate until approved |
| Review-only | system-evidence → review | Do not edit files |
| Recurring failure/enforce | system-evidence → implementation-contracts → evolution → review | Choose lowest effective guard; respect approval boundary |
| Render-invariant logic | none | State that this skill does not apply and continue normal engineering work |

The Router must not always run all five modules. A user may explicitly request a module override, but the Router records why it changes the default route.

- [ ] **Step 5: Add the optional persistence and permission behavior**

In `SKILL.md`, define creation prompting precisely:

- suggest `templates/DESIGN.md` only after an adopted direction, project-specific override, repeat incident, accepted external precedent, or enforcement path exists;
- ask once at the end of the work, not before implementation;
- if declined, continue and do not repeat during the same task;
- a managed document enables implicit invocation on later UI work; absence means explicit invocation remains the default.

List these automatic actions explicitly:

- report existing code and tokens as `observed`;
- attach evidence from tests actually run;
- implement an in-scope component/test guard the user requested;
- mark a decision `component-enforced` only after its implementation and verification path exist.

List these approval-required actions explicitly:

- promote `candidate` to the project's adopted default;
- add a dependency or break a public component API;
- migrate broad existing UI;
- enable a CI failure gate;
- remove legacy behavior, exceptions, or waivers.

State that “다시 발생하지 않게 막아줘” authorizes the in-scope component and test guard, but none of the approval-required expansions.

- [ ] **Step 6: Turn `design-rules` into a compatibility entry**

Replace its broad body with a maximum-80-line direct-entry contract. Preserve its name and concrete trigger, but narrow the description to established-system UI implementation and style decisions. Remove workflow-level triggers such as greenfield direction and choosing among design candidates.

The compatibility body must:

```markdown
# Compatibility entry

This direct entry preserves existing `$design-rules` calls. For process routing, first adoption,
greenfield direction, redesign, review-only, or guard promotion, use `design-workflow`.

For the requested concrete UI decision, read in order:

1. `../design-workflow/references/system-evidence.md`
2. `../design-workflow/references/implementation-contracts.md`
3. `../design-workflow/references/review.md` when a render or review is in scope
4. `../design-workflow/references/evolution.md` only for a repeated failure

`DESIGN.md` remains optional. Never stop because it is absent.
```

Retain this compact old-to-new owner map so old issue links remain understandable; do not retain duplicate normative prose:

| Old section | New owner |
|---|---|
| §1 tone | `system-evidence.md` |
| §2 dimensions | `system-evidence.md` |
| §3 information design | `system-evidence.md` + `implementation-contracts.md` |
| §4 taste defaults | `system-evidence.md` |
| §5 accessibility | `system-evidence.md` + `review.md` |
| §6 generation/refinement | `direction.md` + `review.md` |
| §7 rule evolution | `evolution.md` |

- [ ] **Step 7: Update the old instance guide to delegate to the new document contract**

Keep the file so old links do not break. Replace its template ownership with:

- a link to `../../design-workflow/templates/DESIGN.md`;
- a link to `../../design-workflow/references/design-document.md`;
- a migration note that old free-form files remain unmanaged and valid;
- no automatic rewrite instruction.

Do not maintain a second seven-section template.

- [ ] **Step 8: Run the Router/compatibility contracts and plugin frontmatter parser early**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/skill-contract.sh
claude plugin validate ./woobin-harness
```

Expected: `ALL-OK` and plugin validation exit `0`. The plugin description/count may still be stale until Task 5, but YAML/frontmatter must parse.

- [ ] **Step 9: Confirm removed normative prose has one new owner**

Run:

```bash
rg -n "실제 최대|실제로 잘렸을 때만|observed → candidate|validate → normalize" \
  woobin-harness/skills/design-rules \
  woobin-harness/skills/design-workflow
```

Expected: normative matches live in `design-workflow/references/*`; `design-rules` contains only compatibility pointers or the old-to-new owner map.

- [ ] **Step 10: Commit Task 3**

```bash
git add woobin-harness/skills/design-workflow/SKILL.md \
        woobin-harness/skills/design-workflow/tests/skill-contract.sh \
        woobin-harness/skills/design-rules/SKILL.md \
        woobin-harness/skills/design-rules/references/instance-guide.md
git commit -m "Route design work through conditional modules

Constraint: Existing design-rules calls must keep working without a competing full rule copy
Confidence: medium
Scope-risk: medium
Tested: Router, compatibility, and frontmatter contracts"
```
