### Task 3: Plan-document reviewer — unconditional, three new lenses, report-everything

The reviewer prompt exists but is wired as a mode-③-only escalation. It becomes the pre-flight check for every plan, because under full-auto no human reads the plan before it executes. Three lenses are added, and its calibration is inverted to match `plan-reviewer.md`.

**Files:**
- Modify: `woobin-harness/skills/writing-plans/plan-document-reviewer-prompt.md` (whole file)

**Interfaces:**
- Consumes: the three routing outcomes written by Task 2.
- Produces: the `**Gates:** N` output line. Task 4's `SKILL.md` reads that number and routes on it, so the field name and format are load-bearing — do not reword them.

**Why the three lenses, concretely** — each one is a real pholex failure the current seven categories do not cover:

- *Constraint blast radius*: PR #230's plan carried a Global Constraint `IP/host/port/내부 URL을 외부로 보내지 않는다` with no file scope. The implementer converted `docker-compose.dev.yml`'s dev ports to required env keys and wrote a 119-line `test_port_configuration_policy.py`, none of which appear in the plan's Files lists. PR #233 deleted 117 lines four days later.
- *Completion-check executability*: PR #231's `task-1.md` shipped Alembic revision 023 whose only gates were `test_alembic_invariants.py` (parses files) and a seed contract test. Nothing ran the migration. It had never succeeded in any environment; PR #234 fixed it and added a CI postgres running `alembic upgrade head`.
- *Gate inventory*: the routing rule from Task 2 needs a number, and nothing produces one today.

This file is a prompt template read by a person and dispatched by a model; the surrounding prose stays Korean but the templated prompt itself stays English, as it is today.

---

- [ ] **Step 1: Replace the dispatch-condition header**

The current file has three lines under the title:

```
**Purpose:** Verify the plan is complete, matches the spec, and has proper task decomposition.

**Dispatch after:** The complete plan is written **and** the Self-Review checklist in `SKILL.md` has been run.

**Dispatch only for:** irreversible work — migrations, prod-facing changes, anything headed for execution
mode ③. For ordinary plans the checklist catches the same things at a fraction of the cost, so this
dispatch is pure overhead.
```

Replace the third with:

```
**Dispatch for:** every plan, without exception. This used to be a mode-③-only escalation on the
argument that the Self-Review checklist catches the same things more cheaply. That argument assumed a
human reads the kickoff block and sanity-checks the plan before pasting it. Under full-auto (modes
①/②b/③ with zero gates) nobody does, so this dispatch is the only pre-flight the run gets.

**Dispatch as:** a `general-purpose` subagent. Do not give it a dedicated agent definition — it runs
inside the planning session, whose effort the user chose deliberately, and inheriting that effort is
correct here rather than a hazard.
```

- [ ] **Step 2: Add three rows to the What to Check table**

Append to the existing table inside the prompt block, after the `Language` row:

```
    | Constraint blast radius | For each Global Constraint, which tracked files does it force to change? Are they all in some task's Files list? A constraint stated more broadly than the file list is how scope creep enters — it reads as authorization. |
    | Completion-check executability | Does each task's completion check actually execute what the task produced, or only parse it? A migration whose only gate reads the file, a renderer whose only gate greps a stylesheet, a script whose only gate is a lint — all pass while the artifact is broken. |
    | Gate inventory | Count the points where a human must confirm before work can continue: visual checks, destructive steps, anything phrased as "확인을 받아라" or "get confirmation". Report the count and where each one is. |
```

- [ ] **Step 3: Replace the Calibration section**

Delete this block entirely:

```
    ## Calibration

    **Only flag issues that would cause real problems during implementation.**
    An implementer building the wrong thing or getting stuck is an issue.
    Minor wording, stylistic preferences, and "nice to have" suggestions are not.

    Approve unless there are serious gaps — missing requirements from the spec,
    contradictory steps, placeholder content, or tasks so vague they can't be acted on.
```

and put this in its place:

```
    ## Calibration

    Report everything you find, at every severity. Do not filter to "important" issues and do not
    decide on the caller's behalf what is worth their time — filtering is a separate pass that happens
    after you. A finding you suppressed cannot be recovered; a finding the caller dismisses costs them
    one line.

    Tag every finding with an estimated severity and your confidence so the caller can rank them in
    that separate pass. Coverage is your job at this stage, not ranking.
```

This is not a style preference. `woobin-harness/agents/plan-reviewer.md` already carries the report-everything contract on documented grounds — telling the model to report only serious things makes it literally comply and report less — and the two files currently state opposite rules. Under full-auto the suppressed pass never reaches a human at all.

- [ ] **Step 4: Replace the Output Format section**

```
    ## Output Format

    ## Plan Review

    **Status:** Approved | Issues Found

    **Gates:** N

    Gates is the count from the gate-inventory row, as a bare integer on its own line. The caller routes
    the execution mode on this number and cannot recover it from prose. If the count is not zero, list
    each gate as `- [Task X, Step Y]: <what must be confirmed>` immediately below.

    **Findings:**
    - [Task X, Step Y]: <specific issue> — <why it matters for implementation>  [심각도: high|med|low · 확신: 확실|추정]

    **Recommendations (advisory, do not block approval):**
    - <suggestions for improvement>
```

Also change the closing line of the file from `**Reviewer returns:** Status, Issues (if any), Recommendations` to `**Reviewer returns:** Status, Gates (count + locations), Findings, Recommendations`.

- [ ] **Step 5: Run the check**

```bash
./scripts/test-skills.sh
```

Expected: PASS. This fixture parses every Markdown file bundled under `woobin-harness/skills/` and verifies that relative links resolve; it catches a broken reference introduced while editing.

- [ ] **Step 6: Commit**

```bash
git add woobin-harness/skills/writing-plans/plan-document-reviewer-prompt.md
git commit -m "feat(writing-plans): 플랜 문서 리뷰를 무조건화하고 렌즈 3개·게이트 카운트 추가"
```
