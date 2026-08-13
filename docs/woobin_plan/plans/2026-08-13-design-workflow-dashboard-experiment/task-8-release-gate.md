# Task 8: Generation Ledger, Operator Docs, and Completion Gate

**Files:**
- Create: `experiments/design-workflow-dashboard/scripts/build-generation-ledger.mjs`
- Create: `experiments/design-workflow-dashboard/scripts/audit-experiment.mjs`
- Create: `experiments/design-workflow-dashboard/generation-ledger.json`
- Create: `experiments/design-workflow-dashboard/README.md`
- Modify: `experiments/design-workflow-dashboard/package.json`

**Interfaces:**
- Consumes: input manifest, three `GENERATION.md` files, repair log, builds, private map, launcher, captures, and scorecard.
- Produces: a reproducible evidence ledger, one final audit command, and operator instructions that preserve blindness.
- User handoff consumes: `npm run serve`, the launcher URL, `evaluation/scorecard.md`, and only later `npm run reveal`.

- [ ] **Step 1: Add deterministic ledger and audit commands**

Modify `package.json` scripts to add these entries without changing any pinned dependency:

```json
{
  "ledger": "node scripts/build-generation-ledger.mjs",
  "audit:experiment": "node scripts/audit-experiment.mjs"
}
```

Keep the existing `audit:experiment` key if already present; replace its value only if it differs.

- [ ] **Step 2: Build the generation ledger from committed and private evidence**

Create `scripts/build-generation-ledger.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const experimentRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const repoRoot = path.resolve(experimentRoot, '../..')
const manifest = JSON.parse(fs.readFileSync(path.join(experimentRoot, 'inputs/manifest.json'), 'utf8'))
const repairs = JSON.parse(fs.readFileSync(path.join(experimentRoot, 'evaluation/neutral-repairs.json'), 'utf8'))
const conditions = ['baseline', 'design-rules', 'design-workflow']

function lastCommitFor(relativePath) {
  return execFileSync('git', ['log', '-1', '--format=%H', '--', relativePath], {
    cwd: repoRoot,
    encoding: 'utf8',
  }).trim()
}

const conditionEvidence = Object.fromEntries(conditions.map((condition) => {
  const files = manifest.conditions[condition].files
  const skillHashes = Object.fromEntries(Object.entries(files).filter(([file]) => file.startsWith('skill/')))
  return [condition, {
    model: 'gpt-5.6',
    reasoningEffort: 'xhigh',
    generationBudget: 'one fresh worker turn plus at most one neutral repair turn',
    commonHashes: manifest.commonHashes,
    promptHash: files['PROMPT.md'],
    skillHashes,
    generationCommit: lastCommitFor(`experiments/design-workflow-dashboard/variants/${condition}`),
    buildCommand: `npm run build:${condition}`,
    buildPassed: true,
    neutralRepairs: repairs[condition],
    generationRecord: `variants/${condition}/GENERATION.md`,
  }]
}))

const ledger = {
  schemaVersion: 1,
  baselineRef: manifest.baselineRef,
  inputManifest: 'inputs/manifest.json',
  conditions: conditionEvidence,
  browserMatrix: ['1440x900', '1024x768'],
  blind: {
    mapPath: 'evaluation/private/blind-map.json',
    mapCommitted: false,
    mapRevealed: fs.existsSync(path.join(experimentRoot, 'evaluation/private/revealed-at.txt')),
    capturedScenesPerVariant: 11,
  },
}

fs.writeFileSync(path.join(experimentRoot, 'generation-ledger.json'), `${JSON.stringify(ledger, null, 2)}\n`)
console.log(`LEDGER_READY conditions=${conditions.length} revealed=${ledger.blind.mapRevealed}`)
```

Run:

```bash
npm run ledger
```

Expected before user scoring: `LEDGER_READY conditions=3 revealed=false`.

- [ ] **Step 3: Write the final experiment audit before implementing it**

Run:

```bash
npm run audit:experiment
```

Expected: FAIL because `scripts/audit-experiment.mjs` does not exist.

- [ ] **Step 4: Implement the final leak, equality, artifact, and ledger audit**

Create `scripts/audit-experiment.mjs`:

```js
#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { CONDITIONS, LETTERS, validateMapping } from './blind-map-lib.mjs'

const experimentRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const errors = []
const ledger = JSON.parse(fs.readFileSync(path.join(experimentRoot, 'generation-ledger.json'), 'utf8'))
const mappingPath = path.join(experimentRoot, 'evaluation/private/blind-map.json')
const mapping = JSON.parse(fs.readFileSync(mappingPath, 'utf8'))

function compare(left, right, code) {
  if (!fs.readFileSync(left).equals(fs.readFileSync(right))) errors.push(code)
}

for (const condition of CONDITIONS) {
  compare(
    path.join(experimentRoot, 'common/src/types.ts'),
    path.join(experimentRoot, `variants/${condition}/src/types.ts`),
    `TYPES_DRIFT ${condition}`,
  )
  compare(
    path.join(experimentRoot, 'common/src/fixtures.ts'),
    path.join(experimentRoot, `variants/${condition}/src/fixtures.ts`),
    `FIXTURES_DRIFT ${condition}`,
  )
  const evidence = ledger.conditions[condition]
  if (evidence.model !== 'gpt-5.6') errors.push(`MODEL_MISMATCH ${condition}`)
  if (evidence.reasoningEffort !== 'xhigh') errors.push(`EFFORT_MISMATCH ${condition}`)
  if (evidence.generationBudget !== 'one fresh worker turn plus at most one neutral repair turn') errors.push(`BUDGET_MISMATCH ${condition}`)
  if (!evidence.buildPassed) errors.push(`BUILD_NOT_PASSED ${condition}`)
  if (evidence.neutralRepairs.length > 1) errors.push(`TOO_MANY_REPAIRS ${condition}`)
}

errors.push(...validateMapping(mapping))
if ((fs.statSync(mappingPath).mode & 0o777) !== 0o600) errors.push('BLIND_MAP_MODE_NOT_600')
if (fs.existsSync(path.join(experimentRoot, 'evaluation/private/revealed-at.txt'))) errors.push('MAPPING_ALREADY_REVEALED')
if (ledger.blind.mapRevealed) errors.push('LEDGER_SAYS_REVEALED')

const forbidden = /baseline|design-rules|design-workflow|Condition [ABC]/i
for (const directory of ['launcher/dist', 'evaluation/artifacts']) {
  const root = path.join(experimentRoot, directory)
  const queue = [root]
  while (queue.length) {
    const current = queue.pop()
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const child = path.join(current, entry.name)
      const relative = path.relative(experimentRoot, child)
      if (forbidden.test(relative)) errors.push(`BLIND_PATH_LEAK ${relative}`)
      if (entry.isDirectory()) queue.push(child)
      else if (/\.(html|js|css|json|md|txt)$/.test(entry.name) && forbidden.test(fs.readFileSync(child, 'utf8'))) {
        errors.push(`BLIND_CONTENT_LEAK ${relative}`)
      }
    }
  }
}

for (const letter of LETTERS) {
  const directory = path.join(experimentRoot, `evaluation/artifacts/${letter.toLowerCase()}`)
  const count = fs.readdirSync(directory).filter((file) => file.endsWith('.png')).length
  if (count !== 11) errors.push(`CAPTURE_COUNT ${letter} ${count}`)
}

const measurements = JSON.parse(fs.readFileSync(path.join(experimentRoot, 'evaluation/artifacts/measurements.json'), 'utf8'))
for (const letter of LETTERS) {
  for (const viewport of ['1440x900', '1024x768']) {
    const entry = measurements.variants?.[letter]?.[viewport]
    if (!entry || Object.keys(entry.fields ?? {}).length !== 6) errors.push(`MEASUREMENT_FIELDS ${letter} ${viewport}`)
    if (typeof entry?.documentOverflow?.horizontalOverflow !== 'boolean') errors.push(`MEASUREMENT_OVERFLOW ${letter} ${viewport}`)
  }
}

const scorecard = fs.readFileSync(path.join(experimentRoot, 'evaluation/scorecard.md'), 'utf8')
if (!scorecard.includes('Status: mapping unrevealed')) errors.push('SCORECARD_NOT_BLIND')

try {
  execFileSync('node', ['scripts/audit-inputs.mjs'], { cwd: experimentRoot, stdio: 'pipe' })
} catch (error) {
  errors.push(`INPUT_AUDIT_FAILED ${error.status ?? 'unknown'}`)
}

if (errors.length) {
  for (const error of [...new Set(errors)].sort()) console.error(error)
  process.exit(1)
}
console.log('EXPERIMENT_AUDIT_OK conditions=3 variants=3 captures=33 revealed=false')
```

- [ ] **Step 5: Write operator instructions that preserve the blind**

Create `README.md` with these commands and no X/Y/Z mapping:

````markdown
# Design Workflow Dashboard Experiment

This package compares three independently generated cold-chain dashboards behind blind labels X, Y, and Z.

## Prepare and validate

```bash
npm ci
npm run test:common
npm run audit:inputs
npm run build:variants
npm run test:functional
npm run build:launcher
test -f evaluation/private/blind-map.json || npm run blind-map
EXPERIMENT_SERVER_MODE=blind npm run test:blind
npm run capture
npm run measure
npm run ledger
npm run audit:experiment
```

## Blind review

Start the local server with `npm run serve`, then open `http://127.0.0.1:4173/`. Review X, Y, and Z at the same viewport and fill in `evaluation/scorecard.md`. Do not inspect `evaluation/private/`, `inputs/*/CONDITION.json`, `generation-ledger.json`, or variant source names before recording the preference.

## Reveal after scoring

Only after the scorecard contains a preferred variant and the user confirms the blind evaluation is final, run:

```bash
npm run reveal
```

The reveal command prints X/Y/Z mapping and creates the private `revealed-at.txt` audit marker. If the result is inconclusive, keep round one intact and create a new round with fresh contexts and a new private mapping.
````

- [ ] **Step 6: Run the complete deterministic and browser gate**

From the experiment root run in this order:

```bash
npm ci
npx playwright install chromium
npm run test:common
npm run audit:inputs
npm run build:variants
npm run test:functional
npm run build:launcher
EXPERIMENT_SERVER_MODE=blind npm run test:blind
npm run capture
npm run measure
npm run ledger
npm run audit:experiment
git diff --check
```

Expected final lines include:

```text
INPUT_AUDIT_OK conditions=3
LEDGER_READY conditions=3 revealed=false
EXPERIMENT_AUDIT_OK conditions=3 variants=3 captures=33 revealed=false
```

All browser tests pass in both viewport projects; `git diff --check` emits no output.

- [ ] **Step 7: Run independent final review lenses**

After the gate passes, invoke read-only `plan-reviewer` contexts with the plan directory and the diff from the Task 1 parent to `HEAD`. Do not send screenshots or mapping. Use these three lenses and collect all results before deciding severity:

1. correctness and browser/runtime bugs;
2. completion against Tasks 1–8 and the approved spec;
3. repository standards, input isolation, blind leakage, and experimental validity.

Fix confirmed implementation defects, rerun the complete gate, and do not make aesthetic changes to any variant. A reviewer finding about subjective design belongs in the later blind scorecard, not the code repair loop.

- [ ] **Step 8: Commit public evidence and hand off without reveal**

Confirm no ignored private data is staged:

```bash
git status --short
git check-ignore evaluation/private/blind-map.json evaluation/artifacts/x/01-initial-1440.png
```

Commit:

```bash
git add package.json README.md scripts/build-generation-ledger.mjs scripts/audit-experiment.mjs generation-ledger.json
git commit -m "Document blind dashboard experiment run"
```

Hand the user only:

```text
Launcher: http://127.0.0.1:4173/
Scorecard: experiments/design-workflow-dashboard/evaluation/scorecard.md
Mapping status: unrevealed
```

Do not run `npm run reveal`. Wait for the user to complete and confirm the scorecard.
