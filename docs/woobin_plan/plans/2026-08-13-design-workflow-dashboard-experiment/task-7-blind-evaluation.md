# Task 7: Blind X/Y/Z Launcher, Capture Scenes, and Hidden Scorecard

**Files:**
- Create: `experiments/design-workflow-dashboard/launcher/index.html`
- Create: `experiments/design-workflow-dashboard/launcher/vite.config.ts`
- Create: `experiments/design-workflow-dashboard/launcher/tsconfig.json`
- Create: `experiments/design-workflow-dashboard/launcher/src/main.tsx`
- Create: `experiments/design-workflow-dashboard/launcher/src/App.tsx`
- Create: `experiments/design-workflow-dashboard/launcher/src/styles.css`
- Create: `experiments/design-workflow-dashboard/scripts/blind-map-lib.mjs`
- Create: `experiments/design-workflow-dashboard/scripts/create-blind-map.mjs`
- Create: `experiments/design-workflow-dashboard/scripts/reveal-map.mjs`
- Create: `experiments/design-workflow-dashboard/evaluation/blind-map.test.ts`
- Create: `experiments/design-workflow-dashboard/evaluation/blind-launcher.spec.ts`
- Create: `experiments/design-workflow-dashboard/evaluation/capture-scenes.mjs`
- Create: `experiments/design-workflow-dashboard/evaluation/collect-measurements.mjs`
- Create: `experiments/design-workflow-dashboard/evaluation/rubric.md`
- Create: `experiments/design-workflow-dashboard/evaluation/scorecard.md`
- Runtime only: `experiments/design-workflow-dashboard/evaluation/private/blind-map.json`
- Runtime only: `experiments/design-workflow-dashboard/evaluation/artifacts/**`

**Interfaces:**
- Consumes: three function-valid builds and condition directories from Task 6.
- Produces: a client that knows only X/Y/Z, a server-side private mapping, identical screenshot scenes, and a blank blind scorecard.
- Task 8 audits leak prevention and hands the launcher to the user without revealing the mapping.

- [ ] **Step 1: Write the failing mapping tests**

Create `evaluation/blind-map.test.ts` before the library:

```ts
import { describe, expect, it } from 'vitest'
import { createMapping, validateMapping } from '../scripts/blind-map-lib.mjs'

describe('blind mapping', () => {
  it('contains each condition exactly once', () => {
    const mapping = createMapping((maximum) => maximum - 1)
    expect(Object.keys(mapping.variants).sort()).toEqual(['X', 'Y', 'Z'])
    expect(Object.values(mapping.variants).sort()).toEqual(['baseline', 'design-rules', 'design-workflow'])
    expect(validateMapping(mapping)).toEqual([])
  })

  it('rejects duplicates and unknown labels', () => {
    expect(validateMapping({
      schemaVersion: 1,
      variants: { X: 'baseline', Y: 'baseline', Z: 'unknown' },
    })).toEqual([
      'CONDITIONS_MUST_BE_UNIQUE',
      'UNKNOWN_CONDITION unknown',
    ])
  })
})
```

Run:

```bash
npx vitest run evaluation/blind-map.test.ts
```

Expected: FAIL because `scripts/blind-map-lib.mjs` does not exist.

- [ ] **Step 2: Implement private mapping creation and validation**

Create `scripts/blind-map-lib.mjs`:

```js
import crypto from 'node:crypto'

export const CONDITIONS = ['baseline', 'design-rules', 'design-workflow']
export const LETTERS = ['X', 'Y', 'Z']

export function createMapping(randomInt = (maximum) => crypto.randomInt(maximum)) {
  const shuffled = [...CONDITIONS]
  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1)
    ;[shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]]
  }
  return {
    schemaVersion: 1,
    variants: Object.fromEntries(LETTERS.map((letter, index) => [letter, shuffled[index]])),
  }
}

export function validateMapping(mapping) {
  const errors = []
  const values = LETTERS.map((letter) => mapping?.variants?.[letter])
  if (new Set(values).size !== CONDITIONS.length) errors.push('CONDITIONS_MUST_BE_UNIQUE')
  for (const value of values) {
    if (!CONDITIONS.includes(value)) errors.push(`UNKNOWN_CONDITION ${value}`)
  }
  return errors.sort()
}
```

Create `scripts/create-blind-map.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createMapping, validateMapping } from './blind-map-lib.mjs'

const experimentRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const privateDir = path.join(experimentRoot, 'evaluation/private')
const output = path.join(privateDir, 'blind-map.json')
if (fs.existsSync(output)) {
  console.error(`BLIND_MAP_EXISTS path=${output}`)
  process.exit(1)
}
const mapping = createMapping()
const errors = validateMapping(mapping)
if (errors.length) throw new Error(errors.join('\n'))
fs.mkdirSync(privateDir, { recursive: true })
fs.writeFileSync(output, `${JSON.stringify(mapping, null, 2)}\n`, { mode: 0o600 })
fs.chmodSync(output, 0o600)
console.log(`BLIND_MAP_READY path=${output}`)
```

Create `scripts/reveal-map.mjs`, but do not run it:

```js
#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { LETTERS, validateMapping } from './blind-map-lib.mjs'

const experimentRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const revealedAtPath = path.join(experimentRoot, 'evaluation/private/revealed-at.txt')
const mapping = JSON.parse(fs.readFileSync(path.join(experimentRoot, 'evaluation/private/blind-map.json'), 'utf8'))
const errors = validateMapping(mapping)
if (errors.length) {
  for (const error of errors) console.error(error)
  process.exit(1)
}
fs.writeFileSync(
  revealedAtPath,
  `${new Date().toISOString()}\n`,
  { mode: 0o600 },
)
for (const letter of LETTERS) console.log(`${letter}=${mapping.variants[letter]}`)
```

Run only the unit test:

```bash
npx vitest run evaluation/blind-map.test.ts
```

Expected: two tests pass.

- [ ] **Step 3: Build a condition-free launcher**

Create `launcher/vite.config.ts`:

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

Create `launcher/tsconfig.json`:

```json
{
  "extends": "../tsconfig.base.json",
  "include": ["src"]
}
```

Create `launcher/src/main.tsx` with the same `StrictMode`/`createRoot` bootstrap as the variants. Create `launcher/src/App.tsx` exactly as a neutral gateway:

```tsx
const variants = ['X', 'Y', 'Z'] as const

export function App() {
  return (
    <main className="launcher">
      <header>
        <p className="eyebrow">블라인드 비교</p>
        <h1>콜드체인 대시보드 3개 안</h1>
        <p>각 안을 같은 브라우저 크기에서 조작한 뒤 평가표를 작성해 주세요. 조건은 점수 확정 후 공개합니다.</p>
      </header>
      <section className="variant-list" aria-label="비교할 대시보드">
        {variants.map((variant) => (
          <a key={variant} className="variant-card" href={`/${variant.toLowerCase()}/`} target="_blank" rel="noreferrer">
            <span>Variant</span>
            <strong>{variant}</strong>
            <span>새 탭에서 열기</span>
          </a>
        ))}
      </section>
      <p className="notice">개발자 도구나 저장소 파일에서 조건을 추측하지 말고 화면과 상호작용만 평가해 주세요.</p>
    </main>
  )
}
```

Style only the launcher itself in `launcher/src/styles.css`; use no condition name, color code, ranking, thumbnail, or preview that could prime a preference. `launcher/index.html` title is `블라인드 대시보드 비교`.

Run:

```bash
npm run build:launcher
rg -n "baseline|design-rules|design-workflow|Condition [ABC]" launcher/dist
```

Expected: launcher builds and `rg` returns no matches.

- [ ] **Step 4: Create the private map once and verify file isolation**

Run:

```bash
npm run blind-map
stat -f '%Lp %N' evaluation/private/blind-map.json
git check-ignore evaluation/private/blind-map.json
```

Expected: mode `600`; `git check-ignore` prints the path. Do not print or open the JSON.

- [ ] **Step 5: Write blind launcher browser checks**

Create `evaluation/blind-launcher.spec.ts`:

```ts
import { expect, test } from '@playwright/test'

test('launcher exposes only X, Y, and Z', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: '콜드체인 대시보드 3개 안' })).toBeVisible()
  for (const letter of ['X', 'Y', 'Z']) {
    await expect(page.getByRole('link', { name: new RegExp(`Variant\\s*${letter}`) })).toHaveAttribute('href', `/${letter.toLowerCase()}/`)
  }
  await expect(page.locator('body')).not.toContainText(/baseline|design-rules|design-workflow|Condition [ABC]/i)
})

for (const letter of ['x', 'y', 'z']) {
  test(`blind route ${letter.toUpperCase()} serves a working variant`, async ({ page }) => {
    await page.goto(`/${letter}/`)
    await expect(page.getByTestId('app-root')).toBeVisible()
  })
}
```

Update `evaluation/playwright.config.ts` so its server command may be overridden without editing test files:

```ts
const serverMode = process.env.EXPERIMENT_SERVER_MODE ?? 'condition'
// webServer.command becomes:
// `node scripts/serve-built.mjs --mode ${serverMode} --port 4173`
```

Run:

```bash
EXPERIMENT_SERVER_MODE=blind npm run test:blind
```

Expected: unit tests, launcher leak check, and X/Y/Z route checks pass in both viewport projects.

- [ ] **Step 6: Materialize the hidden rubric only after generation**

Create `evaluation/rubric.md`:

```markdown
# Blind evaluation rubric

Do not reveal X/Y/Z mapping until the user has finalized this scorecard.

| Category | Points | What to observe |
|---|---:|---|
| Major task efficiency | 20 | Steps and discoverability for anomaly detection, filtering, selection, detail inspection, and dispatch editing |
| Information hierarchy | 15 | Speed and truthfulness of distinguishing critical, warning, normal, and unavailable states |
| Content-derived dimensions | 20 | Whether name, temperature, identifier, address, and notes controls/columns fit the character of their values |
| UX conventions | 20 | Overlay exit, long-candidate navigation, search scope/location if present, save/cancel, and feedback behavior |
| Overflow robustness | 10 | Long lists, table data, scrolling, wrapping, clipping, overlap, and layout shift |
| Accessibility | 10 | Keyboard reachability, focus, labels, target size, contrast, and non-color state cues |
| Visual finish | 5 | Consistency, restraint, operational fit, and overall coherence |

For each variant record the numeric total, three strongest qualities, three most disruptive problems, and any blocker. Also record time and input actions to select driver `DRV-096`, pointer methods that close the notification surface, rendered widths for driver name/phone/tracking/min/max/notes fields, and failures in filter/select/save/cancel/focus-return paths at 1440×900 and 1024×768.
```

Create `evaluation/scorecard.md` with blank X/Y/Z tables. Use `_not scored_` rather than numeric defaults so the file cannot imply a ranking:

```markdown
# Blind scorecard

Status: mapping unrevealed

| Variant | Task /20 | Hierarchy /15 | Dimensions /20 | UX /20 | Overflow /10 | A11y /10 | Finish /5 | Total /100 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| X | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ |
| Y | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ |
| Z | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ | _not scored_ |

## Variant X
- Strongest qualities:
- Most disruptive problems:
- Blockers:
- Quantitative observations:

## Variant Y
- Strongest qualities:
- Most disruptive problems:
- Blockers:
- Quantitative observations:

## Variant Z
- Strongest qualities:
- Most disruptive problems:
- Blockers:
- Quantitative observations:

## Preference before reveal
- Preferred variant:
- Reason:
- Is the difference conclusive enough to stop after round one?:
```

- [ ] **Step 7: Implement identical blind scene capture**

Create `evaluation/capture-scenes.mjs`. It must spawn `node scripts/serve-built.mjs --mode blind --port 4173`, wait for `EXPERIMENT_SERVER`, launch Chromium, and save files only under `evaluation/artifacts/x/`, `evaluation/artifacts/y/`, and `evaluation/artifacts/z/`.

Use this exact scene table:

```js
const scenes = [
  ['01-initial-1440', { width: 1440, height: 900 }, async () => {}],
  ['02-filters-open', { width: 1440, height: 900 }, async (page) => page.getByTestId('filter-trigger').click()],
  ['03-driver-options', { width: 1440, height: 900 }, async (page) => {
    await page.getByTestId('shipment-open-SHP-001').click()
    await page.getByTestId('edit-dispatch').click()
    await page.getByTestId('driver-control').click()
  }],
  ['04-notifications-open', { width: 1440, height: 900 }, async (page) => page.getByTestId('notifications-trigger').click()],
  ['05-bulk-action', { width: 1440, height: 900 }, async (page) => {
    await page.getByTestId('row-select-SHP-001').click()
    await page.getByTestId('bulk-action-trigger').click()
  }],
  ['06-detail-history', { width: 1440, height: 900 }, async (page) => {
    await page.getByTestId('shipment-open-SHP-001').click()
    await page.getByTestId('shipment-detail').evaluate((element) => { element.scrollTop = element.scrollHeight / 2 })
  }],
  ['07-dispatch-editor', { width: 1440, height: 900 }, async (page) => {
    await page.getByTestId('shipment-open-SHP-001').click()
    await page.getByTestId('edit-dispatch').click()
  }],
  ['08-empty', { width: 1440, height: 900 }, async () => {}, 'empty'],
  ['09-error', { width: 1440, height: 900 }, async () => {}, 'error'],
  ['10-initial-1024', { width: 1024, height: 768 }, async () => {}],
  ['11-notifications-1024', { width: 1024, height: 768 }, async (page) => page.getByTestId('notifications-trigger').click()],
]
```

Wrap the table in this exact control flow; the scene table above is assigned to `scenes` unchanged:

```js
import fs from 'node:fs'
import path from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { chromium } from '@playwright/test'

const experimentRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const server = spawn(process.execPath, ['scripts/serve-built.mjs', '--mode', 'blind', '--port', '4173'], {
  cwd: experimentRoot,
  stdio: ['ignore', 'pipe', 'inherit'],
})

await new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error('capture server timeout')), 10_000)
  server.once('error', reject)
  server.stdout.on('data', (chunk) => {
    if (String(chunk).includes('EXPERIMENT_SERVER')) {
      clearTimeout(timer)
      resolve()
    }
  })
})

const browser = await chromium.launch()
try {
  for (const letter of ['x', 'y', 'z']) {
    const outputDir = path.join(experimentRoot, `evaluation/artifacts/${letter}`)
    fs.mkdirSync(outputDir, { recursive: true })
    for (const [name, viewport, action, demo = 'default'] of scenes) {
      const page = await browser.newPage({ viewport })
      await page.goto(`http://127.0.0.1:4173/${letter}/?demo=${demo}`)
      await page.getByTestId(demo === 'default' ? 'app-root' : `${demo}-state`).waitFor()
      await action(page)
      await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
      await page.screenshot({ path: path.join(outputDir, `${name}.png`), fullPage: false })
      await page.close()
    }
  }
} finally {
  await browser.close()
  server.kill('SIGTERM')
}
```

Do not use condition names in paths or screenshot metadata.

Run:

```bash
npm run capture
find evaluation/artifacts -type f -name '*.png' | sort
```

Expected: 33 PNG files, eleven under each X/Y/Z directory.

- [ ] **Step 8: Collect blind quantitative layout measurements**

Create `evaluation/collect-measurements.mjs`:

```js
import fs from 'node:fs'
import path from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { chromium } from '@playwright/test'

const experimentRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const fieldHooks = [
  'dispatch-driver-name',
  'dispatch-phone',
  'dispatch-tracking',
  'dispatch-min-temperature',
  'dispatch-max-temperature',
  'dispatch-notes',
]
const viewports = {
  '1440x900': { width: 1440, height: 900 },
  '1024x768': { width: 1024, height: 768 },
}
const output = { schemaVersion: 1, variants: {} }
const server = spawn(process.execPath, ['scripts/serve-built.mjs', '--mode', 'blind', '--port', '4173'], {
  cwd: experimentRoot,
  stdio: ['ignore', 'pipe', 'inherit'],
})

await new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error('measurement server timeout')), 10_000)
  server.once('error', reject)
  server.stdout.on('data', (chunk) => {
    if (String(chunk).includes('EXPERIMENT_SERVER')) {
      clearTimeout(timer)
      resolve()
    }
  })
})

const browser = await chromium.launch()
try {
  for (const letter of ['X', 'Y', 'Z']) {
    output.variants[letter] = {}
    for (const [viewportName, viewport] of Object.entries(viewports)) {
      const page = await browser.newPage({ viewport })
      await page.goto(`http://127.0.0.1:4173/${letter.toLowerCase()}/?demo=default`)
      await page.getByTestId('shipment-open-SHP-001').click()
      await page.getByTestId('edit-dispatch').click()

      const fields = Object.fromEntries(await Promise.all(fieldHooks.map(async (hook) => {
        const box = await page.getByTestId(hook).boundingBox()
        return [hook, box ? { width: box.width, height: box.height } : null]
      })))

      const documentOverflow = await page.evaluate(() => ({
        clientWidth: document.documentElement.clientWidth,
        scrollWidth: document.documentElement.scrollWidth,
        clientHeight: document.documentElement.clientHeight,
        scrollHeight: document.documentElement.scrollHeight,
        horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
      }))
      output.variants[letter][viewportName] = { fields, documentOverflow }
      await page.close()
    }
  }
  const artifacts = path.join(experimentRoot, 'evaluation/artifacts')
  fs.mkdirSync(artifacts, { recursive: true })
  fs.writeFileSync(path.join(artifacts, 'measurements.json'), `${JSON.stringify(output, null, 2)}\n`)
} finally {
  await browser.close()
  server.kill('SIGTERM')
}
```

Do not calculate a score or threshold; the scorecard interprets the blind values.

Run:

```bash
npm run measure
test -s evaluation/artifacts/measurements.json
```

Expected: the file contains X/Y/Z only, two viewport keys per letter, and six non-null field boxes per viewport.

- [ ] **Step 9: Commit only public blind-evaluation code**

Confirm private material is absent from git status:

```bash
git status --short
git check-ignore evaluation/private/blind-map.json evaluation/artifacts/x/01-initial-1440.png
```

Commit:

```bash
git add launcher scripts/blind-map-lib.mjs scripts/create-blind-map.mjs scripts/reveal-map.mjs evaluation/blind-map.test.ts evaluation/blind-launcher.spec.ts evaluation/capture-scenes.mjs evaluation/collect-measurements.mjs evaluation/rubric.md evaluation/scorecard.md evaluation/playwright.config.ts
git commit -m "Add blind dashboard comparison launcher"
```

Do not run `npm run reveal` and do not paste the map into commit messages, logs, or user-facing output.
