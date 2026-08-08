#!/bin/bash
# 자리비움 자동 핸드오프 (Stop 훅, asyncRewake)
# 턴 종료 후 백그라운드로 대기하다가, IDLE_HANDOFF_DELAY(기본 50분) 동안
# 새 활동이 없으면 exit 2 로 모델을 깨워 캐시가 살아있을 때 핸드오프 문서를 만들게 한다.
# - 대기 중 transcript 가 갱신되면(새 턴 시작) 조용히 취소
# - 실제 경과가 IDLE_HANDOFF_MAXGAP(기본 59분)을 넘겼으면(잠자기 등) 캐시 만료로 보고
#   "이 세션 이어가지 말고 새 세션으로" 버전의 문구를 주입한다(포기하지 않는다 — 2026-07-28 수정)
#
# 재주입 방지는 삭제 가능한 마커가 아니라 "파일 mtime 신선도"로 판정한다.
# (마커 방식은 rewake 주입 자체가 UserPromptSubmit 훅을 태워 복귀 가드가 마커를
#  지우는 레이스로 50분 주기 무한 루프가 실제 발생 — 2026-07-24)

input=$(cat)
sid=$(echo "$input" | jq -r '.session_id // empty')
tp=$(echo "$input" | jq -r '.transcript_path // empty')
[ -z "$sid" ] && exit 0
[ -z "$tp" ] || [ ! -f "$tp" ] && exit 0

dir="$HOME/.claude/idle-handoff"
mkdir -p "$dir"
doc="$HOME/.claude/idle-handoffs/${sid}.md"
notified="$dir/$sid.notified"
injected="$dir/$sid.last-inject"

# 사용자가 /close-session 으로 닫은 세션 → 대기도 주입도 알림도 없이 즉시 종료.
# 마커 생성·해제는 idle-return-guard.sh 가 전담한다(정상 활동이 오면 자동 해제).
[ -f "$dir/$sid.handoff-done" ] && exit 0

start_mtime=$(stat -f %m "$tp" 2>/dev/null) || exit 0
FRESH=${IDLE_HANDOFF_FRESH:-300}   # 마지막 활동 기준 이 초 이내에 생긴 파일 = 이번 유휴 국면 소산
fresh() { [ -f "$1" ] && [ "$(stat -f %m "$1" 2>/dev/null || echo 0)" -ge $((start_mtime - FRESH)) ]; }

# 핸드오프 턴 직후의 발화: 문서가 이미 이번 국면 기준 최신 → 재주입 금지, 완료 알림 1회
if fresh "$doc"; then
  if ! fresh "$notified"; then
    touch "$notified"
    osascript -e "display notification \"핸드오프 문서를 남기고 대기 상태로 전환했어요: ~/.claude/idle-handoffs/${sid}.md\" with title \"Claude Code — 자리비움 핸드오프\" sound name \"Glass\"" 2>/dev/null
  fi
  exit 0
fi

# 이번 국면에 주입까지 했는데 문서가 안 생김 → 실패 알림 1회, 재주입은 안 함(루프 방지)
if fresh "$injected"; then
  if ! fresh "$notified"; then
    touch "$notified"
    osascript -e "display notification \"자리비움을 감지했지만 핸드오프 문서 생성이 확인되지 않았어요. 세션을 확인해 주세요.\" with title \"Claude Code — 자리비움 핸드오프\" sound name \"Basso\"" 2>/dev/null
  fi
  exit 0
fi

DELAY=${IDLE_HANDOFF_DELAY:-3000}      # 50분
POLL=${IDLE_HANDOFF_POLL:-60}
MAXGAP=${IDLE_HANDOFF_MAXGAP:-3540}    # 59분 — 이걸 넘겼으면 캐시 만료로 간주

waited=0
while [ "$waited" -lt "$DELAY" ]; do
  sleep "$POLL"
  waited=$((waited + POLL))
  # 24행의 마커 검사는 대기 시작 "전" 한 번뿐이다. /close-session 은 이 루프가 이미
  # 돌고 있는 동안 들어오므로, 루프 안에서도 봐야 그 대기자가 멈춘다.
  # (blocked 프롬프트가 transcript mtime 을 건드리는지에 기대지 않기 위한 것 — 2026-08-04)
  [ -f "$dir/$sid.handoff-done" ] && exit 0
  cur=$(stat -f %m "$tp" 2>/dev/null) || exit 0
  [ "$cur" != "$start_mtime" ] && exit 0
done

now=$(date +%s)
gap=$((now - start_mtime))

touch "$injected"
mkdir -p "$HOME/.claude/idle-handoffs"

if [ "$gap" -gt "$MAXGAP" ]; then
  # 절전 등으로 폴링 루프가 정지해 깨어나 보니 이미 캐시가 만료된 경우.
  # 예전에는 여기서 조용히 포기했는데(exit 0), 그게 정확히 최악의 선택이었다:
  # 캐시가 죽은 상태야말로 다음 턴이 전체 컨텍스트를 재캐싱하므로 핸드오프 가치가 가장 크다.
  # 2026-07-28 실측 — 세션 7b447615(353k tok 재캐싱 $3.36)·6a09249c(205k tok $1.94)가
  # 맥 절전 165분 뒤 이 분기에서 포기당해 합계 $5.30을 재캐싱으로 다시 냈다.
  cat >&2 <<EOF
[자리비움 자동 핸드오프 — 캐시 만료 후] 마지막 활동 후 $((gap / 60))분이 지났고 프롬프트 캐시는 이미 만료됐습니다. 이 세션을 그대로 이어가면 다음 턴이 전체 컨텍스트를 통째로 재캐싱합니다. handoff 스킬을 호출해 이 대화의 핸드오프 문서를 작성하세요. 문서는 반드시 다음 경로에 저장하세요: $doc
작성이 끝나면 다른 작업 없이 "자리비움 감지(캐시 만료) — 핸드오프 문서를 $doc 에 저장해 두었어요. 이 세션을 이어가지 말고 새 세션에서 이 문서를 읽고 시작하는 편이 쌉니다." 한 줄만 남기고 턴을 마치세요. 사용자에게 질문하지 마세요.
EOF
else
  cat >&2 <<EOF
[자리비움 자동 핸드오프] 마지막 활동 후 50분이 지났고 사용자 입력이 없습니다. 프롬프트 캐시가 만료되기 전에 handoff 스킬을 호출해 이 대화의 핸드오프 문서를 작성하세요. 문서는 반드시 다음 경로에 저장하세요: $doc
작성이 끝나면 다른 작업 없이 "자리비움 감지 — 핸드오프 문서를 $doc 에 저장해 두었어요. 복귀 후 새 세션에서 이 문서를 읽고 시작하면 재캐싱 비용 없이 이어갈 수 있어요." 한 줄만 남기고 턴을 마치세요. 사용자에게 질문하지 마세요.
EOF
fi
exit 2
