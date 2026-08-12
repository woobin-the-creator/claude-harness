#!/usr/bin/env bash
# Stop guard — stale-branch-guard.sh(SessionStart)가 남긴 마커가 있는데
# 이번 턴 응답에 그 경고 원문이 실제로 포함되지 않았으면 반려(block)해서
# 강제로 한 번 더 답하게 한다. additionalContext가 모델에게 전달됐는지와
# 무관하게(harness의 알려진 드롭 버그 포함) 마커 파일 자체는 항상 남아있으므로,
# "프롬프트로 부탁"이 아니라 "응답을 실제로 검사"하는 결정론적 게이트다.
# stop_hook_active로 무한루프를 막는다 — 재시도는 1회까지만 강제하고 포기한다.
# (bash 3.2 호환)

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$session_id" ] || exit 0

state_dir=${HARNESS_STATE_DIR:-$HOME/.claude}
marker_dir="$state_dir/hooks/.stale-branch-pending"
marker="$marker_dir/$session_id"
[ -f "$marker" ] || exit 0

transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
stop_hook_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)

signature="stale-branch 점검"

last_text=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null)
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  [ -n "$last_text" ] || last_text=$(tail -n 2000 "$transcript_path" 2>/dev/null | jq -s -r '
      [.[] | select(.type == "assistant")] | last
      | (.message.content // []) | map(select(.type == "text") | .text) | join("\n")
    ' 2>/dev/null)
fi

# 응답에 경고 원문이 들어갔으면 충족 — 마커 정리하고 조용히 종료.
if printf '%s' "$last_text" | grep -qF "$signature" 2>/dev/null; then
  rm -f "$marker" 2>/dev/null
  exit 0
fi

# 이미 한 번 반려해서 재시도한 결과인데도 없으면 포기 — 무한루프 방지.
if [ "$stop_hook_active" = "true" ]; then
  rm -f "$marker" 2>/dev/null
  exit 0
fi

# 마지막 응답도 transcript도 못 읽었으면 fail-open — 잘못된 파싱으로 계속 막지 않는다.
if [ -z "$last_text" ] && { [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; }; then
  exit 0
fi

stored_ctx=$(cat "$marker" 2>/dev/null)
reason="SessionStart가 세션 시작 시 준 stale-branch 경고를 이번 응답에 아직 그대로 전달하지 않았습니다. 답변을 마치기 전에, 아래 경고 원문을 응답 앞부분에 그대로 인용해 사용자에게 알리고 나서 나머지 내용을 이어가세요:

${stored_ctx}"

jq -cn --arg reason "$reason" '{decision:"block",reason:$reason}'
