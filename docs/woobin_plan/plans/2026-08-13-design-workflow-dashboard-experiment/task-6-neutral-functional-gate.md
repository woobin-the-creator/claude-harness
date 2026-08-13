# Task 6: Variant Integration and Neutral Browser Function Gate

**Files:**
- Integrate: `experiments/design-workflow-dashboard/variants/baseline/**`
- Integrate: `experiments/design-workflow-dashboard/variants/design-rules/**`
- Integrate: `experiments/design-workflow-dashboard/variants/design-workflow/**`
- Create: `experiments/design-workflow-dashboard/scripts/serve-built.mjs`
- Create: `experiments/design-workflow-dashboard/evaluation/playwright.config.ts`
- Create: `experiments/design-workflow-dashboard/evaluation/functional.spec.ts`
- Create: `experiments/design-workflow-dashboard/evaluation/neutral-repairs.json`

**Interfaces:**
- Consumes: the three isolated track commits and common hook/data contracts.
- Produces: one integration branch containing all variants, a static condition server, neutral browser results at two viewports, and an auditable zero-or-one repair count per condition.
- Task 7 extends `serve-built.mjs` in blind mode and relies on all function gates passing.

- [ ] **Step 1: Integrate the three isolated commits without opening their UIs**

From the integration worktree run:

```bash
git log -1 --oneline experiment/dashboard-baseline
git log -1 --oneline experiment/dashboard-design-rules
git log -1 --oneline experiment/dashboard-design-workflow
git cherry-pick experiment/dashboard-baseline
git cherry-pick experiment/dashboard-design-rules
git cherry-pick experiment/dashboard-design-workflow
git status --short
```

Expected: three clean cherry-picks with disjoint variant paths. If a cherry-pick conflicts outside its assigned variant directory, abort that cherry-pick and reject the track as an isolation violation rather than resolving it by hand.

- [ ] **Step 2: Run byte-copy, dependency, and build gates before browser tests**

Run from the experiment root:

```bash
cmp common/src/types.ts variants/baseline/src/types.ts
cmp common/src/fixtures.ts variants/baseline/src/fixtures.ts
cmp common/src/types.ts variants/design-rules/src/types.ts
cmp common/src/fixtures.ts variants/design-rules/src/fixtures.ts
cmp common/src/types.ts variants/design-workflow/src/types.ts
cmp common/src/fixtures.ts variants/design-workflow/src/fixtures.ts
npm run audit:inputs
npm run build:variants
```

Expected: all `cmp` commands pass, input audit prints `INPUT_AUDIT_OK conditions=3`, and all three builds exit `0`.

- [ ] **Step 3: Write a static server that can mount independent Vite builds**

Create `scripts/serve-built.mjs` with condition mode now and blind mode support for Task 7:

```js
#!/usr/bin/env node
import fs from 'node:fs'
import http from 'node:http'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const experimentRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, all) => {
  if (value.startsWith('--')) pairs.push([value.slice(2), all[index + 1]])
  return pairs
}, []))
const mode = args.mode ?? 'condition'
const port = Number(args.port ?? 4173)
const conditionDirectories = {
  baseline: path.join(experimentRoot, 'variants/baseline/dist'),
  'design-rules': path.join(experimentRoot, 'variants/design-rules/dist'),
  'design-workflow': path.join(experimentRoot, 'variants/design-workflow/dist'),
}
const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.woff2': 'font/woff2',
}

function blindRoutes() {
  const privateMapPath = path.join(experimentRoot, 'evaluation/private/blind-map.json')
  const mapping = JSON.parse(fs.readFileSync(privateMapPath, 'utf8'))
  return Object.fromEntries(Object.entries(mapping.variants).map(([letter, condition]) => [letter.toLowerCase(), conditionDirectories[condition]]))
}

const variantRoutes = mode === 'blind'
  ? blindRoutes()
  : conditionDirectories
const launcherRoot = path.join(experimentRoot, 'launcher/dist')

function safeFile(root, relativePath) {
  const normalized = path.normalize(relativePath).replace(/^(\.\.(\/|\\|$))+/, '')
  const candidate = path.resolve(root, normalized)
  return candidate === root || candidate.startsWith(`${root}${path.sep}`) ? candidate : null
}

function sendFile(response, file) {
  response.writeHead(200, { 'content-type': mime[path.extname(file)] ?? 'application/octet-stream' })
  fs.createReadStream(file).pipe(response)
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url ?? '/', `http://${request.headers.host ?? '127.0.0.1'}`)
  const segments = url.pathname.split('/').filter(Boolean)
  const route = segments[0]
  const root = route && variantRoutes[route]
  if (root) {
    const relative = segments.slice(1).join('/') || 'index.html'
    const candidate = safeFile(root, relative)
    if (candidate && fs.existsSync(candidate) && fs.statSync(candidate).isFile()) return sendFile(response, candidate)
    return sendFile(response, path.join(root, 'index.html'))
  }
  if (mode === 'blind') {
    const relative = segments.join('/') || 'index.html'
    const candidate = safeFile(launcherRoot, relative)
    if (candidate && fs.existsSync(candidate) && fs.statSync(candidate).isFile()) return sendFile(response, candidate)
  }
  response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' })
  response.end('Not found')
})

server.listen(port, '127.0.0.1', () => console.log(`EXPERIMENT_SERVER mode=${mode} port=${port}`))
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => process.exit(0)))
```

- [ ] **Step 4: Configure the neutral browser matrix**

Create `evaluation/playwright.config.ts`:

```ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: '.',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['json', { outputFile: 'evaluation/private/playwright-results.json' }]],
  use: {
    baseURL: 'http://127.0.0.1:4173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: 'node scripts/serve-built.mjs --mode condition --port 4173',
    port: 4173,
    reuseExistingServer: false,
  },
  projects: [
    { name: 'desktop-1440', use: { viewport: { width: 1440, height: 900 } } },
    { name: 'compact-1024', use: { viewport: { width: 1024, height: 768 } } },
  ],
})
```

- [ ] **Step 5: Write the failing neutral function suite**

Create `evaluation/functional.spec.ts`:

```ts
import { expect, test, type Locator, type Page } from '@playwright/test'

const variants = ['baseline', 'design-rules', 'design-workflow'] as const

async function choose(page: Page, controlId: string, optionId: string, value: string) {
  const control = page.getByTestId(controlId)
  const tag = await control.evaluate((element) => element.tagName)
  if (tag === 'SELECT') {
    await control.selectOption(value)
  } else {
    await control.click()
    const option = page.getByTestId(optionId)
    if (!(await option.isVisible())) {
      const surface = controlId === 'driver-control' ? page.getByTestId('driver-options') : page.getByTestId('filters-surface')
      await surface.evaluate((element) => { element.scrollTop = element.scrollHeight })
    }
    await option.scrollIntoViewIfNeeded()
    await option.click()
  }
}

async function numericText(locator: Locator): Promise<number> {
  const text = (await locator.textContent()) ?? ''
  const match = text.replaceAll(',', '').match(/\d+/)
  if (!match) throw new Error(`No numeric value in: ${text}`)
  return Number(match[0])
}

for (const variant of variants) {
  test.describe(variant, () => {
    test('renders default and reproducible demo states', async ({ page }) => {
      await page.goto(`/${variant}/?demo=default`)
      await expect(page.getByTestId('app-root')).toBeVisible()
      await page.goto(`/${variant}/?demo=loading`)
      await expect(page.getByTestId('loading-state')).toBeVisible()
      await page.goto(`/${variant}/?demo=empty`)
      await expect(page.getByTestId('empty-state')).toBeVisible()
      await page.goto(`/${variant}/?demo=error`)
      await expect(page.getByTestId('error-state')).toBeVisible()
    })

    test('filters and sorts shipment data', async ({ page }) => {
      await page.goto(`/${variant}/`)
      const before = await numericText(page.getByTestId('results-count'))
      expect(before).toBe(64)
      await page.getByTestId('filter-trigger').click()
      await expect(page.getByTestId('filters-surface')).toBeVisible()
      await expect(page.getByTestId('filter-date')).toBeVisible()
      await expect(page.getByTestId('filter-temperature')).toBeVisible()
      await expect(page.getByTestId('filter-driver')).toBeVisible()
      await expect(page.getByTestId('filter-hub')).toBeVisible()
      await choose(page, 'filter-status', 'filter-status-option-temperature-excursion', 'temperature-excursion')
      await page.getByTestId('filter-apply').click()
      const after = await numericText(page.getByTestId('results-count'))
      expect(after).toBeGreaterThan(0)
      expect(after).toBeLessThan(64)
      await page.getByTestId('sort-temperature').click()
      await expect(page.getByTestId('app-root')).toBeVisible()
    })

    test('selects a shipment and applies a bulk status action', async ({ page }) => {
      await page.goto(`/${variant}/`)
      await page.getByTestId('select-all-visible').click()
      await expect(page.getByTestId('row-select-SHP-001')).toBeChecked()
      await page.getByTestId('select-all-visible').click()
      await page.getByTestId('row-select-SHP-001').click()
      await page.getByTestId('bulk-action-trigger').click()
      await page.getByTestId('bulk-resolve').click()
      await expect(page.getByTestId('shipment-status-SHP-001')).toContainText(/완료|resolved/i)
    })

    test('changes notification read state in memory', async ({ page }) => {
      await page.goto(`/${variant}/`)
      await page.getByTestId('notifications-trigger').click()
      await expect(page.getByTestId('notifications-surface')).toBeVisible()
      await page.getByTestId('notification-ALT-030').scrollIntoViewIfNeeded()
      const state = page.getByTestId('notification-state-ALT-030')
      const before = await state.getAttribute('data-state')
      await page.getByTestId('notification-toggle-read-ALT-030').click()
      await expect(state).not.toHaveAttribute('data-state', before ?? '')
      const resolution = page.getByTestId('notification-resolution-ALT-030')
      const resolutionBefore = await resolution.getAttribute('data-state')
      await page.getByTestId('notification-toggle-resolution-ALT-030').click()
      await expect(resolution).not.toHaveAttribute('data-state', resolutionBefore ?? '')
    })

    test('opens detail and saves a driver selected from all candidates', async ({ page }) => {
      await page.goto(`/${variant}/`)
      await page.getByTestId('shipment-open-SHP-001').click()
      await expect(page.getByTestId('shipment-detail')).toBeVisible()
      await page.getByTestId('edit-dispatch').click()
      await choose(page, 'driver-control', 'driver-option-DRV-096', 'DRV-096')
      await page.getByTestId('save-dispatch').click()
      await expect(page.getByTestId('save-success')).toBeVisible()
      await expect(page.getByTestId('dispatch-driver')).toContainText('황보하늘')
    })

    test('reports invalid temperature range before saving', async ({ page }) => {
      await page.goto(`/${variant}/`)
      await page.getByTestId('shipment-open-SHP-001').click()
      await page.getByTestId('edit-dispatch').click()
      for (const field of ['dispatch-driver-name', 'dispatch-phone', 'dispatch-tracking', 'dispatch-min-temperature', 'dispatch-max-temperature', 'dispatch-notes']) {
        await expect(page.getByTestId(field)).toBeVisible()
      }
      await page.getByTestId('dispatch-min-temperature').fill('10')
      await page.getByTestId('dispatch-max-temperature').fill('5')
      await page.getByTestId('save-dispatch').click()
      await expect(page.getByTestId('validation-error')).toBeVisible()
    })

    test('cancels dispatch editing without replacing saved state', async ({ page }) => {
      await page.goto(`/${variant}/`)
      await page.getByTestId('shipment-open-SHP-001').click()
      const before = await page.getByTestId('dispatch-driver').textContent()
      await page.getByTestId('edit-dispatch').click()
      await choose(page, 'driver-control', 'driver-option-DRV-096', 'DRV-096')
      await page.getByTestId('cancel-dispatch').click()
      await expect(page.getByTestId('dispatch-driver')).toHaveText(before ?? '')
    })
  })
}
```

Run:

```bash
npm run test:functional
```

Expected on the first run: either all tests pass or failures identify only a missing required behavior/hook/runtime contract. Save the JSON report; do not inspect screenshots for design quality.

- [ ] **Step 6: Apply at most one neutral repair turn per failed condition**

Initialize `evaluation/neutral-repairs.json`:

```json
{
  "schemaVersion": 1,
  "baseline": [],
  "design-rules": [],
  "design-workflow": []
}
```

For each failed condition, construct the neutral message with this exact function and send its returned text in one fresh-context follow-up to the original track worker/worktree:

```js
function neutralRepairMessage({ condition, project, testTitle, assertion, contractSentence }) {
  return `Neutral functional contract failure.
Condition: ${condition}
Command: npm run test:functional -- --project=${project} --grep "${testTitle}"
Observed: ${assertion}
Required contract: ${contractSentence}

Read only the assigned variant and sealed input package. Do not inspect other variants, evaluation rubric, screenshots, plan, or spec. Correct only the missing function/hook/build wiring, run the condition build command, append the command/result to GENERATION.md, and commit with message "Repair ${condition} functional contract". Do not redesign or evaluate the UI.`
}
```

Record condition, exact test title, error, repair commit SHA, and `attempt: 1` in `neutral-repairs.json`. Cherry-pick the repair commit. If the same condition still fails, stop and report it as an invalid sample; do not send a second repair or patch the design centrally.

- [ ] **Step 7: Re-run the complete neutral matrix and commit the gate**

Run:

```bash
npm run build:variants
npm run test:functional
git diff --check
```

Expected: all tests pass in both viewport projects, or the experiment stops with an invalid-sample report before blind evaluation.

Commit:

```bash
git add experiments/design-workflow-dashboard/scripts/serve-built.mjs experiments/design-workflow-dashboard/evaluation/playwright.config.ts experiments/design-workflow-dashboard/evaluation/functional.spec.ts experiments/design-workflow-dashboard/evaluation/neutral-repairs.json
git commit -m "Add neutral dashboard function gate"
```
