---
name: writing-plans
description: Turn a confirmed spec, PRD, design doc, or agreed requirements into an ordered, self-contained implementation plan that a fresh session can execute without the planning conversation. Use whenever work needs more than one or two steps and the approach is already settled — "이거 계획 세워줘", "플랜 짜줘", "구현 계획", "이 스펙대로 진행하자", "write a plan for this", or right after interview settles a spec. Use it before touching code, not after. Do not use when the approach itself is still unsettled or the requirements are not yet agreed — that is interview.
---

# Writing Plans

## Overview

Write implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need: which files to touch for each task, the code, the tests, the docs they might need to check, how to verify it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

The reason to be this thorough is structural, not stylistic: **the session that implements this plan will not have the planning conversation.** Everything you know right now and don't write down is lost at the session boundary, and the implementer will either guess or come back and ask — which costs more than writing it down did.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, create it from a fresh base at execution time (Claude Code: `EnterWorktree` with `baseRef=fresh`; either host: `git worktree add`).

## Where the Plan Goes

Save to a **directory**, one file per task:

```
docs/woobin_plan/plans/YYYY-MM-DD-<slug>/
├── 00-overview.md      ← the only file the orchestrator reads
├── task-1.md
├── task-2.md
└── …
```

(User preferences for plan location override the root, not the layout.)

Write it split from the start rather than writing one big file and splitting it after. A monolithic plan gets read whole by the orchestrator, and that read is re-billed as a cache read on **every** request for the rest of the implementation session — measured at 48k tokens for a 1,650-line plan, pushing the session floor to 93–122k (`home/HARNESS-LOG.md`). Splitting afterwards works, but you pay to write the document twice.

**Keep `00-overview.md` under 400 lines / 15,000 characters.** It is the one file that every request in the implementation session carries.

### Language

**Write plan documents in English** — both `00-overview.md` and every `task-N.md`.
Their reader is a fresh implementation session, not a person: the overview is
re-billed as a cache read on every request for the rest of that session, and
Korean costs roughly two to three times as many tokens per character.

This applies to the plan documents only. Keep the decision ledger, the
conversation, skill bodies, and hook comments in the language the user is
working in — those have a human reader, and `interview` depends on the user
being able to point at a ledger line and say it is wrong.

Quote verbatim strings exactly as they appear in the source, whatever language
they are in: error messages, file contents, commit messages, user-facing copy,
and the exact commands to run. Do not translate them into English — the
implementer has to match them character for character.

### Append-only

Treat saved plans as append-only: never update, delete, move, or overwrite an existing plan file. If the target directory already exists, pick a distinct slug or ask the user first.

This matters because plan directories are named by date and topic, so two attempts at the same feature on the same day collide — and the loser vanishes silently, taking its rejected-alternatives section with it. That section is the expensive part; regenerating it means re-running the research that produced it.

### What goes where

The split is load-bearing, so the division has to be exact:

**`00-overview.md`** — background, Global Constraints, the task list (number + title + target files + completion-check command only), inter-task ordering dependencies, and **the alternatives you considered and rejected, with reasons.** Without that last part a fresh session re-proposes what you already ruled out.

**`task-N.md`** — the full body of one task: exact file paths, the code, the tests, the completion check. This is the only file its implementer reads, so it must stand alone. Task numbers must match the overview's list exactly.

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs while the spec was being settled. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure — but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate. When drawing task boundaries: fold setup, configuration, scaffolding, and documentation steps into the task whose deliverable needs them; split only where a reviewer could meaningfully reject one task while approving its neighbor. Each task ends with an independently testable deliverable.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Overview Document Format

`00-overview.md` uses this header. The format matters because the implementation session reads only this file — anything not written here is lost at the session boundary.

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Task bodies live in the sibling `task-N.md` files; read each one immediately before implementing it, not all up front.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

## Tasks

| # | Title | Files | Completion check |
|---|---|---|---|
| 1 | … | `path/a.py`, `tests/test_a.py` | `pytest tests/test_a.py -q` |

## Ordering

[Which tasks depend on which, and which share files. One line each. This is
the only basis for choosing an execution mode — see Execution Handoff — and
no later session can reconstruct it as cheaply as you can right now.]

## Rejected Alternatives

- **[Alternative]** — rejected because […]
```

## Task File Format

Each `task-N.md`:

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Self-Review

After writing the complete plan, look at it with fresh eyes. This is a checklist you run yourself — not a subagent dispatch.

The first three checks ask *does the plan match the spec*. The last three ask *does the plan survive the session boundary* — they matter because you are the last session that can answer them; once this conversation ends, the missing information is gone.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

**4. Path concreteness:** Is every file reference an absolute or repo-relative path? A bare function or component name sends the implementer searching.

**5. No conversation references:** Zero occurrences of "위에서 논의한 대로", "as we discussed", "앞서 정한", or anything else that points at this chat.

**6. Completion checks present:** Does every task name the actual command that proves it's done? "Tests pass" is not a check; `pytest tests/test_a.py -q` is.

Fix what you find inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

Then dispatch an independent plan-document reviewer using [plan-document-reviewer-prompt.md](plan-document-reviewer-prompt.md). That file names which reviewer agent to use — `plan-doc-reviewer-opus-xhigh` for a mode-③ trigger (migration, prod-facing, uncheckable UI), `plan-doc-reviewer-opus-medium` otherwise — and why the model is pinned in the agent definition rather than inherited. Do this for **every** plan, not only high-stakes ones: the checklist above is you checking your own work, and the plan may be executed with no human reading it first. Apply the findings to the plan files before going any further — a finding you leave unfixed is a finding nobody will see again.

Keep the reviewer's `**Gates:** N` line. The Execution Handoff below routes on that number.

## Execution Handoff

Read [plan-exec-modes.md](../../plan-exec-modes.md) and follow it — it owns the mode contract, the gate-routing table, and the full-auto procedure.

### Pick the mode

Recommend exactly one and state the evidence, because the only basis for the choice is the ordering section you just wrote into `00-overview.md`, and no later session can reconstruct it as cheaply:

- ① Speed — only when two or more tracks share no files.
- ② Thrift — dependency chain or shared files. Most plans land here.
- ③ Max quality — migrations, prod-facing changes, UI that automated gates cannot check.

### Then route on the gate count

The reviewer's `**Gates:** N` decides whether the run is attended, and it can override the mode you just picked:

- **N = 0** → run it here, full-auto. Do not emit a kickoff block.
- **N ≥ 1** → ②a. Emit the kickoff block and end the turn; the user drives the layer boundaries.
- **N ≥ 1 and the plan meets ③'s trigger** → keep ③ and run it here. It will stop at the gate and report; you relay that to the user and resume. A migration plan does not get demoted to `sonnet`/`medium` over one visual check.

State the routing outcome and the gate count in one line so the user can override it.

### Full-auto (N = 0)

Do not start implementing inline. Follow the modes file's full-auto procedure: open the `plan/<slug>` branch and draft PR first, then spawn one implementer per layer, serially, using the agent name the modes file gives for the chosen mode. Pass the overview path and that layer's `task-N.md` paths in execution order — never the task bodies, and never a `model` argument, because the agent definition owns model and effort. Mode ① reads "layer" as "track" here — it delegates by track, not layer, and opens one draft PR per track instead of one for the whole plan; see the modes file's ① section.

Between layers: the implementer commits, you run `plan-reviewer`, you apply its findings, you push. If a layer changed anything that renders, dispatch `screenshot-verifier` before pushing — nobody is looking at the screen, which is the whole point of full-auto and also its blind spot.

Never fan out a subagent per task, and never tell an implementer to verify its own work — both are measured losses, cited in the modes file.

### The kickoff block (N ≥ 1 only)

End the response with a copyable kickoff prompt, because the handoff only pays off if the user can start the next session without composing anything. Anything they have to fill in themselves is a place the handoff breaks.

Make a fenced ` ```text ` block the **final content of the response** — nothing after it. Match the user's language — the kickoff block is read by a person, unlike the plan documents themselves. Follow the kickoff format in `plan-exec-modes.md`, and substitute the real model, effort, mode number, and absolute plan path. Leave no angle-bracket placeholders.

Measured basis: this harness repo's `home/HARNESS-LOG.md` §16 (single-owner effort/model, no per-task fanout, no self-verification), and the sources at the bottom of `plan-exec-modes.md`.
