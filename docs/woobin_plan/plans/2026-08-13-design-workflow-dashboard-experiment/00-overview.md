# Design Workflow Dashboard Experiment Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session. The planning conversation is not needed. The orchestrator reads only this file; each implementation context receives only its assigned `task-N.md` and allowed input package.

**Goal:** Build three independently generated interactive cold-chain dashboards—no design skill, legacy `design-rules`, and PR #9 `design-workflow`—then expose them as blind X/Y/Z variants for neutral functional and user evaluation.

**Architecture:** A deterministic common package fixes product requirements, fixture pressure, runtime versions, and neutral test hooks. A sealing script creates three auditable input packages, after which three fresh-history workers build isolated variant directories in separate git worktrees. The integration branch runs only function-contract checks, then creates a runtime-only blind mapping, launcher, screenshots, and a scorecard that reveal no A/B/C condition before the user records a preference.

**Tech Stack:** Node.js 22.23.1, npm 10.9.8, React 19.2.8, React DOM 19.2.8, TypeScript 7.0.2, Vite 8.1.5, `@vitejs/plugin-react` 6.0.4, `lucide-react` 1.28.0, Vitest 4.1.10, Playwright 1.61.1, CSS, HTML, SVG, Node standard library.

**Design spec:** `docs/woobin_plan/specs/2026-08-13-design-workflow-dashboard-experiment-design.md`

## Global Constraints

- Build exactly three conditions: baseline with no design/web-production skill, legacy `design-rules` snapshotted from `36a8fe8e54c162f7b77e52c15cc70d649674505c`, and PR #9 `design-workflow` from the execution base.
- Run all three generation workers with the same model, reasoning effort, time budget, common brief, functional contract, fixture source, dependency lockfile, and completion command.
- Give each generation worker a fresh context with no prior turns and a separate git worktree. Baseline reads/writes only `inputs/baseline/` and `variants/baseline/`; the other two conditions follow the same explicit matching-directory rule.
- Do not expose the design spec, this plan, evaluation rubric, sibling variant code, user dislikes, expected UX remedies, or A/B/C mapping to a generation worker.
- Common input describes tasks, data sizes, state requirements, viewport requirements, and neutral `data-testid` hooks; it does not specify field widths, search presence or position, overlay dismissal, list height, table column sizing, visual tokens, focus strategy, or component library.
- Use React, TypeScript, Vite, `lucide-react`, CSS, HTML, SVG, and browser APIs only. Do not add a UI component library, chart library, state library, router, CSS framework, or backend.
- Keep data in browser memory. Do not add authentication, database, server API, telemetry, or network-dependent runtime behavior.
- Each variant owns its React components and CSS. Runtime imports from `common/`, `inputs/`, or sibling variants are forbidden; copy the exact common `types.ts` and `fixtures.ts` snapshot into the variant.
- All three variants must build with the single root `package-lock.json`. Variant workers must not run `npm install`, edit root dependency files, or add dependencies.
- The neutral repair loop may report only a missing required function, state, hook, build error, or runtime error. It must not mention layout, sizing, search, dismissal, overflow strategy, accessibility quality, or aesthetics. Allow at most one repair turn per condition and record it.
- Do not create a managed `DESIGN.md`. The `design-workflow` condition treats its direction as a disposable candidate for this mockup and does not promote project defaults.
- Randomize X/Y/Z only after all three variants and neutral gates are complete. Store the mapping under ignored `evaluation/private/`; never embed condition names in launcher HTML, client bundles, screenshots, or scorecard labels.
- Do not run the reveal command before the user records blind scores and preference.
- The experiment is exploratory. One sample per condition does not establish general causality; run a second round only if the result is inconclusive under the spec's criteria.

## Fresh Execution Worktree

Start implementation from a new worktree based on the branch containing this plan:

```bash
git worktree add -b experiment/design-workflow-dashboard ../pumped-sheep-dashboard-experiment agent/design-workflow
cd ../pumped-sheep-dashboard-experiment
```

Do not implement in the planning worktree. Before Task 3, Task 2 creates three additional track worktrees from the sealed-input commit.

## File Map and Ownership

| Path | Responsibility | Owner |
|---|---|---|
| `experiments/design-workflow-dashboard/package.json` | One exact dependency graph and commands for every condition | Task 1 |
| `experiments/design-workflow-dashboard/package-lock.json` | Reproducible shared dependency versions | Task 1 |
| `experiments/design-workflow-dashboard/tsconfig.base.json` | Strict shared TypeScript compiler options | Task 1 |
| `experiments/design-workflow-dashboard/common/product-brief.md` | Product and user tasks visible to every condition | Task 1 |
| `experiments/design-workflow-dashboard/common/functional-contract.md` | Required behavior, demo states, and neutral automation hooks | Task 1 |
| `experiments/design-workflow-dashboard/common/src/types.ts` | Shared data shape copied verbatim into variants | Task 1 |
| `experiments/design-workflow-dashboard/common/src/fixtures.ts` | Deterministic 64/96/42/12/30 data generator | Task 1 |
| `experiments/design-workflow-dashboard/common/tests/fixtures.test.ts` | Count and data-pressure invariants | Task 1 |
| `experiments/design-workflow-dashboard/scripts/prepare-inputs.mjs` | Seal common files, condition prompts, and allowed skill snapshots | Task 2 |
| `experiments/design-workflow-dashboard/scripts/audit-inputs.mjs` | Prove common hashes match and condition files do not leak | Task 2 |
| `experiments/design-workflow-dashboard/inputs/*` | Committed immutable packages handed to the three workers | Task 2 |
| `experiments/design-workflow-dashboard/variants/baseline/*` | No-skill dashboard implementation | Task 3 only |
| `experiments/design-workflow-dashboard/variants/design-rules/*` | Legacy-skill dashboard implementation | Task 4 only |
| `experiments/design-workflow-dashboard/variants/design-workflow/*` | New-workflow dashboard implementation | Task 5 only |
| `experiments/design-workflow-dashboard/scripts/serve-built.mjs` | Static server for condition and blind routes | Task 6, extended Task 7 |
| `experiments/design-workflow-dashboard/evaluation/functional.spec.ts` | Neutral function-contract browser checks | Task 6 |
| `experiments/design-workflow-dashboard/evaluation/playwright.config.ts` | Browser test server and viewport configuration | Task 6 |
| `experiments/design-workflow-dashboard/launcher/*` | Condition-free X/Y/Z entry UI | Task 7 |
| `experiments/design-workflow-dashboard/scripts/create-blind-map.mjs` | Runtime-only random mapping creation | Task 7 |
| `experiments/design-workflow-dashboard/scripts/reveal-map.mjs` | Explicit post-score reveal command | Task 7 |
| `experiments/design-workflow-dashboard/evaluation/capture-scenes.mjs` | Identical blind screenshots and interaction scenes | Task 7 |
| `experiments/design-workflow-dashboard/evaluation/collect-measurements.mjs` | Blind field-width and viewport-overflow measurements | Task 7 |
| `experiments/design-workflow-dashboard/evaluation/rubric.md` | Hidden 100-point scorecard created after generation | Task 7 |
| `experiments/design-workflow-dashboard/evaluation/private/` | Ignored mapping; never committed or served | Runtime only |
| `experiments/design-workflow-dashboard/evaluation/artifacts/` | Ignored blind screenshots | Runtime only |
| `experiments/design-workflow-dashboard/README.md` | Operator instructions without pre-score mapping | Task 8 |
| `experiments/design-workflow-dashboard/generation-ledger.json` | Prompt hashes, skill hashes, build/gate outcomes, repair count | Task 8 |

## Shared Interfaces

The exact domain types are defined in Task 1 and copied unchanged into each variant:

```ts
export type ShipmentStatus =
  | 'normal'
  | 'temperature-excursion'
  | 'delayed'
  | 'sensor-offline'
  | 'resolved'

export type TemperatureState = 'normal' | 'warning' | 'critical' | 'unavailable'
export type AlertResolution = 'open' | 'acknowledged' | 'resolved'

export interface ExperimentData {
  shipments: Shipment[]
  drivers: Driver[]
  vehicles: Vehicle[]
  hubs: Hub[]
  alerts: Alert[]
  eventsByShipment: Record<string, TimelineEvent[]>
  anomalySeries: AnomalyPoint[]
}

export function createExperimentData(): ExperimentData
```

All variant roots accept the same reproducible URL states:

```text
/?demo=default
/?demo=loading
/?demo=empty
/?demo=error
```

All variants expose the neutral hooks below. Hook names describe required tasks, not visual treatment:

```text
app-root
loading-state
empty-state
error-state
filter-trigger
filters-surface
filter-status
filter-status-option-temperature-excursion
filter-hub
filter-hub-option-HUB-12
filter-date
filter-temperature
filter-driver
filter-apply
results-count
sort-temperature
select-all-visible
row-select-SHP-001
bulk-action-trigger
bulk-resolve
shipment-status-SHP-001
notifications-trigger
notifications-surface
notification-ALT-030
notification-toggle-read-ALT-030
notification-state-ALT-030
notification-toggle-resolution-ALT-030
notification-resolution-ALT-030
shipment-open-SHP-001
shipment-detail
edit-dispatch
driver-control
driver-options
driver-option-DRV-096
dispatch-driver-name
dispatch-phone
dispatch-tracking
dispatch-min-temperature
dispatch-max-temperature
dispatch-notes
save-dispatch
cancel-dispatch
dispatch-driver
validation-error
save-success
```

For native selects, domain IDs are option values; for custom selectors, the corresponding option hook is clickable. Notification state hooks expose `data-state="unread|read"` and `data-state="open|acknowledged|resolved"`. The hook contract does not require a search control, a popover, a modal, a drawer, a particular field width, or a dismissal mechanism. Those remain observable design choices.

## Dependency Graph

```text
Layer 1: Task 1 (common runtime + deterministic data)
   └─> Layer 2: Task 2 (sealed condition inputs + audit)
          ├─> Track A: Task 3 (baseline variant) ───────┐
          ├─> Track B: Task 4 (legacy rules variant) ──┼─> Layer 4: Task 6 (integrate + neutral gate)
          └─> Track C: Task 5 (new workflow variant) ──┘
                                                        └─> Layer 5: Task 7 (blind launcher + captures)
                                                               └─> Layer 6: Task 8 (ledger + final gate)
```

Tasks 3–5 share no files, run in separate git worktrees, receive no prior conversation, and must start at the same Task 2 commit. They are the only parallel fan-out. Tasks 6–8 are serial because they consume all three variants and must not exist in generator inputs.

## Task Index

1. [Common runtime, domain types, and deterministic fixture pressure](task-1-common-foundation.md)
2. [Sealed condition packages and isolation audit](task-2-sealed-inputs.md)
3. [Condition A: baseline dashboard in a fresh context](task-3-baseline-variant.md)
4. [Condition B: legacy `design-rules` dashboard in a fresh context](task-4-design-rules-variant.md)
5. [Condition C: PR #9 `design-workflow` dashboard in a fresh context](task-5-design-workflow-variant.md)
6. [Variant integration and neutral browser function gate](task-6-neutral-functional-gate.md)
7. [Blind X/Y/Z launcher, capture scenes, and hidden scorecard](task-7-blind-evaluation.md)
8. [Generation ledger, operator docs, and completion gate](task-8-release-gate.md)

## Review and Feedback Boundaries

- Tasks 1–2: normal correctness review against exact data, packaging, and leak-prevention contracts.
- Tasks 3–5: do not conduct design review or compare outputs. A worker may run typecheck/build; an independent gate in Task 6 checks functions.
- Task 6: report only functional failures using the neutral template in that task. One fresh-context repair turn per failed variant is permitted.
- Task 7: verify that no client-visible A/B/C mapping or condition name leaks. Do not score or reveal conditions.
- Task 8: run release gates and hand the blind launcher to the user. Do not run `reveal-map.mjs`.

## Rejected Alternatives

- No shared wireframe or shared React components: either would pre-decide the design choices under study.
- No product-name-only prompt: feature-scope variance would dominate the skill comparison.
- No design feedback during repair: it would leak the hidden hypothesis into later output.
- No same-context sequential generation: prior results and user preferences would contaminate later conditions.
- No condition labels in the launcher: expectation bias would affect the score.
- No three samples per condition in round one: begin with one exploratory sample and expand only if inconclusive.
- No framework adapter or backend: they add work unrelated to the UI judgment being measured.

## Completion Gate

Run from `experiments/design-workflow-dashboard/` after Task 8:

```bash
npm ci
npx playwright install chromium
npm run test:common
npm run audit:inputs
npm run build:variants
npm run test:functional
npm run build:launcher
npm run test:blind
npm run capture
npm run measure
npm run audit:experiment
git diff --check
```

Expected:

- fixture tests prove 64 shipments, 96 drivers, 42 vehicles, 12 hubs, 30 alerts, and 12–40 events per shipment;
- input audit proves byte-identical common packages and exactly the allowed skill snapshot per condition;
- all three variants and launcher build with the same lockfile;
- neutral browser tests pass at 1440×900 and 1024×768;
- blind audit finds no `baseline`, `design-rules`, `design-workflow`, `Condition A`, `Condition B`, or `Condition C` in launcher client assets or screenshot paths;
- capture creates the agreed blind scenes for X, Y, and Z;
- measurements record the six dispatch-control widths and document overflow at both viewports under blind letters only;
- private map exists locally with mode `0600`, contains each condition once, and remains gitignored;
- generation ledger records identical common hashes, condition-specific skill hashes, worker model/effort, build results, neutral repair counts, and no reveal;
- `git diff --check` emits no output.

Do not run `npm run reveal` until the user has submitted blind scores and preference.
