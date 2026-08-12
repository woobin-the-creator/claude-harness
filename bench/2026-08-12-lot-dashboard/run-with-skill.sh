#!/usr/bin/env bash
# 팔 2/2 — design-rules 스킬 적용. --plugin-dir 로 이 워크트리의 개정본을 물린다(설치본 v1.5.0 아님).
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$BASE/../../woobin-harness" && pwd)"
cd "$BASE/with-skill" || exit 1

PROMPT="design-rules 스킬을 적용해서 아래를 만들어라.

$(cat "$BASE/prompt.txt")"

claude -p "$PROMPT" \
  --setting-sources project \
  --plugin-dir "$PLUGIN" \
  --permission-mode acceptEdits \
  --allowedTools Write Edit Read Glob Grep Skill \
  --output-format json > run.json 2> run.err

echo "exit=$?"
