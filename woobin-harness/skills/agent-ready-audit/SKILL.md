---
name: agent-ready-audit
description: Diagnose whether a codebase is ready for AI coding agents (Claude Code, Cursor, Codex) and produce a scored, prioritized report. Reads the actual repo — agent context files (AGENTS.md/CLAUDE.md), verification gates (tests/types/lint), navigation/discoverability, docs & tribal knowledge, dependency boundaries, freshness — applies blocking gates (a fatal gap caps the grade, not a weighted average), and optionally analyzes token/prompt-caching efficiency from session logs. Use when the user asks "is this codebase agent-ready / AI-friendly", "audit my repo for AI agents", wants an agent-readiness score, asks how to make a repo friendlier to coding agents, or Korean equivalents — "에이전트 친화적인 코드베이스인지 진단", "AI 에이전트 준비도 점검", "코드베이스 agent-ready 진단", "우리 레포 AI 친화도 점수".
---

# Agent-Ready Audit

Diagnose how ready a codebase is for AI coding agents, then hand back a graded report and a prioritized fix list. The premise (well-supported across Anthropic's guidance, agents.md, and published rubrics like Factory.ai/Kenogami): **agents amplify whatever structure already exists — in a brownfield repo the surrounding infrastructure, not the model, caps output quality.**

This is an **agent-driven** audit. You read the real repo and judge each dimension from evidence, not from a checkbox script. Two rules keep it honest:

1. **Evidence over assumption.** Every score cites a concrete observation (a file that exists or doesn't, a command that runs or fails, a grep count). Never score a dimension you didn't inspect.
2. **Blocking gates beat averages.** A repo with great docs but zero runnable tests is *not* agent-ready. The three blocking gates below cap the overall grade regardless of how the other dimensions score — this is the key correction over naive weighted-average scoring.

Report to the user in **their language** (Korean if the conversation is Korean).

---

## Workflow

### Step 0 — Scope
Confirm the target: current repo root, or a path/subdir the user names. Detect the primary language/stack (look for `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, etc.). Note if it's a monorepo (multiple package manifests) — nesting matters for context files.

### Step 1 — Gather evidence (read the repo)
Work breadth-first and cheaply. Prefer glob/grep counts and targeted reads over reading whole files. Collect:

- **Context files:** `AGENTS.md`, `CLAUDE.md` (root + nested), `.cursorrules`, `.github/copilot-instructions.md`, `agent_docs/`, `.claude/`. Note their line counts.
- **Verification:** test files/dirs and how tests run; typecheck config (`tsconfig` `strict`, mypy, etc.); linter/formatter config; CI workflows (`.github/workflows`, etc.).
- **Navigation:** top-level layout, a repo "map" doc, README quality, presence of a root index of folders.
- **Docs & tribal knowledge:** `docs/`, ADRs (`docs/adr/`, `docs/decisions/`), domain glossary, per-directory docs, CONTRIBUTING.
- **Dependencies & boundaries:** module structure, obvious dead code / deprecated dirs, `.gitignore`/`.claudeignore` coverage of build artifacts.
- **Freshness:** dependency currency (lockfile ages, framework major versions), last-touched dates on docs vs code.

For large or unfamiliar repos, delegate the sweep to a read-only **Explore** subagent (or several in parallel by area) and have it return counts + file paths, so the main context stays clean.

### Step 2 — Score against the rubric
Read `references/scoring-rubric.md` for the full per-dimension criteria and point scale. In short:

| Dimension | Points | Blocking? |
|---|---|---|
| Verification gates (tests · types · lint · CI) | 25 | **YES** — see gate B1 |
| Agent context files (AGENTS.md / CLAUDE.md) | 20 | — |
| Navigation & discoverability | 15 | — |
| Documentation & tribal knowledge | 15 | — |
| Dependency mapping & module boundaries | 15 | **partial** — dead code is gate B2 |
| Freshness & dependency currency | 10 | — |

**Three blocking gates.** If any fails, the overall grade is capped (rubric gives the exact caps):
- **B1 — Runnable verification:** an agent can get a fast, deterministic pass/fail from a fresh clone (tests + typecheck/lint actually run). No gate → capped at "AI-Fragile".
- **B2 — No misleading dead code:** deprecated/dead paths aren't left looking live (they mislead agents into dead-end sessions — the single highest-cost trap).
- **B3 — Fresh-clone reproducibility:** documented build/test steps work from a clean checkout.

Score each dimension with a one-line evidence note. Then compute the raw total **and** apply the blocking caps. Report both ("raw 72/100, but capped at AI-Fragile because no runnable test signal").

Grade bands: **90+ Agent-Native · 75–89 Agent-Ready · 55–74 AI-Fragile · <55 AI-Hostile.**

### Step 3 — Token & prompt-caching efficiency (included)
This audit covers running cost, not just structure. Do the **static** checks always; do the **session-log** analysis only if logs are available.

- **Static caching hygiene** (from the repo — always): Is the stable prefix kept byte-stable? Flag anything that would silently bust prompt caching — dynamic values (timestamps, `git rev-parse`, current date) injected at the *head* of `CLAUDE.md`/system context; oversized context files that push past the cache prefix; per-invocation content mixed into otherwise-static docs. See `references/token-efficiency.md` §Static.
- **Session-log analysis** (only if the user has Claude Code / agent session logs, e.g. `~/.claude/projects/**/*.jsonl`): compute cache-read ratio, output density, duplicate-read ratio, and tool-use efficiency. `references/token-efficiency.md` §Sessions gives the exact metrics, formulas, and thresholds. If no logs exist, say so and skip — do not fabricate numbers.

Ground truth for caching mechanics (verify against Anthropic docs if quoting numbers): 5-min default TTL (refreshed on each hit), cache read 0.1× / 5-min write 1.25× base input, ~1,024-token minimum cacheable prefix, invalidation cascades tools → system → messages (one byte high in the prefix busts everything downstream).

### Step 4 — Report
Emit the report in the user's language using the template below. Lead with the grade and the single most valuable fix.

```
# Agent-Ready 진단: <repo>

## 등급: <band> (raw <n>/100, 관문 반영 <capped band>)
<한 줄 요약 — 가장 큰 병목 하나>

## 관문(Blocking) 점검
- B1 실행 가능한 검증: PASS/FAIL — <근거>
- B2 오해 유발 죽은코드: PASS/FAIL — <근거>
- B3 클린 체크아웃 재현: PASS/FAIL — <근거>

## 차원별 점수
| 차원 | 점수 | 근거 |
|---|---|---|
| 검증 관문 | n/25 | ... |
| 에이전트 컨텍스트 파일 | n/20 | ... |
| 탐색·발견성 | n/15 | ... |
| 문서·부족지식 | n/15 | ... |
| 의존성·모듈 경계 | n/15 | ... |
| 신선도 | n/10 | ... |

## 토큰·캐싱
- 정적 캐싱 위생: <발견 / 이상 없음>
- 세션 로그 분석: <지표 or "로그 없음, 생략">

## 우선순위 개선안 (효과 큰 순)
1. <구체 조치> — 근거: <어느 차원/관문을 올리는가>
2. ...
```

### Step 5 — Offer to fix (don't auto-apply)
List fixes ordered by leverage: unblock a failing gate first, then the lowest-scoring dimension. Offer to draft the missing artifact (a starter `AGENTS.md`, a per-package doc, a CI lint/test gate) — but only on the user's go-ahead, and keep authoring separate from this diagnostic pass.

---

## Scoring discipline
- **Never invent evidence.** "No AGENTS.md found" is a finding; guessing its contents is not.
- **Weight blocking gates correctly.** A high raw score with a failed gate must be reported as capped — that's the whole point of this skill over a spreadsheet.
- **Distinguish standard from opinion.** AGENTS.md precedence/nesting and the caching numbers are hard spec. Exact line limits (60 vs 200 vs 300) and category weights are conventions — present them as guidance, not law.
- **Re-audit is cheap.** After fixes, re-run Steps 1–2 on the changed dimensions only.
