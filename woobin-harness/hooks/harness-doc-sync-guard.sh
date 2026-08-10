#!/bin/sh
# 하네스 문서 동기화 가드 (PostToolUse:Edit|Write|MultiEdit)
# claude-harness 레포에서 woobin-harness/ 아래를 고치면 scripts/check-harness-docs.sh 를 돌려
# 불일치를 additionalContext 로 알린다. 세션 1회, 차단하지 않는다.
#
# 왜: CLAUDE.md 의 "같이 고쳐야 하는 것" 목록이 산문이라 2026-08-10 에 실제로 한 항목이 빠졌다.
# 규율 1(소프트 개입 우선)에 따라 차단은 안 하지만, 규율 2(구조를 바꾼다)에 따라 판정은
# 사람이 아니라 스크립트가 한다.

set -u

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$path" ] || exit 0
case "$path" in *woobin-harness/*) ;; *) exit 0 ;; esac

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$(pwd)
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
checker="$root/scripts/check-harness-docs.sh"
[ -x "$checker" ] || exit 0

# 세션 1회.
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
if [ -n "$session_id" ]; then
  marker_dir="${TMPDIR:-/tmp}/claude-harness-doc-sync"
  marker="$marker_dir/$session_id"
  [ -e "$marker" ] && exit 0
  mkdir -p "$marker_dir" 2>/dev/null
  : > "$marker" 2>/dev/null
fi

report=$(sh "$checker" 2>&1) || :
printf '%s' "$report" | grep -q '✗\|⚠' || exit 0

msg="[하네스 문서 동기화 검사] \`woobin-harness/\` 를 수정했습니다. 아래는 \`scripts/check-harness-docs.sh\` 결과입니다.

$report

✗ 는 반드시 고치고, ⚠ 는 판단해서 처리하세요. CLAUDE.md의 '고칠 때 같이 고쳐야 하는 것'이 산문이라
2026-08-10에 실제로 \`docs/workflow.html\` 이 빠진 적이 있어서 판정을 스크립트로 옮겼습니다.
이 알림은 세션 1회만 뜹니다."

jq -cn --arg ctx "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
