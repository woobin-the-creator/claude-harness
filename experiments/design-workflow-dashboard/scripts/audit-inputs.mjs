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
