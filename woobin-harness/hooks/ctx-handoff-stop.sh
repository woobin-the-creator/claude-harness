#!/bin/sh
# 컨텍스트 자동 핸드오프 (Stop 훅) — 턴이 CTX_HANDOFF_THRESHOLD(기본 300k) 이상에서 끝나면
# exit 2 로 모델을 깨워 handoff 스킬로 핸드오프 문서를 쓰게 하고, 새 세션 전환을 안내한다.
#
# 왜: ctx-warn-statusline.sh 가 200k/300k 를 이미 표시하지만 그건 statusline 텍스트다.
# 2026-07-28(#3) 재측정에서 경고 도입 뒤에도 351k 세션이 발생했고 — "인지 수단만으로는 못 막는다" —
# 2026-08-10 7일 전수에서는 300k 를 넘긴 뒤에도 계속 돈 세션이 10건, 그 구간이 45k floor 대비
# 초과로 낸 cache read 가 $88.47(주간 총지출의 10.4%)였다.
# 이 하네스에서 ✅ 로 재측정된 개입(#1 핸드오프, #2 위임)은 전부 경고가 아니라 **대체 경로를
# 만들어 준** 형태였다. 그래서 여기서도 알리는 대신 문서를 만들게 한다.
#
# idle-handoff-stop.sh 와의 차이 — 복제할 때 이 세 줄을 같이 옮기지 말 것:
#   1. asyncRewake·폴링 루프 없음. 판정 대상이 "지금 끝난 턴의 크기"라 대기할 이유가 없다.
#   2. 재주입 방지가 mtime 신선도가 아니라 세션 1회 마커 + stop_hook_active 다.
#      mtime 방식은 "유휴 국면"이라는 **반복되는** 상태를 판정하려고 도입한 것이고(#1의 무한루프 사고),
#      여기서는 세션당 한 번뿐이라 마커가 더 단순하고 루프 위험이 없다.
#   3. 트리거가 시간이 아니라 크기다. 그래서 자리비움과 무관하게 발화한다.
#
# 문서 계약은 여기 쓰지 않고 handoff 스킬(woobin-harness/skills/handoff/SKILL.md)이 소유한다.
# 훅 2개가 같은 문장을 각자 갖고 있으면 한쪽만 고쳐져 갈라진다 — #16 이 그 사고였다.

set -u

TH=${CTX_HANDOFF_THRESHOLD:-300000}

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

# 우리가 깨워서 도는 턴에서 또 발화하면 무한 루프다.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0

tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$tp" ] || exit 0
[ -f "$tp" ] || exit 0

# /close-session 으로 닫힌 세션은 건드리지 않는다(마커 소유는 idle-return-guard.sh).
[ -f "$HOME/.claude/idle-handoff/$sid.handoff-done" ] && exit 0

# 세션 1회.
marker_dir="${TMPDIR:-/tmp}/claude-ctx-handoff"
marker="$marker_dir/$sid"
[ -e "$marker" ] && exit 0

# 현재 컨텍스트 = transcript 마지막 assistant usage.
# ctx-warn-statusline.sh · plan-session-boundary-guard.sh 와 **같은 식**을 쓴다.
# 세 곳이 다른 값을 말하면 사용자가 어느 쪽을 믿을지 몰라진다.
ctx=$(tail -n 40 "$tp" 2>/dev/null | jq -rR '
    fromjson? // empty
    | select(.type == "assistant")
    | .message.usage // empty
    | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)
  ' 2>/dev/null | tail -n 1)
case "$ctx" in ''|*[!0-9]*) ctx=0 ;; esac
[ "$ctx" -ge "$TH" ] || exit 0

mkdir -p "$marker_dir" 2>/dev/null
: > "$marker" 2>/dev/null

doc="$HOME/.claude/idle-handoffs/${sid}.md"
mkdir -p "$HOME/.claude/idle-handoffs" 2>/dev/null
ctx_k=$((ctx / 1000))

cat >&2 <<EOF
[컨텍스트 자동 핸드오프] 이번 턴이 ${ctx_k}k 컨텍스트에서 끝났습니다. 이 세션을 그대로 이어가면 남은 모든 요청이 이 ${ctx_k}k 를 cache read 로 다시 청구합니다(2026-08-10 7일 전수: 300k 초과 세션 10건이 그 초과분으로만 \$88.47).

handoff 스킬을 호출해 이 대화의 핸드오프 문서를 작성하세요. 문서는 반드시 다음 경로에 저장하세요: ${doc}

작성이 끝나면 다른 작업 없이 아래 한 줄만 남기고 턴을 마치세요. 사용자에게 질문하지 마세요.
"컨텍스트가 ${ctx_k}k 라 핸드오프 문서를 ${doc} 에 저장했어요. /clear 후 이 문서를 읽고 이어가면 이후 요청이 훨씬 쌉니다."
EOF
exit 2
