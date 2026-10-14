#!/bin/bash
# /close-session 가로채기 (UserPromptSubmit 훅)
# 사용자가 /close-session 을 치면 워크트리·브랜치·자원 정리를 돌리고 block 으로 끊는다.
# block 이라 모델이 호출되지 않는다 = 토큰 0. (스킬로 돌리면 200k 캐시 리드 $0.10 이 든다)
#
# 2026-10-14 전에는 이 분기가 idle-return-guard.sh 안에 있었다. 자리비움 핸드오프(R6)를
# Claude Code 내장 idle compaction(2.1.299)으로 넘기며 그 훅을 지웠고, 이 분기만 떼어 남겼다.
# 정리 규칙은 lib/close-session-cleanup.sh 가 단일 정본이다 — 여기서 재구현하지 마라.

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // empty')
case "$prompt" in
  /close-session|/close-session[[:space:]]*) ;;
  *) exit 0 ;;
esac

cleanup_sh="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/lib/close-session-cleanup.sh"
cleanup=$(bash "$cleanup_sh" "$(echo "$input" | jq -r '.cwd // empty')" 2>/dev/null)
msg="🔒 세션을 닫았습니다."
[ -n "$cleanup" ] && msg="$msg
$cleanup"
jq -n --arg m "$msg" '{decision: "block", reason: $m}'
exit 0
