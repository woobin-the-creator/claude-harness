# Design Workflow Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one routed `design-workflow` skill that combines direction finding, project evidence, implementation contracts, render review, and rule evolution while keeping optional structured `DESIGN.md` state machine-checkable.

**Architecture:** A short `SKILL.md` classifies work and loads only the required reference modules. A dependency-free Node validator checks the optional managed section of `DESIGN.md`; project-specific guards remain in the target project's existing component, lint, test, and CI stack. The current `design-rules` becomes a compatibility entry over the new shared modules so there is one source of truth and no competing broad trigger.

**Tech Stack:** Claude Code plugin skills, Markdown, JSON embedded in Markdown, Node.js standard library, POSIX `sh`, Git, optional Claude CLI headless eval.

**Design spec:** `docs/woobin_plan/specs/2026-08-12-design-workflow-design.md`

## Global Constraints

- `DESIGN.md` is optional. Missing and unmanaged files must not block direction, implementation, review, or enforcement work.
- A managed `DESIGN.md` uses `design_workflow.enabled: true`, schema version `1`, and one marker-delimited JSON data block.
- Do not add package dependencies. The validator uses only Node.js standard-library modules.
- Do not duplicate token values or component prop inventories in `DESIGN.md`; store intent and authority paths.
- Do not treat observed local code as adopted policy without user approval.
- Do not promote an external precedent to `adopted` without local evidence.
- Review-only requests are read-only unless the user separately asks for fixes.
- A repeated incident is a promotion signal, not permission to enable a CI failure gate.
- Adding dependencies, changing public component APIs, migrating broad existing UI, enabling CI failure gates, and removing legacy/waiver behavior require user approval.
- Keep the first release framework-neutral. Generate project-local React/Vue/CSS/test guards only when a target project requests them.
- Preserve direct `design-rules` invocation through a compatibility entry; do not keep a second copy of its rules.
- Port the accepted #5/#6 behavior from `17994e0` into the new modules; do not cherry-pick that commit over the new file ownership.
- Paraphrase external sources. Record repository, commit, path, and license; copy no substantial upstream prose or code.
- Keep `home/HARNESS-LOG.md` unchanged until a real post-release measurement exists.
- Every harness change bumps `woobin-harness/.claude-plugin/plugin.json` from the execution-time base version. At the current base `5f8776f`, `plugin.json` is already `1.6.0`; the planned release is `1.7.0` and the resulting skill count is `27`.
- All shell tests use POSIX `sh` with `set -eu`.

## File Map and Ownership

| Path | Responsibility |
|---|---|
| `woobin-harness/skills/design-workflow/SKILL.md` | Thin Router, trigger boundaries, route announcement, permission boundary |
| `woobin-harness/skills/design-workflow/references/direction.md` | Conditional product-direction exploration |
| `.../system-evidence.md` | Authority order, actual-data design, information/a11y evidence, local vs external provenance |
| `.../implementation-contracts.md` | Portable component/API/state/overflow/overlay contracts and guard selection |
| `.../review.md` | Render matrix, craft tests, severity, read-only review contract |
| `.../evolution.md` | Decision lifecycle, promotion/demotion, waiver and approval rules |
| `.../design-document.md` | Managed `DESIGN.md` authoring contract and validator messages |
| `.../sources.md` | External commit/path/license provenance and #8 corrections |
| `.../templates/DESIGN.md` | Optional project-local starter document |
| `.../scripts/design-document-schema.mjs` | Closed enums and pure record validation |
| `.../scripts/validate-design-md.mjs` | CLI path resolution, managed-block parsing, filesystem checks, stable output |
| `.../tests/*` | Deterministic validator and skill/routing contracts |
| `.../evals/*` | Optional real-model routing acceptance, not a unit-test dependency |
| `woobin-harness/skills/design-rules/SKILL.md` | Backward-compatible direct entry into shared modules |
| `README.md`, `docs/workflow.html`, `docs/workflow-spec.md` | User and model workflow documentation |
| plugin and marketplace manifests | Version and skill-count release metadata |

## Interfaces Shared Across Tasks

```ts
type ProjectState = 'greenfield' | 'established' | 'mixed' | 'legacy'
type DirectionStatus = 'unset' | 'candidate' | 'adopted'
type DecisionStatus =
  | 'observed'
  | 'candidate'
  | 'adopted'
  | 'component-enforced'
  | 'ci-enforced'
  | 'retired'
type SourceType =
  | 'user-decision'
  | 'local-code'
  | 'local-incident'
  | 'external-precedent'
type EnforcementType = 'component' | 'static' | 'unit' | 'a11y' | 'browser' | 'ci'
```

Validator CLI:

```text
node woobin-harness/skills/design-workflow/scripts/validate-design-md.mjs [<repo-root-or-DESIGN.md>]
```

Stable success outputs:

```text
DESIGN_ABSENT path=<absolute-path>
DESIGN_UNMANAGED path=<absolute-path>
DESIGN_OK schema=1 decisions=<count>
```

Invalid managed files exit `1` and print sorted `DESIGN_E_* path=<json-pointer-or-file> message=<text>` lines to stderr.

## Dependency Graph

```text
Layer 1: Task 1 (document contract) ─┐
         Task 2 (workflow modules)  ├─> Layer 2: Task 3 (Router + compatibility migration)
                                    └─> Layer 3: Task 4 (contracts + headless eval)
                                                └─> Layer 4: Task 5 (docs, metadata, release gates)
```

Tasks 1 and 2 share no implementation files and can be reviewed independently. Tasks 3–5 are serial because they consume the exact interfaces and wording established earlier.

## Task Index

1. [Optional structured DESIGN.md contract and validator](task-1-design-document.md)
2. [Progressively disclosed workflow modules](task-2-workflow-modules.md)
3. [Router and design-rules compatibility migration](task-3-router-migration.md)
4. [Routing contracts and real-model acceptance](task-4-routing-tests.md)
5. [Workflow docs, plugin metadata, and release validation](task-5-release.md)

## Rejected Alternatives

Implementation workers must preserve the full reasoning in the design spec. The load-bearing rejections are:

- No monolithic always-loaded skill: it makes small changes pay for direction and review context.
- No mandatory `DESIGN.md`: absence and unrelated existing files are valid states.
- No second machine registry: it creates two authorities and a synchronization problem.
- No framework-wide CLI in v1: project-local guards use the target's existing stack.
- No automatic policy or CI promotion based only on incident count.
- No continued duplicate full `design-rules`: compatibility must point at the new shared modules.

## Completion Gate

Run from repository root after Task 5:

```bash
sh woobin-harness/skills/design-workflow/tests/all.sh
sh scripts/check-harness-docs.sh
claude plugin validate ./woobin-harness
DRY_RUN=1 ./bootstrap.sh
git diff --check
```

Expected:

- design-workflow tests end with `ALL-OK`.
- document checker and plugin validator exit `0`.
- dry-run performs no writes outside its documented simulation.
- `git diff --check` emits no output.

The optional headless eval is recorded separately because it consumes model tokens and requires Claude CLI authentication:

```bash
sh woobin-harness/skills/design-workflow/evals/run-routing.sh all
```

It must pass before claiming routing quality was empirically measured, but its absence must not make deterministic plugin validation fail.
