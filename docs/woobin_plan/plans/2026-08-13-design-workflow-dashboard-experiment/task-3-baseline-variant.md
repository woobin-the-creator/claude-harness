# Task 3: Condition A — Baseline Dashboard in a Fresh Context

**Files:**
- Create only under worktree `../pumped-sheep-dashboard-baseline`:
  - `experiments/design-workflow-dashboard/variants/baseline/index.html`
  - `experiments/design-workflow-dashboard/variants/baseline/vite.config.ts`
  - `experiments/design-workflow-dashboard/variants/baseline/tsconfig.json`
  - `experiments/design-workflow-dashboard/variants/baseline/src/main.tsx`
  - `experiments/design-workflow-dashboard/variants/baseline/src/App.tsx`
  - `experiments/design-workflow-dashboard/variants/baseline/src/styles.css`
  - `experiments/design-workflow-dashboard/variants/baseline/src/types.ts`
  - `experiments/design-workflow-dashboard/variants/baseline/src/fixtures.ts`
  - `experiments/design-workflow-dashboard/variants/baseline/src/components/OperationalSummary.tsx`
  - `experiments/design-workflow-dashboard/variants/baseline/src/components/FilterSurface.tsx`
  - `experiments/design-workflow-dashboard/variants/baseline/src/components/ShipmentTable.tsx`
  - `experiments/design-workflow-dashboard/variants/baseline/src/components/NotificationSurface.tsx`
  - `experiments/design-workflow-dashboard/variants/baseline/src/components/ShipmentDetail.tsx`
  - `experiments/design-workflow-dashboard/variants/baseline/src/components/DispatchEditor.tsx`
  - `experiments/design-workflow-dashboard/variants/baseline/GENERATION.md`

**Interfaces:**
- Consumes only: `inputs/baseline/`, root `package.json`, root lockfile, and installed modules from Task 2.
- Produces: a buildable Vite app under `variants/baseline/` with every behavior and hook in the sealed functional contract.
- Task 6 cherry-picks the track commit and runs independent neutral browser checks.

**Isolation:** Run Task 3 concurrently with Tasks 4 and 5. Spawn one `worker` with `fork_turns: "none"`, model `gpt-5.6`, reasoning effort `xhigh`, and no inherited conversation. The worker is not alone in the repository; it owns only the baseline variant and must neither inspect nor revert other work.

- [ ] **Step 1: Confirm clean isolated starting state**

In `../pumped-sheep-dashboard-baseline` run:

```bash
git status --short --branch
git rev-parse HEAD
test ! -e experiments/design-workflow-dashboard/variants/design-rules
test ! -e experiments/design-workflow-dashboard/variants/design-workflow
test ! -e experiments/design-workflow-dashboard/evaluation
```

Expected: clean branch `experiment/dashboard-baseline`; no sibling variants or evaluation directory; SHA equals the Task 2 sealed-input commit.

- [ ] **Step 2: Send the exact fresh-context worker assignment**

Use this orchestration prompt without adding preferences, examples, screenshots, or evaluation criteria:

```text
You own Condition A at ../pumped-sheep-dashboard-baseline/experiments/design-workflow-dashboard/variants/baseline. You are not alone in the repository; do not inspect, edit, or revert files outside that variant except reading the root package.json/package-lock.json and your sealed input directory ../pumped-sheep-dashboard-baseline/experiments/design-workflow-dashboard/inputs/baseline. Read PROMPT.md, common/product-brief.md, common/functional-contract.md, common/src/types.ts, and common/src/fixtures.ts completely. Do not read docs/woobin_plan, evaluation, launcher, git history, any design skill, any sibling variant, or any image evidence. Use no design/UI/web-production/image-generation skill. Implement the complete interactive React mockup in one turn, copying types.ts and fixtures.ts byte-for-byte. Use only root-lockfile dependencies. Run `npm run build:baseline` from the experiment root. Write GENERATION.md with condition `baseline`, the input manifest common hash, `allowed skill: none`, the build command/result, and concise implementation assumptions; do not critique or score the result. Commit only variants/baseline with message `Build baseline cold-chain dashboard`. Return the commit SHA and build status in at most 25 lines.
```

- [ ] **Step 3: Require the neutral app shell, not a shared design**

The worker must use these infrastructure contents while making all visual and interaction decisions itself.

`vite.config.ts`:

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

`tsconfig.json`:

```json
{
  "extends": "../../tsconfig.base.json",
  "include": ["src"]
}
```

`src/main.tsx`:

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

`App.tsx` parses `new URLSearchParams(window.location.search).get('demo')` into `'default' | 'loading' | 'empty' | 'error'`, creates one in-memory fixture snapshot, and owns cross-surface state. Component boundaries may exchange props, but no component may import from `common/` or `inputs/` at runtime.

- [ ] **Step 4: Build without subjective repair**

The worker runs:

```bash
cd experiments/design-workflow-dashboard
cmp common/src/types.ts variants/baseline/src/types.ts
cmp common/src/fixtures.ts variants/baseline/src/fixtures.ts
npm run build:baseline
```

Expected: both `cmp` commands and the typecheck/Vite build pass. The worker may fix compile or runtime wiring errors found by this command, but must not be shown hidden design criteria.

- [ ] **Step 5: Commit the isolated variant**

In the baseline worktree:

```bash
git add experiments/design-workflow-dashboard/variants/baseline
git commit -m "Build baseline cold-chain dashboard"
git status --short
```

Expected: clean branch with exactly one variant commit after the Task 2 base. Do not cherry-pick yet; Task 6 integrates all three together.
