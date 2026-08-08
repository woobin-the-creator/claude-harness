#!/bin/bash
# 장기 자리비움 복귀 가드 (UserPromptSubmit 훅)
# 마지막 활동에서 IDLE_GUARD_THRESHOLD(기본 65분) 넘게 지난 세션에 프롬프트가 오면
# 1회 차단하고 안내한다(그 한 줄이 전체 재캐싱을 유발하는 사고 방지).
# 같은 프롬프트를 10분 내 다시 제출하면 통과시킨다.
# 정상 활동이 확인되면 idle-handoff 마커를 청소해 다음 자리비움 때 다시 발화하게 한다.

input=$(cat)
sid=$(echo "$input" | jq -r '.session_id // empty')
tp=$(echo "$input" | jq -r '.transcript_path // empty')
[ -z "$sid" ] && exit 0

dir="$HOME/.claude/idle-handoff"
mkdir -p "$dir"
warn="$dir/$sid.warned"
done_marker="$dir/$sid.handoff-done"

# /close-session — 대화가 끝났다고 사용자가 선언한다. 이 세션은 자리비움 핸드오프를 만들지 않는다.
# block 으로 끊으므로 모델이 호출되지 않는다 = 토큰 0. (스킬로 만들면 200k 캐시 리드 $0.10 이 든다)
# 별도 훅으로 빼지 않고 여기 둔 이유: 아래 49행이 정상 활동 시 done_marker 를 지우므로,
# 훅을 분리하면 실행 순서에 따라 방금 만든 마커가 곧바로 청소되는 경쟁이 생긴다.
prompt=$(echo "$input" | jq -r '.prompt // empty')
case "$prompt" in
  /close-session|/close-session[[:space:]]*)
    touch "$done_marker"
    rm -f "$warn" "$dir/$sid.notified"
    # 워크트리·브랜치 정리도 여기서 끝낸다 — block 으로 끊으니 모델이 못 도는데,
    # 스킬에만 넣으면 정상 경로에서는 영영 실행되지 않는다. 규칙은 스크립트가 단일 정본.
    cleanup=$(bash "$HOME/.claude/hooks/close-session-cleanup.sh" \
      "$(echo "$input" | jq -r '.cwd // empty')" 2>/dev/null)
    msg="🔒 세션을 닫았습니다 — 자리비움 자동 핸드오프를 만들지 않아요. 이 세션에 다시 프롬프트를 보내면 자동으로 해제됩니다."
    [ -n "$cleanup" ] && msg="$msg
$cleanup"
    jq -n --arg m "$msg" '{decision: "block", reason: $m}'
    exit 0 ;;
esac

# 새 세션이거나 transcript 없음 → 잴 것이 없음
[ -z "$tp" ] || [ ! -f "$tp" ] && exit 0

THRESH=${IDLE_GUARD_THRESHOLD:-3900}   # 65분
now=$(date +%s)
mt=$(stat -f %m "$tp" 2>/dev/null) || exit 0
gap=$((now - mt))

if [ "$gap" -gt "$THRESH" ]; then
  # 이미 경고했고 10분 내 재제출 → 통과 (사용자가 감수하고 이어가기로 함)
  if [ -f "$warn" ]; then
    wmt=$(stat -f %m "$warn" 2>/dev/null || echo 0)
    if [ $((now - wmt)) -lt 600 ]; then
      rm -f "$warn" "$done_marker" "$dir/$sid.notified"
      exit 0
    fi
  fi
  touch "$warn"
  mins=$((gap / 60))
  doc="$HOME/.claude/idle-handoffs/${sid}.md"
  if [ -f "$doc" ]; then
    doc_line="자동 생성된 핸드오프 문서가 있습니다: $doc — 새 세션에서 이 문서를 읽고 시작하는 걸 권장합니다."
  else
    doc_line="이 세션에는 자동 핸드오프 문서가 없습니다. 이어가야 한다면 재캐싱 비용을 감수해야 합니다."
  fi
  jq -n --arg reason "⏱️ 마지막 활동 후 ${mins}분이 지나 프롬프트 캐시가 만료됐습니다. 이 세션에 이어쓰면 전체 컨텍스트 재캐싱 비용이 듭니다. $doc_line 그래도 이 세션에서 이어가려면 같은 프롬프트를 다시 제출하세요(10분 내 재제출 시 통과)." \
    '{decision: "block", reason: $reason}'
  exit 0
fi

# 정상 활동 → 마커 청소
rm -f "$warn" "$done_marker" "$dir/$sid.notified"
exit 0
