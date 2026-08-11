#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { relative, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const distArg = process.argv[2]

if (!distArg) {
  process.exit(1)
}

const distRoot = resolve(distArg)
const indexPath = resolve(distRoot, 'index.html')
const failures = []

if (!existsSync(indexPath)) {
  console.log('index.html')
  process.exit(1)
}

const html = readFileSync(indexPath, 'utf8')
const refs = [...html.matchAll(/(?:src|href)=["']([^"']+)["']/g)].map((match) => match[1])
const distBaseUrl = pathToFileURL(`${distRoot}/`)
const seenMissing = new Set()

for (const ref of refs) {
  if (/^(?:https?:|data:|#)/.test(ref)) {
    continue
  }

  const clean = ref.split(/[?#]/, 1)[0].replace(/^\.\//, '').replace(/^\//, '')
  if (!clean) {
    continue
  }

  const targetPath = resolve(distRoot, clean)
  const rel = relative(distRoot, targetPath)
  if (rel.startsWith('..') || rel === '..') {
    if (!seenMissing.has(clean)) {
      failures.push(clean)
      seenMissing.add(clean)
    }
    continue
  }

  // Resolve through a file URL so relative asset references follow browser-style path rules.
  const resolvedPath = resolve(new URL(clean, distBaseUrl).pathname)
  if (!existsSync(resolvedPath) && !seenMissing.has(clean)) {
    failures.push(clean)
    seenMissing.add(clean)
  }
}

let fileCount = 0
let hasJsAsset = false

const walk = (dir) => {
  for (const entry of readdirSync(dir)) {
    const entryPath = resolve(dir, entry)
    const entryStat = statSync(entryPath)
    if (entryStat.isDirectory()) {
      walk(entryPath)
      continue
    }
    fileCount += 1
    if (/\.js$/i.test(entry)) {
      hasJsAsset = true
    }
  }
}

walk(distRoot)

if (!hasJsAsset) {
  failures.push('NO_JS_ASSET')
}

if (failures.length > 0) {
  for (const failure of failures) {
    console.log(failure)
  }
  process.exit(1)
}

console.log(`DIST_OK files=${fileCount}`)
