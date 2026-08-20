# Task 4: Routing Contracts and Real-Model Acceptance

**Files:**
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/routes/established-first-use.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/routes/greenfield.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/routes/incremental.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/routes/review-only.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/routes/guard-promotion.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/routes/design-managed.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/routes/design-unmanaged.md`
- Create: `woobin-harness/skills/design-workflow/tests/router-contract.sh`
- Create: `woobin-harness/skills/design-workflow/tests/all.sh`
- Create: `woobin-harness/skills/design-workflow/evals/cases/*.md`
- Create: `woobin-harness/skills/design-workflow/evals/run-routing.sh`
- Create: `woobin-harness/skills/design-workflow/evals/assert-routing.mjs`

**Interfaces:**
- Consumes: exact route names and announcement format from Task 3.
- Produces: deterministic documentation/fixture contracts and an optional authenticated model acceptance harness.
- Task 5 consumes: `tests/all.sh` as the skill-wide release gate.

- [ ] **Step 1: Create scenario fixtures as explicit input/output contracts**

Each route fixture is Markdown with exactly these headings:

```markdown
# Context
# User request
# Expected route
# Must do
# Must not do
```

Use these cases and expectations:

| Fixture | Expected route | Must not do |
|---|---|---|
| `established-first-use.md` | `system-evidence → implementation-contracts → review` | Block on DESIGN.md or reopen product direction |
| `greenfield.md` | `direction → system-evidence → implementation-contracts → review` | Adopt direction without user choice |
| `incremental.md` | `system-evidence → implementation-contracts → review` | Load direction or audit unrelated screens |
| `review-only.md` | `system-evidence → review` | Write files or silently fix findings |
| `guard-promotion.md` | `system-evidence → implementation-contracts → evolution → review` | Enable CI failure gate without approval |
| `design-managed.md` | `system-evidence → implementation-contracts → review`, preceded by validator | Treat DESIGN.md as raw token inventory |
| `design-unmanaged.md` | `system-evidence → implementation-contracts → review` | Overwrite, migrate, or fail the task |

Give each fixture a concrete user request from the design spec rather than generic placeholders. For example, review-only uses “이 PR의 UI 변경을 리뷰해줘. 수정은 하지 마.”

- [ ] **Step 2: Write the failing deterministic route contract**

Create `tests/router-contract.sh`:

```sh
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
```

- [ ] **Step 3: Run the contract and verify the missing-fixture failure**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/router-contract.sh
```

Expected: non-zero exit because route fixtures do not exist.

- [ ] **Step 4: Fill the fixtures and make the deterministic contract pass**

Write all seven fixtures with the exact route table above. Include these additional load-bearing assertions in prose:

- first use scopes repository reading to the current task;
- managed DESIGN runs the validator but absence remains valid;
- greenfield asks only decisions that change the direction;
- review findings use blocker/should-fix/note;
- guard promotion seeks common cause and lowest effective layer;
- external precedent cannot become adopted without local evidence.

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/router-contract.sh
```

Expected: `ALL-OK`.

- [ ] **Step 5: Add the aggregate deterministic suite**

Create `tests/all.sh`:

```sh
#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

for test_script in \
  validate-design-md.sh \
  module-contract.sh \
  skill-contract.sh \
  router-contract.sh
do
  sh "$SCRIPT_DIR/$test_script"
done

echo ALL-OK
```

Run it and expect each child `ALL-OK` plus the final aggregate `ALL-OK`.

- [ ] **Step 6: Create headless eval cases without real project data**

Under `evals/cases/`, create five prompts: `established-first-use.md`, `greenfield.md`, `incremental.md`, `review-only.md`, and `guard-promotion.md`. Each prompt instructs the model to respond only with:

```text
ROUTE=<ordered module names>
DESIGN_BEHAVIOR=<absent|validate|unmanaged>
MUTATION=<allowed|forbidden|approval-required>
FIRST_ACTION=<one sentence>
```

Use synthetic repository facts in the prompt. Do not ask the model to edit files. The review case must include “수정은 하지 마”; the guard case must ask to prevent a third recurrence but not mention CI.

- [ ] **Step 7: Implement the headless runner with isolated Claude contexts**

Create `evals/run-routing.sh` as POSIX shell. It accepts one case name or `all`, requires `claude` on PATH, creates a temporary output directory, and runs each prompt independently:

```sh
claude -p "$(cat "$case_file")" \
  --plugin-dir "$PLUGIN_DIR" \
  --output-format text \
  >"$output_file"
node "$ASSERT" "$case_name" "$output_file"
```

Set `PLUGIN_DIR` from the repository-local `woobin-harness`, not the installed cache. Print the case name before invocation and `EVAL_OK case=<name>` after assertion. Do not reuse conversation context between cases.

- [ ] **Step 8: Implement deterministic output assertions**

Create `evals/assert-routing.mjs` using `node:fs` only. Hard-code the five expected route strings and mutation states in an object:

```js
const expected = {
  'established-first-use': {
    route: 'system-evidence → implementation-contracts → review',
    design: 'absent',
    mutation: 'allowed',
  },
  greenfield: {
    route: 'direction → system-evidence → implementation-contracts → review',
    design: 'absent',
    mutation: 'approval-required',
  },
  incremental: {
    route: 'system-evidence → implementation-contracts → review',
    design: 'validate',
    mutation: 'allowed',
  },
  'review-only': {
    route: 'system-evidence → review',
    design: 'validate',
    mutation: 'forbidden',
  },
  'guard-promotion': {
    route: 'system-evidence → implementation-contracts → evolution → review',
    design: 'absent',
    mutation: 'approval-required',
  },
}
```

Parse exact `KEY=value` lines. Fail on a missing key, duplicate key, unexpected route, or wrong mutation/design state. Do not score prose quality in this deterministic assertion.

- [ ] **Step 9: Run one paid acceptance case and record the limitation**

Run only if Claude CLI authentication and model-token spending are available:

```bash
sh woobin-harness/skills/design-workflow/evals/run-routing.sh review-only
```

Expected: `EVAL_OK case=review-only`. If authentication is unavailable, do not weaken the deterministic tests; record `headless eval: not run (authentication unavailable)` in the implementation handoff.

- [ ] **Step 10: Commit Task 4**

```bash
git add woobin-harness/skills/design-workflow/tests \
        woobin-harness/skills/design-workflow/evals
git commit -m "Cover design workflow routes with scenario contracts

Constraint: Review-only and optional DESIGN.md behavior must remain observable
Confidence: medium
Scope-risk: narrow
Tested: deterministic route suite; isolated headless case when authenticated"
```
