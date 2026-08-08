# Scoring Rubric

100 points across 6 dimensions, plus 3 blocking gates that cap the overall grade. Score each dimension from **evidence you actually gathered**; attach a one-line note per dimension. Fractional points are fine.

Grade bands: **90+ Agent-Native · 75–89 Agent-Ready · 55–74 AI-Fragile · <55 AI-Hostile.**

---

## Blocking gates (apply AFTER summing raw points)

A gate failure means the repo cannot be trusted by an agent no matter how the other dimensions look. Cap the reported grade:

| Gate | Question | Fail → cap at |
|---|---|---|
| **B1 — Runnable verification** | From a fresh clone, can an agent get a fast, deterministic pass/fail? (tests run AND typecheck/lint run) | AI-Fragile (max 74) |
| **B2 — No misleading dead code** | Are deprecated/dead paths removed or clearly marked, so agents aren't lured into dead ends? | drop one full band |
| **B3 — Fresh-clone reproducibility** | Do the documented build/test steps work from a clean checkout (no undocumented local state)? | AI-Fragile (max 74) |

If B1 and B3 both fail, cap at AI-Hostile. Report raw AND capped.

---

## 1. Verification gates — 25 pts (also drives B1)
The single most important lever; every published rubric weights it highest.

- Tests exist and are runnable with one documented command (0–8)
- Test signal is fast and scoped (per-package commands, not only a 20-min repo-wide suite) (0–4)
- Static types present and strict where the language allows (`tsc --strict`, mypy strict, no pervasive `any`) (0–6)
- Linter + formatter configured and enforcing (ESLint/Prettier/ruff/gofmt…) (0–4)
- CI runs these on PRs, fail-fast (lint/type before slow tests) (0–3)

## 2. Agent context files — 20 pts
- `AGENTS.md` or `CLAUDE.md` exists at root (0–6)
- Monorepo: nested context files in subprojects (closest-wins) — full credit if applicable, N/A→redistribute (0–3)
- Kept short and pointer-heavy (~≤200–300 lines; flags the *direction*, not exhaustive command dumps) (0–4)
- Contains what code can't tell you: build/test commands, gotchas, domain context — not linter-enforceable style (0–4)
- Progressive disclosure for anything large (`agent_docs/`, `.claude/rules/*.md` referenced from root) (0–3)

## 3. Navigation & discoverability — 15 pts
- A repo "map": each top-level folder has a one-line purpose somewhere discoverable (0–4)
- Clear entry points identified (0–3)
- Files small enough to understand independently; no giant god-files (0–3)
- API/behavior visible near call sites rather than buried in deep abstraction (0–3)
- Build artifacts / generated code / vendored deps excluded via `.gitignore` / `.claudeignore` (0–2)

## 4. Documentation & tribal knowledge — 15 pts
- `docs/` with architecture/overview present (0–4)
- ADRs or equivalent capture *intent* (why, not just what) (0–4)
- Domain glossary for project-specific terms (0–3)
- Gotchas/traps captured — ideally as code examples/patterns over long rule lists (0–4)

## 5. Dependency mapping & module boundaries — 15 pts (dead code = B2)
- Module boundaries clear; a change is localizable without breaking unrelated code (0–5)
- Dependency/architecture map exists (diagram or doc) (0–3)
- **No misleading dead/deprecated code** left looking live (0–5) — a 0 here trips gate B2
- Circular/tangled dependencies minimized (0–2)

## 6. Freshness & dependency currency — 10 pts
- Stack/framework versions are current enough that models trained recently recognize the patterns (0–4)
- Docs updated in step with code (no stale AGENTS.md describing removed modules) (0–3)
- Deps not dangerously outdated (lockfile not years stale) (0–3)

---

## Worked example (from a real audit of a small Next.js app)
Raw 54/100 → **AI-Fragile**. Navigation 6/15 (no repo map), Context 17/20 (good CLAUDE.md), Tribal 9/20, Deps 8/15, Gates 10/15, Freshness 3/10. B1 marginal (tests thin) — kept at AI-Fragile. Top fix: add a folder map + wire a CI test gate, which unblocks the biggest two gaps at once. Use this as a calibration anchor, not a target.
