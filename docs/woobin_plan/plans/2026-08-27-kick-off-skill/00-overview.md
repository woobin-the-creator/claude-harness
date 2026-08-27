# kick-off Skill Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Task bodies live in the sibling `task-N.md` files; read each one immediately before implementing it, not all up front.

**Goal:** Add a single user-invoked entry point (`/kick-off`) to this harness so the user only has to remember one trigger, plus one `UserPromptSubmit` hook that recognises the keyword and nudges once when a session drifts out of the workflow.

**Architecture:** `kick-off` is a *thin router*, not a methodology. Its `SKILL.md` names the downstream skills and never restates what they do. It is user-invoked only (`disable-model-invocation: true` on Claude Code, `policy.allow_implicit_invocation: false` on Codex), so it cannot compete with `grill-me` for auto-invocation. A new hook `kickoff-guard.sh` covers the two paths the frontmatter switch closes off: it recognises the literal keywords `kickoff` / `kick-off` / `킥오프` in a prompt, and it injects one reminder per session when an implementation-intent prompt arrives while the recorded stage is still `spec` or `plan`. Durable state lives in `.claude/kickoff.local.md` (a gitignored per-repo file, modelled on the `ralph-loop` plugin's `.claude/ralph-loop.local.md`).

**Tech Stack:** POSIX `sh` hooks + `jq`, Markdown skills with YAML frontmatter, `agents/openai.yaml` for Codex skill policy, existing shell fixture suites (`scripts/test-hooks.sh`, `scripts/test-skills.sh`, `scripts/check-harness-docs.sh`, `scripts/validate-codex.sh`).

## Global Constraints

- Skill bodies, hook comments and injected text are written in **Korean**. Only the plan documents are English.
- The hook must **never block**. `additionalContext` injection only — no `decision: "block"`, no `permissionDecision: "deny"`.
- The drift branch fires **at most once per session** via a marker file, following the shape already used by `sdd-kickoff-guard.sh`.
- `kick-off/SKILL.md` must not restate any downstream skill's procedure. It names skills and nothing else.
- The hook injects a **file-read instruction** (`Read ${CLAUDE_PLUGIN_ROOT}/skills/kick-off/SKILL.md and follow it`), never "invoke the kick-off skill" — `disable-model-invocation: true` may remove the skill from the model's Skill listing, and a hook that names an unreachable skill dies silently.
- Both `woobin-harness/.claude-plugin/plugin.json` and `woobin-harness/.codex-plugin/plugin.json` move `1.14.0` → **`1.15.0`**. Verified absent from `~/.claude/plugins/cache/woobin-harness/woobin-harness/` (which holds 1.3.3, 1.6.0–1.12.0, 1.14.0); installed version is 1.14.0.
- Counts after this plan: **skills 20 → 21**, **hooks 12 → 13**, Codex-wired hooks **4 → 5**. Agents stay 4.
- `scripts/check-harness-docs.sh` reads only the **first** `훅 N개` / `스킬 N개` / `에이전트 N개` match per file. In `docs/workflow-spec.md` those first matches are the §4 headings at lines 616 / 668 / 649.
- Never modify an existing file under `docs/woobin_plan/plans/` — plans are append-only.

## Tasks

| # | Title | Files | Completion check |
|---|---|---|---|
| 1 | kick-off skill + skill-count sync | `woobin-harness/skills/kick-off/SKILL.md`, `woobin-harness/skills/kick-off/agents/openai.yaml`, `scripts/test-skills.sh`, `scripts/validate-codex.sh`, `README.md`, `docs/workflow-spec.md`, `docs/workflow.html`, `.claude-plugin/marketplace.json`, `woobin-harness/.claude-plugin/plugin.json`, `woobin-harness/.codex-plugin/plugin.json` | `./scripts/test-skills.sh && ./scripts/check-harness-docs.sh && claude plugin validate ./woobin-harness` |
| 2 | kickoff-guard hook + wiring + hook-count sync | `woobin-harness/hooks/kickoff-guard.sh`, `woobin-harness/hooks/claude-hooks.json`, `woobin-harness/hooks/hooks.json`, `.gitignore`, `scripts/test-hooks.sh`, `README.md`, `docs/workflow-spec.md`, `docs/workflow.html`, `.claude-plugin/marketplace.json`, `woobin-harness/.claude-plugin/plugin.json` | `./scripts/test-hooks.sh && ./scripts/check-harness-docs.sh` |
| 3 | Rule R20 + HARNESS-LOG #30 + full verification | `docs/workflow-spec.md`, `home/HARNESS-LOG.md` | `./scripts/check-harness-docs.sh && ./scripts/test-hooks.sh && ./scripts/test-skills.sh && ./scripts/validate-codex.sh` |

## Ordering

- Task 1 → Task 2 → Task 3, strictly serial. All three edit `docs/workflow-spec.md`, `README.md` and `docs/workflow.html`; Tasks 1 and 2 both edit `.claude-plugin/marketplace.json` and `woobin-harness/.claude-plugin/plugin.json`. There is no pair that shares no files, so parallel tracks are impossible.
- Task 2 depends on Task 1 only for the version bump already being present (Task 2 does not bump again — `check-harness-docs.sh` looks at the whole diff against `origin/main`, so one bump covers the branch).
- Task 3 depends on both: R20's mechanism section names the skill *and* the hook, and `home/HARNESS-LOG.md` records why both exist.

## Decision ledger (settled before this plan; do not re-litigate)

| # | Decision | Rejected — why |
|---|---|---|
| 1 | User-invoked only (`disable-model-invocation: true` + Codex `allow_implicit_invocation: false`) | Leaving it model-invoked — the deleted `brainstorming` skill fired **0 times** across 246 sessions in 3 days because it competed with `grill-me` for the same trigger space |
| 2 | Keyword trigger via `UserPromptSubmit` hook regex | Putting trigger phrases in `description` — incompatible with decision 1, and it revives the same competition |
| 3 | Body delegates only; zero lines of downstream procedure | Summarising each stage — this repo has a real incident where a copy left in a hook kept recommending a deleted skill 5 more times |
| 4 | Entry point chosen from repo state first; ask only when files cannot decide | Always starting at stage 1 — wastes a full round trip on days when the spec already exists |
| 5 | Durable state in `.claude/kickoff.local.md` | Session-start injection (the `superpowers` bootstrap shape) — already rejected in `docs/workflow-spec.md` §7-A for prompt conflict |
| 6 | **No difficulty routing.** An explicit `/kick-off` is taken as the user's own judgement that this is workflow-worthy | A one-line size test, and the `design-workflow` three-layer classifier — zero misroutes have been observed, and §7-A's precedent is to add machinery only after a failure is measured |
| 7 | The skill names three doors — feature development, product UI, debugging — and announces its pick in one line. No classifier is built, and branch (D) "small change" is not a door because decision 6 forbids judging size | Feature-development branch only — delivers half of "one trigger to remember" |
| 8 | Renaming `sdd-kickoff-guard.sh` is out of scope | Doing it here — filed as issue #28 so a regression in hook firing stays separable |
| 9 | Hook speaks **once per session on drift**, never blocks | Recording state silently (catches nothing) · reminding on every prompt (warning fatigue — the same failure `plugin-update-guard.sh` avoided by scoping its commit count) |

## Rejected Alternatives

- **Detecting drift with a `PreToolUse:Edit|Write` hook** — rejected because a non-blocking `additionalContext` channel is not confirmed for `PreToolUse` in this harness version (the two existing `PreToolUse` hooks use `permissionDecision`/`updatedInput`), and blocking is forbidden by decision 9. `UserPromptSubmit` has a proven non-blocking channel used by 9 of the 12 current hooks. Revisit if `PreToolUse` gains a documented `additionalContext` field.
- **A second hook script for the keyword branch** — rejected: both branches read the same state file and share the same marker directory, and `docs/workflow-spec.md` §4 counts hooks by `.sh` file, so splitting doubles the inventory rows for one behaviour.
- **Naming the skill in the hook's injected text** (`kick-off 스킬을 실행하라`) — rejected because `disable-model-invocation: true` may remove it from the model's reachable Skill list, and the failure would be silent. The hook injects a file path to read instead.
- **A routing eval suite mirroring `design-workflow/evals/`** — rejected for now under decision 6. `design-workflow`'s own eval set has 5 cases and **none** of them covers its `none` route, so the pattern does not yet prove the over-classification case anyway. Add cases only after a real misroute is observed.
- **Storing state outside the repo (`~/.claude/kickoff/<hash>.md`)** — rejected: git worktrees of this repo are used routinely, and a per-repo `.claude/` file keeps one state per worktree, which matches how a stage actually progresses. The cost is one `.gitignore` line.
- **Bumping the plugin version in every task** — rejected: `check-harness-docs.sh` evaluates the whole diff against `origin/main`, so a single bump in Task 1 satisfies it for the rest of the branch, and repeated bumps would land on cache directories that may already exist.
