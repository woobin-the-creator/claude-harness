# Plan Document Reviewer Prompt Template

Use this template when dispatching a plan document reviewer subagent.

**Purpose:** Verify the plan is complete, matches the spec, and has proper task decomposition.

**Dispatch after:** The complete plan is written **and** the Self-Review checklist in `SKILL.md` has been run.

**Dispatch for:** every plan, without exception. This used to be a mode-③-only escalation on the
argument that the Self-Review checklist catches the same things more cheaply. That argument assumed a
human reads the kickoff block and sanity-checks the plan before pasting it. Under full-auto (modes
①/②b/③ with zero gates) nobody does, so this dispatch is the only pre-flight the run gets.

**Dispatch as:** a dedicated reviewer agent, picked by difficulty:

| Plan | Agent |
|------|-------|
| mode-③ trigger — migration, prod-facing change, or UI that automated gates cannot check | `plan-doc-reviewer-opus-xhigh` |
| anything else | `plan-doc-reviewer-opus-medium` |

Judge the trigger from the plan you just wrote — it is knowable now, before the review runs (the review
is what *produces* the gate count, so gate count cannot be the input here). Do not pass a `model`
argument: the agent definition owns model and effort, and `Agent` calls have no `effort` argument at all.

This used to dispatch a `general-purpose` subagent on the theory that it inherits the planning session's
deliberately-chosen effort. It does not: `subagent-model-default.sh` (R3) pins any model-unspecified
`general-purpose` subagent to sonnet, so the review ran on sonnet regardless of the planning session.
Frontmatter is the only carrier that survives that hook and full-auto's lack of a session relaunch.

```
Subagent (plan-doc-reviewer-opus-medium | plan-doc-reviewer-opus-xhigh):
  description: "Review plan document"
  prompt: |
    You are a plan document reviewer. Verify this plan is complete and ready for implementation.

    **Plan to review:** [PLAN_DIR_PATH]  — read `00-overview.md` first, then every `task-N.md`
    **Spec for reference:** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing steps |
    | Spec Alignment | Plan covers spec requirements, no major scope creep |
    | Task Decomposition | Tasks have clear boundaries, steps are actionable |
    | Buildability | Could an engineer follow this plan without getting stuck? |
    | Split integrity | Task numbers in the overview's table match the actual `task-N.md` files; no task body leaked into the overview |
    | Self-containment | No references to a planning conversation; every file path is absolute or repo-relative; every task names a real completion-check command |
    | Language | Plan documents are written in English. Verbatim strings — error messages, file contents, commands, user-facing copy — are quoted in their original language, not translated. |
    | Constraint blast radius | For each Global Constraint, which tracked files does it force to change? Are they all in some task's Files list? A constraint stated more broadly than the file list is how scope creep enters — it reads as authorization. |
    | Completion-check executability | Does each task's completion check actually execute what the task produced, or only parse it? A migration whose only gate reads the file, a renderer whose only gate greps a stylesheet, a script whose only gate is a lint — all pass while the artifact is broken. |
    | Gate inventory | Count the points where a human must confirm before work can continue: visual checks, destructive steps, anything phrased as "확인을 받아라" or "get confirmation". Report the count and where each one is. |

    ## Calibration

    Report everything you find, at every severity. Do not filter to "important" issues and do not
    decide on the caller's behalf what is worth their time — filtering is a separate pass that happens
    after you. A finding you suppressed cannot be recovered; a finding the caller dismisses costs them
    one line.

    Tag every finding with an estimated severity and your confidence so the caller can rank them in
    that separate pass. Coverage is your job at this stage, not ranking.

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

**Reviewer returns:** Status, Gates (count + locations), Findings, Recommendations
