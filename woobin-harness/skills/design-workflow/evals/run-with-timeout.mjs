#!/usr/bin/env node
import fs from 'node:fs'
import { spawn } from 'node:child_process'

const [timeoutValue, outputPath, timeoutMessage, separator, command, ...args] = process.argv.slice(2)

if (!timeoutValue || !outputPath || !timeoutMessage || separator !== '--' || !command) {
  fail('usage: run-with-timeout.mjs <timeout-seconds> <output-file> <timeout-message> -- <command> [args...]', 2)
}

const timeoutSeconds = Number(timeoutValue)
if (!Number.isFinite(timeoutSeconds) || timeoutSeconds <= 0) {
  fail(`invalid timeout seconds: ${timeoutValue}`, 2)
}

const output = fs.createWriteStream(outputPath, { flags: 'w' })
const child = spawn(command, args, {
  detached: process.platform !== 'win32',
  stdio: ['ignore', 'pipe', 'pipe'],
})

let finished = false
let timedOut = false

child.stdout.pipe(output)
child.stderr.pipe(process.stderr)

const timer = setTimeout(() => {
  timedOut = true
  cleanupChild()
}, Math.ceil(timeoutSeconds * 1000))

child.on('error', error => {
  if (finished) return
  finished = true
  clearTimeout(timer)
  output.end(() => {
    console.error(`EVAL_COMMAND_ERROR ${error.message}`)
    process.exit(127)
  })
})

child.on('exit', (code, signal) => {
  if (finished) return
  finished = true
  clearTimeout(timer)
  output.end(() => {
    if (timedOut) {
      console.error(timeoutMessage)
      process.exit(124)
    }
    if (signal) {
      console.error(`EVAL_SIGNAL signal=${signal}`)
      process.exit(1)
    }
    process.exit(code ?? 1)
  })
})

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    cleanupChild()
    process.kill(process.pid, signal)
  })
}

function cleanupChild() {
  if (child.exitCode !== null || child.signalCode !== null) return
  try {
    if (process.platform === 'win32') {
      child.kill('SIGTERM')
    } else {
      process.kill(-child.pid, 'SIGTERM')
    }
  } catch {}
  setTimeout(() => {
    try {
      if (process.platform === 'win32') {
        child.kill('SIGKILL')
      } else {
        process.kill(-child.pid, 'SIGKILL')
      }
    } catch {}
  }, 1000).unref()
}

function fail(message, code) {
  console.error(`EVAL_TIMEOUT_WRAPPER_ERROR ${message}`)
  process.exit(code)
}
