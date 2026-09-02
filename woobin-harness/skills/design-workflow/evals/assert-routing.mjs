#!/usr/bin/env node
import fs from 'node:fs'

const expected = {
  'established-first-use': {
    route: 'principles → system-evidence → implementation-contracts → review',
    design: 'absent',
    localMutation: 'allowed',
    escalation: 'approval-required',
  },
  greenfield: {
    route: 'principles → direction → system-evidence → implementation-contracts → review',
    design: 'absent',
    localMutation: 'allowed',
    escalation: 'approval-required',
  },
  incremental: {
    route: 'principles → system-evidence → implementation-contracts → review',
    design: 'validate',
    localMutation: 'allowed',
    escalation: 'approval-required',
  },
  'review-only': {
    route: 'principles → system-evidence → review',
    design: 'validate',
    localMutation: 'forbidden',
    escalation: 'forbidden',
  },
  'guard-promotion': {
    route: 'principles → system-evidence → implementation-contracts → evolution → review',
    design: 'absent',
    localMutation: 'allowed',
    escalation: 'approval-required',
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
  const match = /^(ROUTE|DESIGN_BEHAVIOR|LOCAL_MUTATION|ESCALATION|FIRST_ACTION)=(.*)$/.exec(line)
  if (!match) {
    fail(`unexpected line: ${line}`)
  }
  const [, key, value] = match
  if (parsed.has(key)) {
    fail(`duplicate key: ${key}`)
  }
  parsed.set(key, value)
}

for (const key of ['ROUTE', 'DESIGN_BEHAVIOR', 'LOCAL_MUTATION', 'ESCALATION', 'FIRST_ACTION']) {
  if (!parsed.has(key)) {
    fail(`missing key: ${key}`)
  }
}

assertEqual('ROUTE', parsed.get('ROUTE'), contract.route)
assertEqual('DESIGN_BEHAVIOR', parsed.get('DESIGN_BEHAVIOR'), contract.design)
assertEqual('LOCAL_MUTATION', parsed.get('LOCAL_MUTATION'), contract.localMutation)
assertEqual('ESCALATION', parsed.get('ESCALATION'), contract.escalation)

const firstAction = parsed.get('FIRST_ACTION').trim()
const routeAnnouncement = `작업 유형: `
const moduleAnnouncement = ` · 사용 모듈: ${contract.route}`
if (!firstAction.startsWith(routeAnnouncement)) {
  fail('FIRST_ACTION must start with route announcement')
}
if (!firstAction.includes(moduleAnnouncement)) {
  fail(`FIRST_ACTION must include "${moduleAnnouncement}"`)
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
