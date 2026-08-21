---
name: grill-me
description: A relentless but focused interview to sharpen a plan or design — asks only the questions whose answers would change what gets built, within a fixed question budget (default 5). Use when the user wants to stress-test a plan or design, mentions "grill me", or asks to 계획을 검증/그릴/따져봐 달라고 할 때.
---

Interview me about this plan until we reach a shared understanding. Then stop.

## What to ask

Ask a question **only if a different answer would produce different work** — a different data model, a different failure mode, a different module boundary, or a different user-visible behaviour.

Before asking anything, apply this test:

> If I asked this and got either answer, would I write different code?

- **No** → do not ask. Choose the sensible default and record it as an assumption for the closing block.
- **Yes** → ask it.

Never spend a question on something already determined:

- Anything a *fact* in the environment settles — naming conventions, file layout, existing schemas, library versions, test patterns. Look it up (filesystem, git history, docs, tools) rather than asking.
- Anything where one option is conventional and the other is merely possible. Take the convention.
- Anything cheaply reversible. Pick one; I will say so if I disagree.

The *decisions* are mine, but only the ones that are actually decisions.

## How many to ask

Default budget: **5 questions**. If I passed a number as an argument, use that as the budget instead.

Order by impact. The question that constrains the most downstream decisions goes first — resolve what other decisions depend on before the decisions that depend on it.

Number each one so I can see the budget burning down: `Q2/5`.

Stop when the budget is spent, or earlier if every remaining question fails the test above. **A short grilling is a good grilling** — do not pad the budget to fill it.

If you genuinely hit the budget with load-bearing questions still unanswered, say so and ask whether to extend it. Do not silently continue past the budget.

## How to ask

One question at a time. Wait for my answer before the next one — asking several at once is bewildering.

For each question:

1. State the question.
2. Give two or three concrete options, not an open-ended prompt.
3. In one line, say what each choice changes downstream. This is the question's justification for taking a slot in the budget — if you cannot write this line, the question fails the test and should not be asked.
4. Give exactly one recommendation, with the reason for it.

## How to finish

When the budget is spent, report every default you took in a single block, in the language we have been conversing in:

> **Assumptions I am proceeding on** — tell me if any are wrong:
> - `<assumption>` — `<why this default>`

Include only the ones I could plausibly disagree with. Do not pad the block with trivia to look thorough.

Then stop and wait. Do not start the work until I confirm we have reached a shared understanding.

## Handing off to writing-plans

This applies only when the grilled thing is work about to be built. If I was stress-testing a decision that is already made, or a doc, or an argument, stop at the block above and skip this section.

Once I confirm, **continue into writing-plans in this same session.** Do not tell me to `/clear` first. The only mandatory boundary in this workflow is after the plan is saved, when implementation starts.

Two conditions make that safe, and you must hold both:

1. **Delegate every codebase survey to the read-only explorer subagent** (Claude Code: `Explore`; Codex: `explorer`). The measured cost of planning-after-designing was not the interview sitting in context — it was 45 grep/sed calls run in the main loop (`home/HARNESS-LOG.md` #11, #15 in this harness repo). Read directly only in the three cases the active `CLAUDE.md`/`AGENTS.md` policy allows: three files or fewer, verifying an edit you just made, or copying a style you must reproduce verbatim.
2. **Carry the grill's output forward in writing, not in memory.** Whatever I settled, the assumptions block, and — most importantly — **each option I rejected with the reason** must reach the plan document's rejected-alternatives section. If it only lives in this conversation, the implementation session proposes it again.

Write a separate spec doc at `docs/woobin_plan/specs/YYYY-MM-DD-<topic>-design.md` only when the design is large enough to outlive this plan, or when I ask. For a three-or-four-decision feature the plan's own rejected-alternatives section is enough, and a spec doc is duplication.

If the survey turns out to need heavy direct reading anyway and context climbs past roughly 200k, stop, save the spec, and hand me a `/clear` — that is the fallback, not the default.

For output format and readability, follow the rules of the currently active output style.
