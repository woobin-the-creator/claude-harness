---
name: debug
description: The debugging door of this harness. Build a reproduction loop that turns the target red before touching the fix, run that loop to produce a runtime diagnosis record, and patch from that record. Use when `kick-off` routes to the debugging path, or when the user invokes debug by name.
---

# debug

The loop comes before the patch. Hold to the three clauses below — the rest is your judgment.

## ① Build the loop first

Produce **one command that turns the target red**. A test, a curl, a CLI call, a headless browser
script, a replayed trace capture, a minimal harness — anything works. Four conditions:

- **Can go red** — it asserts the exact symptom the user reported. "It runs clean" is not red
- **Deterministic** — the same verdict every run. For nondeterministic defects the goal is not a
  clean reproduction but **raising the reproduction rate** (100× repeat, parallelism, timing
  pressure). 50% is debuggable; 1% is not
- **Fast** — seconds, not minutes
- **Agent-runnable** — if it needs a human click, wrap that procedure in a script

If you cannot build the loop, **stop there and say so.** List what you tried, and ask for what you
need: access to a reproduction environment, captured artifacts (HAR, log dumps, screen recordings),
or permission to add temporary instrumentation. Do not advance to hypotheses without a loop.

## ② Reproduce on several faces, then run it into a record

**Aiming to make one single reproduction pass produces a partial patch.** When the issue states
several behavioral requirements, build a reproduction for each.

Then **run the reproduction and write down what you observed** as a diagnosis record — at which
boundary a value turned into what, how far down the layers it reached. Treat the reproduction as a
**source of runtime fact**, not as a goal to pass. Write the patch from that record.

If you added instrumentation, give it a unique prefix such as `[DEBUG-<4 chars>]`. Strip it with one
grep at the end.

## ③ Close a failure with an instruction for the next attempt, not a call for a human

Form **3–5 ranked hypotheses** from the start. A single hypothesis anchors you to the first
plausible thought. Each must be falsifiable — "if X is the cause, changing Y makes the symptom go away".

When a fix attempt fails:

1. Record what stayed red and which hypothesis died
2. Close with **an instruction the next attempt can execute and verify**. "We should question the
   architecture" is not an instruction. "Change A to B and see whether `<command>` goes green" is
3. If no such narrowed instruction emerges — that is when to call a human. Call them with what you
   could not narrow

## Before you finish

- The original reproduction is no longer red (re-run the loop to confirm)
- You left a regression test, or **recorded the absence of a place to put one as a finding**.
  A test wedged into a seam that cannot reproduce the real defect pattern leaves only false confidence
- You removed the `[DEBUG-...]` instrumentation and any temporary reproduction files
- You left the winning hypothesis as one line in the commit or PR body

If it was an operational incident, hand off to `runbook-logger`.
