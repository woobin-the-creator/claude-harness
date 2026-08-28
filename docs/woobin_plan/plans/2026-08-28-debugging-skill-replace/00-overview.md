# Replace `systematic-debugging` with `repro-loop` Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Task bodies live in the sibling `task-N.md` files; read each one immediately before implementing it, not all up front.

**Goal:** Delete the 274-line `systematic-debugging` skill (a lightly-edited copy of obra/superpowers) and replace it with a ~55-line self-authored skill `repro-loop` carrying only the three clauses that current research supports, then re-sync every document and manifest that names the old skill.

**Architecture:** `woobin-harness/skills/` is shared by both runtimes (Claude Code via `.claude-plugin/plugin.json`, Codex via `.codex-plugin/plugin.json`, both pointing at `./skills/`). So the replacement is one directory swap plus reference updates. Skill count stays at 21, which means the hardcoded `-eq 21` assertions in `scripts/test-skills.sh:19` and `scripts/validate-codex.sh:144` do NOT change — they are the gate that proves the swap was atomic.

**Tech Stack:** Markdown skills with YAML frontmatter, bash test fixtures, `claude plugin validate`.

## Global Constraints

- New skill name: `repro-loop`. Directory `woobin-harness/skills/repro-loop/`, single file `SKILL.md`. No supporting files.
- The `description` must NOT contain generic bug-report trigger words (`버그`, `에러`, `bug`, `error`, `failure`, `test failure`, `broken`, `throwing`, `slow`). It shares a runtime with `mattpocock-skills:diagnosing-bugs`, whose description already claims that trigger space; two descriptions competing for it is the prompt-conflict failure that `docs/workflow-spec.md` §4 records for `explain` / `explain-in-html`.
- Skill body language: Korean (matches `kick-off`, `interview`, `groupchat-debug`). Plan documents stay English.
- Skill count must remain **21**. Do not edit the `-eq 21` assertions.
- `docs/workflow.html` contains **no** mention of debugging or `systematic-debugging` (verified by grep). Do not add one and do not go looking for a line to edit there.
- There is no `version` field in `.claude-plugin/marketplace.json` or `.agents/plugins/marketplace.json` (verified). Only the two `plugin.json` files carry a version.
- Version bump target: `1.16.0` → `1.17.0`. Verified free: `~/.claude/plugins/cache/woobin-harness/woobin-harness/` holds 1.3.3, 1.6.0–1.12.0, 1.14.0, 1.15.0, 1.16.0. Repo and installed are both 1.16.0, so `+1` is safe this time — but re-run the check in Task 4 before writing.

## Tasks

| # | Title | Files | Completion check |
|---|---|---|---|
| 1 | Swap the skill directory | Create `woobin-harness/skills/repro-loop/SKILL.md`; delete `woobin-harness/skills/systematic-debugging/` | `./scripts/test-skills.sh` |
| 2 | Re-point routing and kill the dead `diagnose` reference | `woobin-harness/skills/kick-off/SKILL.md:31`, `woobin-harness/skills/groupchat-debug/SKILL.md:3`, `docs/workflow-spec.md:88`, `docs/workflow-spec.md:719` | `grep -rn 'systematic-debugging\|`diagnose`' woobin-harness/ docs/workflow-spec.md` must print nothing |
| 3 | Record the narrative in HARNESS-LOG | `home/HARNESS-LOG.md` | `grep -n '^## 32\.' home/HARNESS-LOG.md` |
| 4 | Version bump and full validation | `woobin-harness/.claude-plugin/plugin.json`, `woobin-harness/.codex-plugin/plugin.json` | `claude plugin validate ./woobin-harness && ./scripts/validate-codex.sh && ./scripts/test-hooks.sh && ./scripts/test-skills.sh && ./scripts/check-harness-docs.sh` |

## Ordering

- Task 1 must run first and must be atomic — create the new directory and delete the old one in the same commit, or `test-skills.sh` fails on `-eq 21`.
- Task 2 depends on Task 1 only for the new skill's name being final; it edits four different files, none of which Task 1 touches.
- Task 3 is independent of Tasks 1–2 in file terms (`home/HARNESS-LOG.md` only), but its text cites the new skill name, so run it after Task 1.
- Task 4 must run last. It is the gate: `test-skills.sh` and `validate-codex.sh` will fail if Task 1 left the count wrong, and `check-harness-docs.sh` will fail if Task 2 left a stale count in `README.md`.
- No two tasks share a file. All four are a single dependency chain by content, not by file contention.

## Rejected Alternatives

- **Keep `systematic-debugging` and just trim it.** Rejected: the parts worth keeping are three clauses, two of which the current body states *wrongly* (unconditional "create failing test before fix", and "Form Single Hypothesis"). A trim that changes the majority of the clauses is a rewrite with a misleading git history.
- **Delete it and route Claude to `mattpocock-skills:diagnosing-bugs` with no replacement.** Rejected: `skills/` is shared with Codex, which has no mattpocock plugin, so Codex would lose its debugging door and `kick-off`'s route list would diverge per runtime.
- **Vendor `mattpocock-skills:diagnosing-bugs` into the repo (MIT, attribution precedent exists in `woobin-harness/output-styles/ATTRIBUTION.md`).** Rejected: it recreates exactly the failure being removed — a frozen upstream copy that misses upstream updates. `systematic-debugging` was never touched after its import commit `d6c6a5b`.
- **Name the new skill `systematic-debugging` (keep the name, replace the body).** Rejected: the name collides head-on with the two most-installed public skills of the same name, which are both copies of the same superpowers document — the name signals the wrong method.
- **Add the two research clauses as an overlay on top of mattpocock's skill instead of a standalone skill.** Rejected: an overlay pointing at another plugin's skill is the dead cross-reference pattern that `HARNESS-LOG` #28 records; and it does not solve Codex.
- **Add a new rule to `docs/workflow-spec.md` §3.** Rejected: §0 requires a fillable `무효화 조건`, and the sample here is 5 real debugging episodes in two months. Same call as `interview` in §4.
