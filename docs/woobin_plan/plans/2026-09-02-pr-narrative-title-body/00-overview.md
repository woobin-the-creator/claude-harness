# PR Title and Body as Narrative Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Task bodies live in the sibling `task-N.md` files; read each one immediately before implementing it, not all up front.

**Goal:** Change the R15 procedure so a plan PR's title and body tell the story "what problem did the user actually have → how was it solved", written by invoking the `explain` skill, instead of the current slug title and pointer-only body.

**Architecture:** The R15 execution procedure has exactly one owner — the "중단 대비" subsection of `woobin-harness/plan-exec-modes.md`. This change edits that subsection (create-time block and ready-time block), adds a consumer section to `woobin-harness/skills/explain/SKILL.md` so sentence-level rules keep a single owner, appends two pointer lines to the existing `sdd-kickoff-guard.sh` R15 injection (no new hook), and then re-syncs the four documents that describe R15. No skill, hook, or agent is created or deleted, so every hardcoded count in `README.md`, both `plugin.json` files, and `docs/workflow-spec.md` §4 stays exactly as it is.

**Tech Stack:** Markdown procedure documents with YAML-frontmatter skills, POSIX `sh` hooks emitting `UserPromptSubmit` JSON via `jq`, bash fixture tests, `claude plugin validate`.

## Global Constraints

- **Plan PRs only.** This changes R15, which applies to `plan/<slug>` branches. Do not extend the narrative requirement to arbitrary PRs (hotfixes, dependency bumps).
- **Final title format is `<문제> — <해결 요지>`** (em dash `—`, U+2014, spaces on both sides). At `gh pr create` time the `<해결 요지>` half does not exist yet, so only `<문제>` is written; the full form is written at `gh pr edit` time just before `gh pr ready`.
- **`explain` is invoked, not paraphrased.** In Claude Code, call the `Skill` tool with `explain`. Never copy `explain`'s sentence rules into `plan-exec-modes.md` — duplicated ownership is the failure mode this repo has been bitten by repeatedly (`docs/workflow-spec.md` §6-6).
- **`explain` is invoked at both points** — once before `gh pr create`, once before `gh pr edit` + `gh pr ready`.
- **Source priority for the narrative facts**, in this exact order: `.claude/kickoff.local.md` (the user's verbatim first prompt) → the `interview` decision ledger → `00-overview.md` → the layer commit log. Fall through to the next when the previous is absent.
- **No new hook.** The pointer goes into the existing R15 block of `woobin-harness/hooks/sdd-kickoff-guard.sh` (lines 108–132), inside the same `if` that already gates on "repo has a remote".
- **The existing "PR 본문은 포인터만" rule stays.** The narrative is not an exception to it — plan directories survive merge in this repo (`docs/woobin_plan/plans/` still holds the merged `2026-08-27-full-auto-plan-execution` and `2026-08-28-debugging-skill-replace`), so the pointer is live. The narrative is a different thing: no repo document owns "the problem the user had, in the user's terms". `00-overview.md`'s `**Goal:**` line is already engineering-framed.
- **The `interview` auto-confirmed-decisions exception stays verbatim.** Do not delete or reword `woobin-harness/plan-exec-modes.md:69-72`.
- **Hook language is Korean**, matching every other string in `sdd-kickoff-guard.sh`. Skill body language for `explain` is **English**, matching the rest of that file.
- **Version bump target: `1.19.0` → `1.20.0`.** Verified free — `~/.claude/plugins/cache/woobin-harness/woobin-harness/` holds 1.3.3, 1.6.0–1.12.0, 1.14.0–1.19.0. Repo and installed are both 1.19.0, so `+1` is safe. Re-run the check in Task 5 before writing.
- **Counts do not change.** Do not edit any `[0-9]+개` figure in `README.md`, `docs/workflow.html`, or `docs/workflow-spec.md`.
- **Next `home/HARNESS-LOG.md` entry number is `## 35.`** (`## 34.` is the last one, at line 969).
- **`./scripts/validate-codex.sh` currently fails** on `kick-off`'s `disable-model-invocation` frontmatter key. That failure predates this plan. Do not fix it here and do not treat it as a regression.

## Tasks

| # | Title | Files | Completion check |
|---|---|---|---|
| 1 | Rewrite the R15 create/ready procedure | `woobin-harness/plan-exec-modes.md:51-98`, `woobin-harness/plan-exec-modes-codex.md:30-35` | `grep -c '어떻게 풀었나' woobin-harness/plan-exec-modes.md` prints `3`; `claude plugin validate ./woobin-harness` |
| 2 | Give `explain` a documented PR consumer | `woobin-harness/skills/explain/SKILL.md` | `./scripts/test-skills.sh` |
| 3 | Add the narrative pointer to the kickoff hook | `woobin-harness/hooks/sdd-kickoff-guard.sh:126-131`, `scripts/test-hooks.sh:144-161` | `./scripts/test-hooks.sh` |
| 4 | Re-sync the four R15 documents | `docs/workflow-spec.md:442-527`, `docs/workflow.html:203-210`, `home/HARNESS-LOG.md` | the five distinctive-phrase `grep -q` chain in task-4 Step 7, then `./scripts/check-harness-docs.sh` |
| 5 | Version bump and full validation | `woobin-harness/.claude-plugin/plugin.json`, `woobin-harness/.codex-plugin/plugin.json` | `claude plugin validate ./woobin-harness && ./scripts/test-hooks.sh && ./scripts/test-skills.sh && ./scripts/test-agents.sh && ./scripts/check-harness-docs.sh` |

## Ordering

- **Task 1 runs first.** Tasks 3 and 4 both quote or point at wording that Task 1 fixes; if Task 1's exact phrases (`어떻게 풀었나`, `explain`) are not final, the hook fixture in Task 3 asserts on a string that does not exist.
- **Tasks 2 and 3 are independent of each other** — different files, no shared symbols. Both depend on Task 1 only for the name `explain` and the two-invocation-point decision being final.
- **Task 4 runs after 1–3.** `scripts/check-harness-docs.sh:92` fails when `woobin-harness/hooks/` or `woobin-harness/agents/` changed in the diff without an accompanying documentation change. Task 3 edits a hook, so `check-harness-docs.sh` will report that gap until Task 4 lands. **This is why Task 3's completion check is `test-hooks.sh` and not `check-harness-docs.sh`** — do not "fix" Task 3 by editing docs inside it.
- **Task 5 runs last.** It is the gate: it re-runs every validator including the one Task 4 satisfies.
- **No two tasks share a file.** Tasks 1–4 form a single content-dependency chain, not a file-contention chain.

## Rejected Alternatives

- **Write the narrative only at `gh pr ready`.** Rejected: the draft PR exists for the entire implementation period, and during that window the PR list would show nothing but a slug — a reviewer has no reason to open it. The user chose both points.
- **Write the narrative only at `gh pr create`.** Rejected: at the first turn of implementation no code exists yet, so "how it was solved" is unknowable. This drops half of what the change is for.
- **Create a new hook that fires just before `gh pr ready`.** Rejected: costs one more hook, forces count updates in `README.md`, both `plugin.json` files, both marketplaces, `docs/workflow.html` and `docs/workflow-spec.md` §4, and `docs/workflow-spec.md` §6-6 forbids two hooks owning the same condition. The user chose the existing hook.
- **Change only `plan-exec-modes.md` and add no enforcement.** Rejected: R15 was left as pure procedure and was found dead on 2026-09-02 (`docs/workflow-spec.md:448-454`). Repeating the method that just failed is not a plan.
- **Add `.github/PULL_REQUEST_TEMPLATE.md`.** Rejected: the R15 procedure passes `--body` explicitly to `gh pr create`, which overrides the template. The template would be silently dead — the exact failure class this repo keeps hitting.
- **Inline `explain`'s writing rules into `plan-exec-modes.md`.** Rejected: two owners of the same prose rules, which is `docs/workflow-spec.md` §6-6's named failure mode, and the concrete precedent is a phrase deleted from a skill that survived hardcoded in a hook and kept being recommended five more times (`CLAUDE.md`).
- **Reference `explain` by name without invoking it.** Rejected by the user in favor of a real `Skill` call: a name-only reference has procedure-level force only, which contradicts the decision to back this with a hook pointer.
- **Title format `<type>: <문제 서술>`.** Rejected: the conventional-commit prefix eats the first ~10 characters of a one-line title. Recorded as an invalidation condition instead — if automated changelog or semantic-release is adopted, this format wins.
- **Title format `[<slug>] <문제 서술>`.** Rejected: the PR title becomes the squash merge commit subject, so a slug prefix restores exactly the state being fixed — `main`'s history currently reads `2026-08-28-debugging-skill-replace (#34)`.
- **Treat the narrative as a second exception to "PR 본문은 포인터만".** Rejected: merged plan directories are not actually deleted in this repo, so the pointer is live and the narrative is not competing with it for ownership.
