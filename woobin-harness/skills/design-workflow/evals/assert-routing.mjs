#!/usr/bin/env node
import fs from 'node:fs'

const expected = {
  'established-first-use': {
    route: 'system-evidence → implementation-contracts → review',
    design: 'absent',
    mutation: 'allowed',
  },
  greenfield: {
    route: 'direction → system-evidence → implementation-contracts → review',
    design: 'absent',
    mutation: 'approval-required',
  },
  incremental: {
    route: 'system-evidence → implementation-contracts → review',
    design: 'validate',
    mutation: 'allowed',
  },
  'review-only': {
    route: 'system-evidence → review',
    design: 'validate',
    mutation: 'forbidden',
  },
  'guard-promotion': {
    route: 'system-evidence → implementation-contracts → evolution → review',
    design: 'absent',
    mutation: 'approval-required',
  },
}

const [caseName, outputPath] = process.argv.slice(2)

if (!caseName || !outputPath) {
  fail('usage: assert-routing.mjs <case-name> <output-file>')
}

const contract = expected[caseName]
if (!contract) {
  fail(`unknown case: ${caseName}`)
}

const output = fs.readFileSync(outputPath, 'utf8')
const parsed = new Map()

for (const rawLine of output.split(/\r?\n/)) {
  const line = rawLine.trim()
  if (line === '') continue
  const match = /^(ROUTE|DESIGN_BEHAVIOR|MUTATION|FIRST_ACTION)=(.*)$/.exec(line)
  if (!match) {
    fail(`unexpected line: ${line}`)
  }
  const [, key, value] = match
  if (parsed.has(key)) {
    fail(`duplicate key: ${key}`)
  }
  parsed.set(key, value)
}

for (const key of ['ROUTE', 'DESIGN_BEHAVIOR', 'MUTATION', 'FIRST_ACTION']) {
  if (!parsed.has(key)) {
    fail(`missing key: ${key}`)
  }
}

assertEqual('ROUTE', parsed.get('ROUTE'), contract.route)
assertEqual('DESIGN_BEHAVIOR', parsed.get('DESIGN_BEHAVIOR'), contract.design)
assertEqual('MUTATION', parsed.get('MUTATION'), contract.mutation)

if (parsed.get('FIRST_ACTION').trim() === '') {
  fail('FIRST_ACTION is empty')
}

function assertEqual(key, actual, expectedValue) {
  if (actual !== expectedValue) {
    fail(`${key} expected "${expectedValue}" but got "${actual}"`)
  }
}

function fail(message) {
  console.error(`ROUTING_ASSERT_FAIL ${message}`)
  process.exit(1)
}
