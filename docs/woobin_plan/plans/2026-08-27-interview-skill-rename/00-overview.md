# Rename `grill-me` to `interview` + Re-ask Menu Rule Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Task bodies live in the sibling `task-N.md` files; read each one immediately before implementing it, not all up front.

**Goal:** Rename the `grill-me` skill to `interview`, add a rule that forbids re-serving an unchanged option menu when the user asks back, and make auto-confirmed decisions survive PR merge.

**Architecture:** This is a documentation and prose change across one skill body, one shared workflow doc, and five reference sites — there is no executable code. The skill body (`woobin-harness/skills/interview/SKILL.md`) is the single source of truth; every other file either routes to it by name or describes it. Three of the six changes are pure renames of live references; historical narrative in `home/HARNESS-LOG.md` and `docs/workflow-spec.md` keeps the old name on purpose, because those passages record measurements taken when the skill actually had that name. Validation is the repo's existing three-script suite plus `claude plugin validate`.

**Tech Stack:** Markdown, POSIX shell (`sh`/`bash`), `jq`, `git mv`, Claude Code plugin manifests.

## Global Constraints

- **Repo root for all paths:** `/Users/mac_wb/.paseo/worktrees/11zirkjp/rabid-stingray`. This is a git worktree; run everything from here and never `cd` to the original checkout.
- **Skill count stays 21.** This is a rename, not an addition. `scripts/test-skills.sh:19` and `scripts/validate-codex.sh:144` both hard-assert `21`; if either number needs to change, something went wrong.
- **Version bump target is `1.16.0`.** Verified on 2026-08-27: the frozen plugin cache at `~/.claude/plugins/cache/woobin-harness/woobin-harness/` holds `1.3.3, 1.6.0, 1.7.0, 1.8.0, 1.9.0, 1.10.0, 1.11.0, 1.12.0, 1.14.0, 1.15.0`; installed is `1.15.0`; repo is `1.15.0`. `1.16.0` is free. Both `woobin-harness/.claude-plugin/plugin.json` and `woobin-harness/.codex-plugin/plugin.json` must carry the same value.
- **Never use bare `git stash` / `git stash pop`.** The stash stack is shared with other worktrees and other sessions. Use a WIP commit instead.
- **Skill body prose stays Korean.** Only these plan documents are English. Every Korean block quoted in a task file is verbatim content to paste — do not translate it, do not re-word it, do not "improve" it.
- **`scripts/validate-codex.sh` is expected to FAIL.** It fails unconditionally because `woobin-harness/skills/kick-off/SKILL.md` carries `disable-model-invocation: true`, which the external Codex validator rejects. This is documented in `docs/codex-compatibility-audit-2026-08-12.md:55` and is intentional. Do not "fix" it; do not treat its failure as this plan's failure.
- **Do not touch `agents-skill-lock.json`.** Its `grill-me` entry at line 798 belongs to a third-party skill marketplace (`NomaDamas/k-skill`), not to this harness.

## Tasks

| # | Title | Files | Completion check |
|---|---|---|---|
| 1 | Rename skill directory and rewrite three sections of its body | `woobin-harness/skills/grill-me/SKILL.md` → `woobin-harness/skills/interview/SKILL.md` | `claude plugin validate ./woobin-harness && ./scripts/test-skills.sh` |
| 2 | Add the PR-body exception to `plan-exec-modes.md` | `woobin-harness/plan-exec-modes.md:47` | `command grep -c '자동 확정된 결정' woobin-harness/plan-exec-modes.md` returns `1` |
| 3 | Update the five live references to the old name | `woobin-harness/skills/kick-off/SKILL.md`, `woobin-harness/hooks/kickoff-guard.sh`, `woobin-harness/skills/writing-plans/SKILL.md`, `README.md`, `docs/workflow.html` | `./scripts/test-hooks.sh && ./scripts/test-skills.sh` |
| 4 | Update `workflow-spec.md` §4 and append the `HARNESS-LOG.md` entry | `docs/workflow-spec.md`, `home/HARNESS-LOG.md` | `command grep -c '^## 31\. grill-me → interview' home/HARNESS-LOG.md` returns `1` |
| 5 | Bump both manifests to 1.16.0, fix the local `skillOverrides` key, run the full suite | `woobin-harness/.claude-plugin/plugin.json`, `woobin-harness/.codex-plugin/plugin.json`, `~/.claude/settings.json` | `./scripts/test-hooks.sh && ./scripts/test-skills.sh && claude plugin validate ./woobin-harness` |

## Ordering

- Task 1 must run first: Tasks 3, 4, and 5 all reference the new directory path `woobin-harness/skills/interview/`.
- Task 2 is independent of Task 1 — different file, no shared lines — but its prose cites `interview §④`, so run it after Task 1 so the cited section exists.
- Task 3 depends on Task 1 (the renamed directory must exist before `kick-off` routes to it).
- Task 4 depends on Tasks 1–3: the §4 inventory in `workflow-spec.md` lists what Tasks 1 and 3 produced, and the `HARNESS-LOG` entry narrates all of them.
- Task 5 must run last. The version bump is meaningless until every file it packages is final, and `~/.claude/settings.json` must be edited after the skill directory is renamed or the override key will point at a directory that does not exist yet.
- **No two tasks share a file.** Task 1 owns the skill body, Task 2 owns `plan-exec-modes.md`, Task 3 owns the five reference files, Task 4 owns the two doc files, Task 5 owns the two manifests plus one file outside the repo. The chain is strictly sequential by dependency, not by file contention.

## Rejected Alternatives

- **A difficulty-based skip route (skip the interview for easy work)** — rejected because `woobin-harness/skills/kick-off/SKILL.md:36-38` already carries a section titled `## 난이도는 판정하지 않는다` ruling exactly this out, and because the failure mode measured in `HARNESS-LOG` #26 was the model asking *too little*, not too much. A skip route hands that failure mode an escape hatch, and the entity judging difficulty is the same model that committed the failure.
- **A "zero blanks → skip the interview" route** — rejected as redundant. The skill body already scales output to change size (`두 줄짜리 변경엔 두 줄짜리 스펙이면 충분하다`).
- **New prose for "auto-select the obviously-best option"** — rejected because `§③` already contains the full branch: three filters (same code either way / convention wins / cheap to reverse) plus the override (`트레이드오프가 크고 그 대가를 사용자가 치른다면 … 빈칸이다`). Adding a second statement of the same rule creates a second owner that will drift.
- **A session-level round cap ported from `oh-my-claudecode`'s `deep-interview` (round 10 warning / round 20 hard cap)** — rejected on measurement. Across all 31 `/grill-me` invocations logged 2026-08-03..08-27, the 6 that actually loaded the current skill body ran 1, 5, 1, 1, 1, 1 rounds — median 1. A cap of 5 catches 0 of 6. Worse, the one 5-round session was legitimate: the user's round-1 and round-2 answers were both requests for the tradeoff information that `§③` already requires in the first menu. A cap would have closed that blank before the user saw option B's cost.
- **A per-blank re-ask hard stop (3rd ask → force the default)** — rejected for the same reason: it would have fired on the only measured long session, where the user was doing legitimate information-gathering rather than stalling.
- **`deep-interview`'s Round 0 topology enumeration gate** — rejected for lack of evidence. Across the 6 current-body sessions, sibling-component starvation occurred 0 times; the 5-round session emitted `[?1][?2][?3]` in a single round once the approach was settled, and the multi-item session of 2026-08-26 00:25 addressed every numbered item the user raised. The existing rule (`사용자의 요청은 대개 이미 1. 2. 3. 번호 목록으로 온다. 그 번호를 유지해라`) is already doing this job.
- **`deep-interview`'s ambiguity scoring (0.0–1.0 weighted dimensions gated on a `settings.json` threshold)** — rejected because the model scores itself and then gates itself on its own score, with an obvious bypass (declare the number below threshold). This repo already rejected `spec_contract.py` for the identical reason, recorded in `docs/woobin_plan/plans/2026-08-26-codex-harness-port/00-overview.md:46`: `검증기는 형식만 보지 정직함은 못 본다`.
- **`deep-interview`'s one-question-per-round rule** — rejected because the current skill adopted the opposite on measurement (`서로 독립인 빈칸은 한 번에 최대 4개까지 묶어 왕복을 줄인다`), and one-at-a-time is a *cause* of long interviews, not a cure for them.
- **`deep-interview`'s challenge-agent modes (contrarian at round 4, simplifier at 6, ontologist at 8)** — rejected because they lengthen interviews by design, which is the symptom being treated.
- **`deep-interview`'s `state_write` interview-resume state** — rejected as duplicate: `§④` already mandates updating the ledger every round, and `.claude/kickoff.local.md` already carries durable stage state.
- **Enforcing the "cost line per option" rule with a hook or validator** — rejected. The 5-round session's cause was non-compliance with a rule that already exists, not a missing rule. A validator over prose can only check shape, which opens the same bypass as the ambiguity score.
- **Copying the full decision ledger into the PR body** — rejected: it creates two owners for the same living document, which is exactly what `plan-exec-modes.md:47` forbids. Only the auto-confirmed rows and assumptions go in, because those are the rows with no other owner after merge.
- **Mandating a `docs/woobin_plan/specs/` file for every interview** — rejected: it contradicts the existing rule `결정 서너 개짜리면 파일은 중복이다` and would accumulate spec files for three-decision changes.
- **Promoting the re-ask rule to a new `### R21` in `docs/workflow-spec.md` §3** — rejected on the repo's own precedent. `docs/workflow-spec.md:735-736` already declined to make the 2026-08-21 rewrite a §3 rule, verbatim: `**§3에 새 규칙을 만들지 않았다** — 훅·에이전트에 걸리는 하네스 규칙이 아니라 스킬 내부 규율이고, 채울 \`무효화 조건\`이 "실측 27건"뿐이라 §0이 요구하는 등급에 못 미친다.` The re-ask rule is the same shape (skill-internal discipline, not a hook or agent contract) with a *thinner* measurement — 6 sessions versus 27. Admitting it while a stronger case was denied would void §3's bar. It goes in the §4 narrative instead.
- **Rewriting `grill-me` mentions inside `home/HARNESS-LOG.md` and the history sections of `docs/workflow-spec.md`** — rejected. Those passages record measurements taken when the skill carried that name; renaming them detaches the evidence from what was measured.
- **Editing `woobin-harness/plan-exec-modes-codex.md` to match Task 2** — rejected because it has no PR/branch section at all (verified: zero matches for `PR` or `gh pr create` in its 78 lines). The Claude Code branch/PR flow is Claude-only, so there is no counterpart passage to keep in sync.
