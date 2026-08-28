# Full-Auto Plan Execution Implementation Plan

> **For agentic workers:** Task bodies live in the sibling `task-N.md` files; read each one immediately before implementing it, not all up front. Repo root is the `claude-harness` worktree you are already in.

**Goal:** Let the planning session run implementation to completion for modes ①/②b/③ by spawning a model-and-effort-explicit implementer subagent, keep mode ②a as the attended path for plans with human-confirmation gates, and make the plan-document review unconditional so the pre-flight check exists for runs nobody will watch.

**Architecture:** Three changes that depend on each other. (1) `plan-implementer` is replaced by three variants whose frontmatter pins `model` and `effort`, because the delegated implementer can no longer inherit them from a session relaunch that will not happen — the `Agent` tool has no `effort` argument, so frontmatter is the only carrier. (2) `writing-plans` gains a gate-count routing step: plans with zero confirmation gates go full-auto, plans with gates go to ②a, and mode ③ overrides that routing because its trigger is irreversibility rather than attendance. (3) The plan-document reviewer becomes unconditional, gains three lenses, and emits a machine-readable gate count that the routing step consumes.

**Tech Stack:** POSIX shell (`sh`), Markdown, TOML, JSON, Python 3 (only inside existing validation scripts), `jq`, `git`, `gh`.

---

## Global Constraints

- **Plan documents are English; everything else stays Korean.** Skill bodies, hook comments and injected hook strings, `docs/workflow-spec.md`, `README.md`, `docs/workflow.html`, and `home/HARNESS-LOG.md` are read by a person and stay in Korean (spec R19).
- **Version bump target is `1.17.0`, not `1.16.0`.** The repo manifests say `1.15.0` but `~/.claude/plugins/cache/woobin-harness/woobin-harness/` already has a frozen `1.16.0` directory. Writing `1.16.0` lands in an existing frozen directory and the update silently does nothing. Both `woobin-harness/.claude-plugin/plugin.json` and `woobin-harness/.codex-plugin/plugin.json` must carry the same value.
- **`./scripts/check-harness-docs.sh` is the mechanical gate for every count.** It compares the real file counts against `README.md`, `woobin-harness/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `docs/workflow-spec.md`, requires a `` `<agent-name>` `` row in `docs/workflow-spec.md` §4 for every agent file, requires `docs/workflow.html` to change when an agent is **added**, and fails if either `plugin.json` version is unchanged. Do not hand-audit what it counts.
- **Never write `AskUserQuestion` into a subagent contract.** It is removed from every subagent (`docs/workflow.html:322`). A gate is always "stop and report", never "ask".
- **Do not add a verification instruction to any implementer prompt.** Spec R9. The implementer runs the completion-check commands the task names; independent review is `plan-reviewer`'s job.
- **`docs/woobin_plan/plans/**` is append-only.** Do not edit, move, or delete existing plan directories, including this one, while implementing.

---

## Tasks

| # | Title | Files | Completion check |
|---|---|---|---|
| 1 | Implementer variants + mechanical name lock | `woobin-harness/agents/plan-implementer-*.md`, `codex/agents/plan-implementer-*.toml`, `scripts/test-agents.sh`, `scripts/validate-codex.sh` | `./scripts/test-agents.sh && claude plugin validate ./woobin-harness` |
| 2 | Execution mode contracts (both hosts) | `woobin-harness/plan-exec-modes.md`, `woobin-harness/plan-exec-modes-codex.md` | `./scripts/test-agents.sh` |
| 3 | Plan-document reviewer: unconditional, 3 lenses, report-everything | `woobin-harness/skills/writing-plans/plan-document-reviewer-prompt.md` | `./scripts/test-skills.sh` |
| 4 | `writing-plans` handoff rewrite | `woobin-harness/skills/writing-plans/SKILL.md` | `./scripts/test-skills.sh` |
| 5 | Hook backstop branch | `woobin-harness/hooks/plan-saved-session-boundary.sh` | `./scripts/test-hooks.sh` |
| 6 | Doc sync, version bump, machine cleanup | `docs/workflow-spec.md`, `README.md`, `docs/workflow.html`, `home/HARNESS-LOG.md`, `CLAUDE.md`, both `plugin.json`, `.claude-plugin/marketplace.json` | `./scripts/check-harness-docs.sh && ./scripts/test-hooks.sh && ./scripts/test-skills.sh && ./scripts/test-agents.sh && ./scripts/validate-codex.sh` |

---

## Ordering

Single track. Every task depends on the one before it, so there is no parallel opportunity here.

- **Task 1 → Task 2**: the mode files name the agents by their exact new names. Writing them before the agents exist means `test-agents.sh` cannot check the cross-reference.
- **Task 2 → Task 3**: the reviewer prompt's gate-inventory lens exists to feed the routing rule that Task 2 writes down. The prompt must quote the same three routing outcomes.
- **Task 3 → Task 4**: `SKILL.md` dispatches the reviewer prompt unconditionally and consumes its `**Gates:** N` line, so the prompt's output format must be final first.
- **Task 4 → Task 5**: the hook is the backstop for sessions that run without the skill; it must describe the same procedure the skill just gained, and it points at `plan-exec-modes.md` for the details.
- **Task 5 → Task 6**: `check-harness-docs.sh` requires `docs/workflow-spec.md` and `docs/workflow.html` to change in the same working tree as the hook/agent changes, and requires both `plugin.json` versions bumped. Running it before Tasks 1–5 are on disk produces failures that are not about Task 6.

Shared files: Tasks 3 and 4 both live under `woobin-harness/skills/writing-plans/` but touch different files. Tasks 1 and 6 both touch `scripts/` but different files (`test-agents.sh` vs none — Task 6 only edits `CLAUDE.md`'s and `README.md`'s listing of the validation commands).

Suggested layer split for delegation: **L1 = Task 1**, **L2 = Tasks 2–3**, **L3 = Tasks 4–5**, **L4 = Task 6**.

---

## Rejected Alternatives

- **Keep `plan-implementer` alongside the three variants** — rejected because the un-pinned definition inherits session effort, which is exactly the failure this plan removes. Leaving it callable means some future session spawns a combination that appears in no mode, and nothing detects it. It is deleted, not deprecated.
- **Name the variants after mode numbers (`plan-implementer-mode2`)** — rejected because mode numbering has already churned once (② split into ②a/②b) and the names would have to churn with it. `model`+`effort` names are stable and, more importantly, mechanically comparable to the frontmatter they claim.
- **Trust the naming convention without a fixture** — rejected. Discipline 6 of `home/HARNESS-LOG.md` is "judge by source, not by name". A filename that asserts `sonnet-medium` is a second owner of a fact that lives in frontmatter, and a silent divergence there produces a run at the wrong effort with no symptom. `scripts/test-agents.sh` makes the name a derived value instead of a second owner.
- **Give the plan-document reviewer its own agent definition** — rejected. It runs inside the planning session, whose effort the user chose deliberately, so session-effort inheritance is correct here rather than a hazard. A dedicated definition would pin an effort that fights the user's choice, and it would make the agent count 7 with a fourth doc-sync surface. It stays a `general-purpose` dispatch driven by a prompt template.
- **Route every gated plan to ②a, including mode ③ plans** — rejected. ③'s trigger is irreversibility (migrations, prod-facing changes, UI automated gates cannot check), and ②a is `sonnet` + `medium`. Routing a migration plan to ②a because it contains one visual gate demotes the model and effort for the class of work that most needs them. Gates are an attendance question; modes are a model/effort question, and the stronger signal wins.
- **Use `PushNotification` to call the user at a gate** — rejected for now. It preserves unattended running with intervention intact, but it adds a delivery dependency this harness has never measured, and the ②a route already covers gated plans at zero new cost. Reconsider if gated plans turn out to be common enough that ②a's cost becomes the complaint.
- **Drop `memory: local` from the ① and ③ variants to avoid splitting the memory three ways** — rejected. The memory holds repo environment facts (which runner the completion checks need, where migrations live), which are mode-independent and equally useful to all three. Omitting it makes ① and ③ strictly worse at the one thing it exists for. The fragmentation cost is real but bounded by the 100-line cap already in the agent body, and it is recorded as an open measurement under `docs/workflow-spec.md` §8 O1.
- **Delete `~/.claude/agents/plan-implementer.md` outright during Task 6** — rejected. User-local agents override same-named plugin agents (`README.md`, 원본 머신 transition table), so the stale copy must stop being resolvable, but deleting a file that is not in this repo is not reversible from this repo. It is moved to a dated backup directory instead, matching the `~/.claude/hooks/.pre-plugin-260808/` precedent.
