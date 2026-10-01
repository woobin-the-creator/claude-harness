# Spec Reviewer Prompt Template

Use this template when dispatching the spec reviewer after interview saves a spec file.

**Purpose:** Catch, before implementation, what the implementing session would otherwise discover halfway
through and resolve with its own judgement — ambiguity, acceptance criteria nobody can check, claims about
the repo that are not true, and the gaps where "if I build exactly this, where do I get stuck?".

**Dispatch after:** the spec file is written and `Open questions` is empty.

**Dispatch for:** every spec that will be implemented, without exception. The A/B measurements in issue #41
showed the quality gain of the old planning path came from this pre-implementation gap-finding (13 defaults,
6 document conflicts, 19 spec revisions in one run), not from the task documents. This review is where that
gain now lives.

**Dispatch as:** `woobin-harness:spec-reviewer`. Do not pass a `model` argument: the agent definition owns
model and effort, and `Agent` calls have no `effort` argument. Always use the namespaced name — other
installed plugins may ship agents with similar names.

```
Subagent (woobin-harness:spec-reviewer):
  description: "Review design spec"
  prompt: |
    First run `git rev-parse --show-toplevel` and `git branch --show-current`. Expected: [TOPLEVEL], [BRANCH].
    If different, change nothing and report BLOCKED.

    You are a spec reviewer. Verify this design spec is ready for a fresh session to implement
    without the interview conversation.

    **Spec to review:** [SPEC_FILE_PATH]
    **Repo guidance:** root `CLAUDE.md` (and `AGENTS.md` if present)

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Ambiguity | Any Acceptance criterion a fresh session could read two ways. Any Decision whose "고른 것" does not pin down the behaviour |
    | Testability | Each Acceptance criterion names something checkable — a command, a file, a grep, an observable behaviour. Flag the ones that can only be judged by reading prose |
    | Repo-fact conflicts | File paths, line numbers, counts, hook names, "this test checks X" — open them. Report every claim that does not match the repo |
    | Gaps | "If implemented exactly as written, where does it get stuck?" References the spec does not list but the repo has (grep for the names it touches). Decisions it silently assumes |
    | Scope creep | Anything in Goals or Acceptance criteria that no Decision justifies. It reads as authorized in the implementing session |
    | E2E proof | The Acceptance criteria require the end-to-end behaviour to be proven automatically and reproduced from a fresh clone, and a `woobin-harness:code-reviewer` cycle recorded in the PR. Flag if either default item is missing |
    | Repo rules | Does the spec honour the root `CLAUDE.md` "같이 고쳐야 하는 것" list (doc sync, version bump, counts, invalidation condition for any new rule)? |

    ## Calibration

    Report everything you find, at every severity. Do not filter to "important" issues and do not
    decide on the caller's behalf what is worth their time — filtering is a separate pass that happens
    after you. A finding you suppressed cannot be recovered; a finding the caller dismisses costs them
    one line.

    Tag every finding with an estimated severity and your confidence so the caller can rank them in
    that separate pass. Coverage is your job at this stage, not ranking.

    ## Output Format

    ## Spec Review

    **Status:** Approved | Issues Found

    **Findings:**
    - [Section / criterion N]: <specific issue> — <why it matters for implementation>  [심각도: high|med|low · 확신: 확실|추정]

    **Recommendations (advisory, do not block approval):**
    - <suggestions for improvement>

    Keep the report under 60 lines; compress rather than drop findings.
```

**Reviewer returns:** Status, Findings, Recommendations.

**Caller then:** applies the findings to the spec file (the spec is the ledger — fix it there, not in chat),
records the review in the spec's frontmatter (`spec_review:` line with date and finding count), and hands off
to the implementing session per `SKILL.md` "구현 세션으로 넘기기".
