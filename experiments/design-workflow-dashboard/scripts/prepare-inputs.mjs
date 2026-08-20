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
