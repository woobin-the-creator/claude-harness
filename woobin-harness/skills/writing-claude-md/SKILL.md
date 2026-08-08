---
name: writing-claude-md
description: Use when creating or revising a CLAUDE.md, AGENTS.md, or other agent-instruction file for a repo or subdirectory, when an existing one has grown long, stale, or duplicates other docs, or when asked to document repo conventions so future agent sessions work correctly.
---

# Writing a CLAUDE.md

## Overview

A CLAUDE.md is **not** a repo tour. It is the set of things an agent would get **wrong** after reading the code — and nothing else. Modern models read the filesystem competently; they cannot guess which of two reasonable choices your team already rejected.

**Core principle: every line must survive the Delete Test.**

> **Delete Test** — could an agent get this from `ls`, `grep`, reading a config file, or opening a doc you already link? If yes, delete it. The agent will read those anyway, and faster than you can summarize them.

## The Output Contract

Write these four parts, in this order. Nothing else. Part 3 may carry subheadings that group its gotchas; parts 1, 2, and 4 stay flat.

**1. Orientation — 1–2 sentences.** What this directory is, and a pointer to the design doc. Not a stack list (`package.json` has it), not a directory tree (`ls` has it).

**2. Load-on-demand pointers.** For each body of guidance that only applies to *some* tasks, one line: a **trigger condition** plus the file to read.

> `Deciding what a screen looks like? Read design-rules.md first.`

Split anything situational into its own file. A CLAUDE.md loads on **every** turn in its scope; content that matters to one task in five belongs behind a pointer.

**3. Gotchas — the bulk of the document.** This is what you are actually writing. Each entry is a fact plus *why*, because the why is what stops an agent from "fixing" it:

- **Rejected alternatives.** "Zustand は検討済み・却下" — otherwise an agent helpfully migrates you.
- **Pins and caps with reasons.** "`ruff<0.12` — 0.12 widens the default ruleset and broke the CI gate."
- **Load-bearing code that looks removable.** "Don't delete this fixture; it looks redundant but the engine singleton outlives the loop."
- **Doc/code drift.** "The palette table in `docs/x.md` §13 predates the code. Real tokens are `--ink`/`--canvas`."
- **Invariants that fail silently.** Wrong output, no error.
- **Non-obvious sequences.** The order of a multi-file change, when a wrong order fails late.

**4. Verification — only the non-obvious part.** Skip the command list; `package.json` and CI config already have it. Keep the discipline a command can't express: "Confirm a regression test actually fails when you revert the fix."

## Budget Check

Measure in **characters**, not lines — characters are what every future turn pays for, and long lines hide a bloated file behind a short line count.

- **Total: under 6,000 characters (`wc -m`, not bytes).** Past 10,000 you wrote a repo tour, not a warning list.
- **Gotchas: the majority of those characters.** If orientation, pointers, and verification outweigh part 3, cut them, not the gotchas.

Run `wc -m` on the file before you call it done. If it fails either check, delete — do not compress prose to fit.

## Quick Reference

| Symptom | Fix |
|---|---|
| Architecture / layer explanation | Delete. `ls` shows it. Keep only invariants that break silently. |
| Endpoint or file map | Delete. `grep` beats a map that goes stale. |
| Command block from package.json / CI | One line, or delete. |
| Restates a doc you also link | Point at it. Never both. |
| "This project uses X" | Delete unless the point is that Y was rejected. |
| Section only some tasks need | Move to its own file + trigger pointer. |

## Common Mistakes

- **Writing it from repo exploration alone.** Gotchas live in git log, PR bodies, issue threads, and code comments explaining *why*. Mine those; a fresh read of the tree yields structure, not scars.
- **Stating a rule prose can't enforce.** If a lint rule, test, or type can enforce it, do that instead and let the doc point at the check. A test that fails is worth more than a paragraph.
- **Writing both the pointer and the content.** Pick one.
