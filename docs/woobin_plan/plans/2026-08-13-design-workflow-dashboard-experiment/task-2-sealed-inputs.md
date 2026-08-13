# Task 2: Sealed Condition Packages and Isolation Audit

**Files:**
- Create: `experiments/design-workflow-dashboard/scripts/prepare-inputs.mjs`
- Create: `experiments/design-workflow-dashboard/scripts/audit-inputs.mjs`
- Create: `experiments/design-workflow-dashboard/inputs/manifest.json`
- Create: `experiments/design-workflow-dashboard/inputs/baseline/**`
- Create: `experiments/design-workflow-dashboard/inputs/design-rules/**`
- Create: `experiments/design-workflow-dashboard/inputs/design-workflow/**`

**Interfaces:**
- Consumes: Task 1 common files; baseline git object `36a8fe8e54c162f7b77e52c15cc70d649674505c`; current PR #9 workflow files.
- Produces: three committed, auditable input directories and `manifest.json` with SHA-256 hashes.
- Tasks 3–5 may read only their matching directory. Task 8 consumes the manifest for the generation ledger.

- [ ] **Step 1: Run the missing packager contract**

Run from the experiment root:

```bash
npm run prepare:inputs
```

Expected: FAIL with `Cannot find module .../scripts/prepare-inputs.mjs`.

- [ ] **Step 2: Implement deterministic package preparation**

Create `scripts/prepare-inputs.mjs`. Use only Node standard-library modules and `git show`; do not fetch the network.

```js
#!/usr/bin/env node
import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const experimentRoot = path.resolve(scriptDir, '..')
const repoRoot = path.resolve(experimentRoot, '../..')
const inputsRoot = path.join(experimentRoot, 'inputs')
const baselineRef = '36a8fe8e54c162f7b77e52c15cc70d649674505c'
const commonFiles = [
  'common/product-brief.md',
  'common/functional-contract.md',
  'common/src/types.ts',
  'common/src/fixtures.ts',
  'package.json',
  'package-lock.json',
  'tsconfig.base.json',
]

const conditionPrompts = {
  baseline: `# Generation condition\n\nBuild the interactive mockup described by the files under ./common. Use no design, UI, frontend-design, website-building, or image-generation skill. Do not inspect repository files outside this sealed input directory except the assigned output directory and the root dependency lockfile. Do not inspect the experiment spec, plan, evaluation files, or sibling variants. Make reasonable product decisions without asking follow-up questions. Copy common/src/types.ts and common/src/fixtures.ts unchanged into the assigned variant src directory. Implement every required behavior and data-testid hook. Use only dependencies already present in the root lockfile. Record build status and key implementation assumptions in GENERATION.md, but do not evaluate the design.\n`,
  'design-rules': `# Generation condition\n\nBuild the interactive mockup described by the files under ./common. Before implementation, read ./skill/design-rules/SKILL.md completely and follow it as the only design skill; read its bundled reference only if the skill directs you there. Do not use any other design, UI, frontend-design, website-building, or image-generation skill. Do not inspect repository files outside this sealed input directory except the assigned output directory and the root dependency lockfile. Do not inspect the experiment spec, plan, evaluation files, or sibling variants. Make reasonable product decisions without asking follow-up questions. Copy common/src/types.ts and common/src/fixtures.ts unchanged into the assigned variant src directory. Implement every required behavior and data-testid hook. Use only dependencies already present in the root lockfile. Record the selected skill path, build status, and key implementation assumptions in GENERATION.md, but do not evaluate the design.\n`,
  'design-workflow': `# Generation condition\n\nBuild the interactive mockup described by the files under ./common. Before implementation, read ./skill/design-workflow/SKILL.md completely and follow it as the only design skill, including only the route references bundled beside it. This is a disposable greenfield mockup: treat direction as a one-off candidate, do not create DESIGN.md, and do not promote a project default. Do not use any other design, UI, frontend-design, website-building, or image-generation skill. Do not inspect repository files outside this sealed input directory except the assigned output directory and the root dependency lockfile. Do not inspect the experiment spec, plan, evaluation files, or sibling variants. Make reasonable product decisions without asking follow-up questions. Copy common/src/types.ts and common/src/fixtures.ts unchanged into the assigned variant src directory. Implement every required behavior and data-testid hook. Use only dependencies already present in the root lockfile. Record the announced route, loaded references, build status, and key implementation assumptions in GENERATION.md, but do not evaluate the design.\n`,
}

const allowedSkillFiles = {
  baseline: [],
  'design-rules': [
    ['git', `${baselineRef}:woobin-harness/skills/design-rules/SKILL.md`, 'skill/design-rules/SKILL.md'],
    ['git', `${baselineRef}:woobin-harness/skills/design-rules/references/instance-guide.md`, 'skill/design-rules/references/instance-guide.md'],
  ],
  'design-workflow': [
    ['file', 'woobin-harness/skills/design-workflow/SKILL.md', 'skill/design-workflow/SKILL.md'],
    ['file', 'woobin-harness/skills/design-workflow/references/direction.md', 'skill/design-workflow/references/direction.md'],
    ['file', 'woobin-harness/skills/design-workflow/references/system-evidence.md', 'skill/design-workflow/references/system-evidence.md'],
    ['file', 'woobin-harness/skills/design-workflow/references/implementation-contracts.md', 'skill/design-workflow/references/implementation-contracts.md'],
    ['file', 'woobin-harness/skills/design-workflow/references/review.md', 'skill/design-workflow/references/review.md'],
  ],
}

function write(relativePath, content) {
  const destination = path.join(inputsRoot, relativePath)
  fs.mkdirSync(path.dirname(destination), { recursive: true })
  fs.writeFileSync(destination, content)
}

function readGitObject(spec) {
  return execFileSync('git', ['show', spec], { cwd: repoRoot, encoding: 'utf8' })
}

function sha256(content) {
  return crypto.createHash('sha256').update(content).digest('hex')
}

function listFiles(root, relative = '') {
  const directory = path.join(root, relative)
  return fs.readdirSync(directory, { withFileTypes: true })
    .flatMap((entry) => {
      const child = path.join(relative, entry.name)
      return entry.isDirectory() ? listFiles(root, child) : [child.replaceAll(path.sep, '/')]
    })
    .sort()
}

fs.rmSync(inputsRoot, { recursive: true, force: true })
fs.mkdirSync(inputsRoot, { recursive: true })

for (const condition of Object.keys(conditionPrompts)) {
  for (const commonFile of commonFiles) {
    const content = fs.readFileSync(path.join(experimentRoot, commonFile))
    write(`${condition}/common/${commonFile.replace(/^common\//, '')}`, content)
  }
  write(`${condition}/PROMPT.md`, conditionPrompts[condition])
  write(`${condition}/CONDITION.json`, `${JSON.stringify({ condition, baselineRef }, null, 2)}\n`)
  for (const [sourceType, source, destination] of allowedSkillFiles[condition]) {
    const content = sourceType === 'git'
      ? readGitObject(source)
      : fs.readFileSync(path.join(repoRoot, source))
    write(`${condition}/${destination}`, content)
  }
}

const conditions = Object.fromEntries(
  Object.keys(conditionPrompts).map((condition) => {
    const root = path.join(inputsRoot, condition)
    const files = Object.fromEntries(
      listFiles(root).map((file) => [file, sha256(fs.readFileSync(path.join(root, file)))]),
    )
    return [condition, { files }]
  }),
)

const commonHashes = Object.fromEntries(
  commonFiles.map((commonFile) => {
    const packagedPath = `common/${commonFile.replace(/^common\//, '')}`
    return [packagedPath, conditions.baseline.files[packagedPath]]
  }),
)

write('manifest.json', `${JSON.stringify({ schemaVersion: 1, baselineRef, commonHashes, conditions }, null, 2)}\n`)
console.log(`INPUTS_READY conditions=${Object.keys(conditions).length} common=${Object.keys(commonHashes).length}`)
```

- [ ] **Step 3: Generate the packages and inspect the exact inventory**

Run:

```bash
npm run prepare:inputs
find inputs -type f | sort
```

Expected inventories:

```text
baseline: PROMPT.md, CONDITION.json, seven common files, no skill directory
design-rules: the same nine files plus skill/design-rules/SKILL.md and references/instance-guide.md
design-workflow: the same nine files plus SKILL.md and exactly direction, system-evidence, implementation-contracts, review
```

The generated `inputs/manifest.json` must record the full SHA-256 map.

- [ ] **Step 4: Write the failing isolation audit**

Before creating `audit-inputs.mjs`, run:

```bash
npm run audit:inputs
```

Expected: FAIL because the audit script does not exist.

- [ ] **Step 5: Implement the input leak and equality audit**

Create `scripts/audit-inputs.mjs`:

```js
#!/usr/bin/env node
import crypto from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const experimentRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const inputsRoot = path.join(experimentRoot, 'inputs')
const manifest = JSON.parse(fs.readFileSync(path.join(inputsRoot, 'manifest.json'), 'utf8'))
const conditions = ['baseline', 'design-rules', 'design-workflow']
const expectedSkillFiles = {
  baseline: [],
  'design-rules': [
    'skill/design-rules/SKILL.md',
    'skill/design-rules/references/instance-guide.md',
  ],
  'design-workflow': [
    'skill/design-workflow/SKILL.md',
    'skill/design-workflow/references/direction.md',
    'skill/design-workflow/references/implementation-contracts.md',
    'skill/design-workflow/references/review.md',
    'skill/design-workflow/references/system-evidence.md',
  ],
}
const forbiddenCommonPhrases = [
  '바깥 클릭',
  '입력 필드 폭',
  '검색 기능이',
  '콘텐츠 기반 치수',
  'UX 관행',
  '가장 거슬리는',
  '100점',
  'X/Y/Z',
]

function hash(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')
}

function walk(root, relative = '') {
  return fs.readdirSync(path.join(root, relative), { withFileTypes: true })
    .flatMap((entry) => {
      const child = path.join(relative, entry.name)
      return entry.isDirectory() ? walk(root, child) : [child.replaceAll(path.sep, '/')]
    })
    .sort()
}

const errors = []
for (const commonPath of Object.keys(manifest.commonHashes)) {
  const hashes = conditions.map((condition) => hash(path.join(inputsRoot, condition, commonPath)))
  if (new Set(hashes).size !== 1 || hashes[0] !== manifest.commonHashes[commonPath]) {
    errors.push(`COMMON_HASH_MISMATCH ${commonPath}`)
  }
}

for (const condition of conditions) {
  const root = path.join(inputsRoot, condition)
  const actualSkillFiles = walk(root).filter((file) => file.startsWith('skill/'))
  if (JSON.stringify(actualSkillFiles) !== JSON.stringify(expectedSkillFiles[condition])) {
    errors.push(`SKILL_INVENTORY_MISMATCH ${condition}`)
  }
  const visibleInput = [
    fs.readFileSync(path.join(root, 'PROMPT.md'), 'utf8'),
    ...walk(path.join(root, 'common')).filter((file) => file.endsWith('.md')).map((file) =>
      fs.readFileSync(path.join(root, 'common', file), 'utf8')),
  ].join('\n')
  for (const phrase of forbiddenCommonPhrases) {
    if (visibleInput.includes(phrase)) errors.push(`HIDDEN_HYPOTHESIS_LEAK ${condition} ${phrase}`)
  }
  for (const [file, expectedHash] of Object.entries(manifest.conditions[condition].files)) {
    if (hash(path.join(root, file)) !== expectedHash) errors.push(`MANIFEST_HASH_MISMATCH ${condition} ${file}`)
  }
}

if (errors.length) {
  for (const error of errors.sort()) console.error(error)
  process.exit(1)
}
console.log(`INPUT_AUDIT_OK conditions=${conditions.length}`)
```

- [ ] **Step 6: Run the seal audit and prove the baseline snapshot source**

Run:

```bash
npm run audit:inputs
git show 36a8fe8e54c162f7b77e52c15cc70d649674505c:woobin-harness/skills/design-rules/SKILL.md | shasum -a 256
shasum -a 256 inputs/design-rules/skill/design-rules/SKILL.md
```

Expected:

```text
INPUT_AUDIT_OK conditions=3
```

The two SHA-256 values for legacy `SKILL.md` must match exactly.

- [ ] **Step 7: Commit the sealed packages**

Run:

```bash
git add experiments/design-workflow-dashboard/scripts experiments/design-workflow-dashboard/inputs
git commit -m "Seal dashboard experiment generation inputs"
```

Record the resulting commit as the common starting point for all three tracks:

```bash
git rev-parse HEAD
```

- [ ] **Step 8: Create three isolated track worktrees from the same commit**

Run from the integration worktree:

```bash
git worktree add -b experiment/dashboard-baseline ../pumped-sheep-dashboard-baseline HEAD
git worktree add -b experiment/dashboard-design-rules ../pumped-sheep-dashboard-design-rules HEAD
git worktree add -b experiment/dashboard-design-workflow ../pumped-sheep-dashboard-design-workflow HEAD
git worktree list
```

Expected: the three new worktrees show the same starting commit. Do not create `evaluation/`, `launcher/`, or sibling variant code before spawning Tasks 3–5.
