# Task 4: Condition B — Legacy `design-rules` Dashboard in a Fresh Context

**Files:**
- Create only under worktree `../pumped-sheep-dashboard-design-rules`:
  - `experiments/design-workflow-dashboard/variants/design-rules/index.html`
  - `experiments/design-workflow-dashboard/variants/design-rules/vite.config.ts`
  - `experiments/design-workflow-dashboard/variants/design-rules/tsconfig.json`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/main.tsx`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/App.tsx`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/styles.css`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/types.ts`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/fixtures.ts`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/components/OperationalSummary.tsx`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/components/FilterSurface.tsx`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/components/ShipmentTable.tsx`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/components/NotificationSurface.tsx`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/components/ShipmentDetail.tsx`
  - `experiments/design-workflow-dashboard/variants/design-rules/src/components/DispatchEditor.tsx`
  - `experiments/design-workflow-dashboard/variants/design-rules/GENERATION.md`

**Interfaces:**
- Consumes only: `inputs/design-rules/`, root `package.json`, root lockfile, and installed modules from Task 2.
- Produces: a buildable Vite app under `variants/design-rules/` governed only by the snapshotted legacy skill.
- Task 6 cherry-picks the track commit and runs independent neutral browser checks.

**Isolation:** Run Task 4 concurrently with Tasks 3 and 5. Spawn one `worker` with `fork_turns: "none"`, model `gpt-5.6`, reasoning effort `xhigh`, and no inherited conversation. The worker owns only this variant and must neither inspect nor revert other work.

- [ ] **Step 1: Confirm clean isolated starting state and legacy hash**

In `../pumped-sheep-dashboard-design-rules` run:

```bash
git status --short --branch
git rev-parse HEAD
test ! -e experiments/design-workflow-dashboard/variants/baseline
test ! -e experiments/design-workflow-dashboard/variants/design-workflow
test ! -e experiments/design-workflow-dashboard/evaluation
git show 36a8fe8e54c162f7b77e52c15cc70d649674505c:woobin-harness/skills/design-rules/SKILL.md | shasum -a 256
shasum -a 256 experiments/design-workflow-dashboard/inputs/design-rules/skill/design-rules/SKILL.md
```

Expected: clean branch, same Task 2 SHA, absent sibling/evaluation directories, and equal legacy-skill hashes.

- [ ] **Step 2: Send the exact fresh-context worker assignment**

Use this prompt without adding the user's hidden dislikes or expected remedies:

```text
You own Condition B at ../pumped-sheep-dashboard-design-rules/experiments/design-workflow-dashboard/variants/design-rules. You are not alone in the repository; do not inspect, edit, or revert files outside that variant except reading the root package.json/package-lock.json and your sealed input directory ../pumped-sheep-dashboard-design-rules/experiments/design-workflow-dashboard/inputs/design-rules. Read PROMPT.md, common/product-brief.md, common/functional-contract.md, common/src/types.ts, common/src/fixtures.ts, and skill/design-rules/SKILL.md completely. Read the bundled instance-guide only if the skill directs it. Treat that snapshot as the only design skill. Do not read the repository's current woobin-harness skills, docs/woobin_plan, evaluation, launcher, git history, sibling variants, or image evidence. Do not use any other design/UI/web-production/image-generation skill. Implement the complete interactive React mockup in one turn, copying types.ts and fixtures.ts byte-for-byte. Use only root-lockfile dependencies. Run `npm run build:design-rules` from the experiment root. Write GENERATION.md with condition `design-rules`, common and legacy skill hashes, loaded skill files, build command/result, and concise implementation assumptions; do not critique or score the result. Commit only variants/design-rules with message `Build legacy-rules cold-chain dashboard`. Return the commit SHA and build status in at most 25 lines.
```

- [ ] **Step 3: Use the same neutral app shell**

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

`App.tsx` parses the four `demo` query values, initializes one in-memory fixture snapshot, and owns cross-surface state. The prescribed component files are responsibility boundaries only; the legacy skill chooses visual hierarchy, dimensions, controls, overlay behavior, and styling.

- [ ] **Step 4: Build without comparison or design feedback**

Run in the legacy worktree:

```bash
cd experiments/design-workflow-dashboard
cmp common/src/types.ts variants/design-rules/src/types.ts
cmp common/src/fixtures.ts variants/design-rules/src/fixtures.ts
npm run build:design-rules
```

Expected: copy checks, TypeScript, and Vite build pass. Do not show the worker baseline or workflow output, screenshots, scorecard, or subjective comments.

- [ ] **Step 5: Commit the isolated variant**

```bash
git add experiments/design-workflow-dashboard/variants/design-rules
git commit -m "Build legacy-rules cold-chain dashboard"
git status --short
```

Expected: clean track with one variant commit after the common sealed-input base. Task 6 performs integration.
