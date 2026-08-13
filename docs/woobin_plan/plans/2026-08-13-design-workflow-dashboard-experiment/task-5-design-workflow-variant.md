# Task 5: Condition C — PR #9 `design-workflow` Dashboard in a Fresh Context

**Files:**
- Create only under worktree `../pumped-sheep-dashboard-design-workflow`:
  - `experiments/design-workflow-dashboard/variants/design-workflow/index.html`
  - `experiments/design-workflow-dashboard/variants/design-workflow/vite.config.ts`
  - `experiments/design-workflow-dashboard/variants/design-workflow/tsconfig.json`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/main.tsx`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/App.tsx`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/styles.css`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/types.ts`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/fixtures.ts`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/components/OperationalSummary.tsx`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/components/FilterSurface.tsx`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/components/ShipmentTable.tsx`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/components/NotificationSurface.tsx`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/components/ShipmentDetail.tsx`
  - `experiments/design-workflow-dashboard/variants/design-workflow/src/components/DispatchEditor.tsx`
  - `experiments/design-workflow-dashboard/variants/design-workflow/GENERATION.md`

**Interfaces:**
- Consumes only: `inputs/design-workflow/`, root `package.json`, root lockfile, and installed modules from Task 2.
- Produces: a buildable Vite app under `variants/design-workflow/`, plus route/reference evidence in `GENERATION.md`.
- Task 6 cherry-picks the track commit and runs independent neutral browser checks.

**Isolation:** Run Task 5 concurrently with Tasks 3 and 4. Spawn one `worker` with `fork_turns: "none"`, model `gpt-5.6`, reasoning effort `xhigh`, and no inherited conversation. The worker owns only this variant and must neither inspect nor revert other work.

- [ ] **Step 1: Confirm clean isolated starting state and workflow inventory**

In `../pumped-sheep-dashboard-design-workflow` run:

```bash
git status --short --branch
git rev-parse HEAD
test ! -e experiments/design-workflow-dashboard/variants/baseline
test ! -e experiments/design-workflow-dashboard/variants/design-rules
test ! -e experiments/design-workflow-dashboard/evaluation
find experiments/design-workflow-dashboard/inputs/design-workflow/skill -type f | sort
```

Expected: clean branch at the Task 2 SHA and exactly five allowed workflow files: Router plus direction, system-evidence, implementation-contracts, and review.

- [ ] **Step 2: Send the exact fresh-context worker assignment**

Use this prompt without adding hidden criteria or preferred remedies:

```text
You own Condition C at ../pumped-sheep-dashboard-design-workflow/experiments/design-workflow-dashboard/variants/design-workflow. You are not alone in the repository; do not inspect, edit, or revert files outside that variant except reading the root package.json/package-lock.json and your sealed input directory ../pumped-sheep-dashboard-design-workflow/experiments/design-workflow-dashboard/inputs/design-workflow. Read PROMPT.md, common/product-brief.md, common/functional-contract.md, common/src/types.ts, common/src/fixtures.ts, and skill/design-workflow/SKILL.md completely. Follow it as the only design skill and read only the bundled references required by the selected route. This is a disposable greenfield mockup: the approved product brief authorizes choosing one reversible candidate direction for this mockup, but do not create DESIGN.md or mark a project default adopted. Do not read repository woobin-harness files outside the sealed input, docs/woobin_plan, evaluation, launcher, git history, sibling variants, or image evidence. Do not use any other design/UI/web-production/image-generation skill. Implement the complete interactive React mockup in one turn, copying types.ts and fixtures.ts byte-for-byte. Use only root-lockfile dependencies. Run `npm run build:design-workflow` from the experiment root. Write GENERATION.md with condition `design-workflow`, the exact route announcement, loaded reference paths, common and skill hashes, build command/result, and concise implementation assumptions; do not compare, critique, or score the result. Commit only variants/design-workflow with message `Build design-workflow cold-chain dashboard`. Return the commit SHA, announced route, loaded references, and build status in at most 25 lines.
```

- [ ] **Step 3: Use the same neutral app shell while preserving workflow choice**

Write `vite.config.ts`:

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  root: import.meta.dirname,
  base: './',
  plugins: [react()],
  build: { outDir: 'dist', emptyOutDir: true },
})
```

Write `tsconfig.json`:

```json
{
  "extends": "../../tsconfig.base.json",
  "include": ["src"]
}
```

Write `src/main.tsx`:

```tsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './App'
import './styles.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
```

`App.tsx` parses the four `demo` query values, creates one in-memory fixture snapshot, and owns cross-surface state. The component boundaries do not prescribe layout. The worker must make the route announcement before design work and preserve it verbatim in `GENERATION.md`.

- [ ] **Step 4: Audit the loaded route before build**

Inspect only `GENERATION.md` metadata, not the UI, and require:

```text
작업 유형: greenfield · 사용 모듈: direction → system-evidence → implementation-contracts → review
```

The loaded-reference list must contain those four files and must not contain `evolution.md`, `design-document.md`, `sources.md`, or any nonsealed skill. If the route metadata is wrong, reject the track before looking at its render and restart Task 5 from the same sealed base with the same prompt.

- [ ] **Step 5: Build without comparison or subjective correction**

Run:

```bash
cd experiments/design-workflow-dashboard
cmp common/src/types.ts variants/design-workflow/src/types.ts
cmp common/src/fixtures.ts variants/design-workflow/src/fixtures.ts
npm run build:design-workflow
test ! -e variants/design-workflow/DESIGN.md
```

Expected: copy checks and build pass, and no managed design document exists. Do not show the worker other variants, evaluation rubric, screenshots, or user preferences.

- [ ] **Step 6: Commit the isolated variant**

```bash
git add experiments/design-workflow-dashboard/variants/design-workflow
git commit -m "Build design-workflow cold-chain dashboard"
git status --short
```

Expected: clean track with one variant commit after the common sealed-input base. Task 6 performs integration.
