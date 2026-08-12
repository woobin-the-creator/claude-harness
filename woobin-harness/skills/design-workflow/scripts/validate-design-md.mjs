#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { SCHEMA_VERSION, validateDesignData } from './design-document-schema.mjs'

const START = '<!-- design-workflow:data:start -->'
const END = '<!-- design-workflow:data:end -->'
const MANAGED = /design_workflow:\s*\n(?:[ \t]+.*\n)*?[ \t]+enabled:\s*true(?:\s|$)/
const FRONTMATTER_SCHEMA = /design_workflow:\s*\n(?:[ \t]+.*\n)*?[ \t]+schema_version:\s*(\d+)(?:\s|$)/

function resolveTarget(input) {
  const raw = input ?? process.cwd()
  const absolute = path.resolve(raw)
  if (fs.existsSync(absolute) && fs.statSync(absolute).isDirectory()) {
    return { designPath: path.join(absolute, 'DESIGN.md'), repoRoot: absolute }
  }
  return { designPath: absolute, repoRoot: path.dirname(absolute) }
}

function initialFrontmatter(text) {
  if (!text.startsWith('---\n')) return ''
  const end = text.indexOf('\n---', 4)
  if (end === -1) return ''
  const after = text.slice(end, end + 5)
  return after === '\n---\n' || after === '\n---\r' || after.startsWith('\n---') ? text.slice(4, end + 1) : ''
}

function countOccurrences(text, needle) {
  let count = 0
  let offset = 0
  for (;;) {
    const found = text.indexOf(needle, offset)
    if (found === -1) return count
    count += 1
    offset = found + needle.length
  }
}

function isExternalReference(value) {
  return typeof value === 'string' && (value.includes('@') || value.includes('://'))
}

function safeProjectPath(repoRoot, value, options = {}) {
  if (typeof value !== 'string' || value.trim() === '') return null
  if (options.allowExternal && isExternalReference(value)) return null
  const resolved = path.resolve(repoRoot, value)
  const rel = path.relative(repoRoot, resolved)
  if (rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel))) return resolved
  return false
}

function addMissingPathErrors(errors, repoRoot, data) {
  if (Array.isArray(data.authorities)) data.authorities.forEach((authority, index) => {
    const candidate = safeProjectPath(repoRoot, authority?.path)
    if (candidate && !fs.existsSync(candidate)) {
      errors.push({ code: 'DESIGN_E_PATH_MISSING', path: `/authorities/${index}/path`, message: 'referenced project path does not exist' })
    } else if (candidate === false) {
      errors.push({ code: 'DESIGN_E_PATH_OUTSIDE_REPO', path: `/authorities/${index}/path`, message: 'referenced path leaves repository root' })
    }
  })
  if (!Array.isArray(data.decisions)) return
  data.decisions.forEach((decision, index) => {
    const base = `/decisions/${index}`
    if (Array.isArray(decision?.source?.references)) decision.source.references.forEach((ref, refIndex) => {
      const candidate = safeProjectPath(repoRoot, ref, { allowExternal: true })
      if (candidate && !fs.existsSync(candidate)) {
        errors.push({ code: 'DESIGN_E_PATH_MISSING', path: `${base}/source/references/${refIndex}`, message: 'referenced project path does not exist' })
      } else if (candidate === false) {
        errors.push({ code: 'DESIGN_E_PATH_OUTSIDE_REPO', path: `${base}/source/references/${refIndex}`, message: 'referenced path leaves repository root' })
      }
    })
    if (Array.isArray(decision?.localEvidence)) decision.localEvidence.forEach((ref, refIndex) => {
      const candidate = safeProjectPath(repoRoot, ref)
      if (candidate && !fs.existsSync(candidate)) {
        errors.push({ code: 'DESIGN_E_PATH_MISSING', path: `${base}/localEvidence/${refIndex}`, message: 'referenced project path does not exist' })
      } else if (candidate === false) {
        errors.push({ code: 'DESIGN_E_PATH_OUTSIDE_REPO', path: `${base}/localEvidence/${refIndex}`, message: 'referenced path leaves repository root' })
      }
    })
    if (Array.isArray(decision?.enforcement)) decision.enforcement.forEach((item, itemIndex) => {
      const candidate = safeProjectPath(repoRoot, item?.path)
      if (candidate && !fs.existsSync(candidate)) {
        errors.push({ code: 'DESIGN_E_PATH_MISSING', path: `${base}/enforcement/${itemIndex}/path`, message: 'referenced project path does not exist' })
      } else if (candidate === false) {
        errors.push({ code: 'DESIGN_E_PATH_OUTSIDE_REPO', path: `${base}/enforcement/${itemIndex}/path`, message: 'referenced path leaves repository root' })
      }
    })
  })
}

const { designPath, repoRoot } = resolveTarget(process.argv[2])

if (!fs.existsSync(designPath)) {
  console.log(`DESIGN_ABSENT path=${designPath}`)
  process.exit(0)
}

const text = fs.readFileSync(designPath, 'utf8')
const frontmatter = initialFrontmatter(text)

if (!MANAGED.test(frontmatter)) {
  console.log(`DESIGN_UNMANAGED path=${designPath}`)
  process.exit(0)
}

const schemaMatch = frontmatter.match(FRONTMATTER_SCHEMA)
if (!schemaMatch || Number(schemaMatch[1]) !== SCHEMA_VERSION) {
  console.error(`DESIGN_E_FRONTMATTER_SCHEMA path=/design_workflow/schema_version message=expected ${SCHEMA_VERSION}`)
  process.exit(1)
}

const errors = []
let data
if (countOccurrences(text, START) !== 1 || countOccurrences(text, END) !== 1 || text.indexOf(START) > text.indexOf(END)) {
  errors.push({ code: 'DESIGN_E_MARKERS', path: '/', message: 'managed file requires exactly one data marker pair' })
} else {
  const between = text.slice(text.indexOf(START) + START.length, text.indexOf(END))
  const block = between.match(/^\s*```json\s*\n([\s\S]*?)\n```\s*$/)
  if (!block) {
    errors.push({ code: 'DESIGN_E_DATA_BLOCK', path: '/', message: 'managed data must be one fenced json block' })
  } else {
    try {
      data = JSON.parse(block[1])
    } catch (error) {
      errors.push({ code: 'DESIGN_E_JSON', path: '/', message: error.message })
    }
    if (!errors.some((error) => error.code === 'DESIGN_E_JSON')) {
      errors.push(...validateDesignData(data))
      if (data && typeof data === 'object' && !Array.isArray(data)) {
        addMissingPathErrors(errors, repoRoot, data)
      }
    }
  }
}

errors.sort((left, right) => `${left.path}:${left.code}`.localeCompare(`${right.path}:${right.code}`))
for (const error of errors) {
  console.error(`${error.code} path=${error.path} message=${error.message}`)
}
if (errors.length) {
  process.exit(1)
}
console.log(`DESIGN_OK schema=${SCHEMA_VERSION} decisions=${data.decisions.length}`)
