#!/usr/bin/env bash
# 팔 1/2 — design-rules 스킬 없이. 사용자 전역 설정·설치 플러그인을 로드하지 않는다.
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE/no-skill" || exit 1

claude -p "$(cat "$BASE/prompt.txt")" \
  --setting-sources project \
  --permission-mode acceptEdits \
  --allowedTools Write Edit Read Glob Grep \
  --output-format json > run.json 2> run.err

echo "exit=$?"
