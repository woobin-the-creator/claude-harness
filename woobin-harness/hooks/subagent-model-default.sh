#!/bin/sh
# PreToolUse(Agent|Task) — model 미지정 서브에이전트를 sonnet(latest)으로 기본값 고정.
#
# 왜: 서브에이전트는 model을 명시하지 않으면 **부모 세션 모델을 상속**한다(harness 기본값 "inherit").
# 2026-07-30 실측 — 메인이 opus-5인 상태에서 model 없이 스폰된 general-purpose 에이전트들이
# opus로 돌아 하루 $25.30을 썼다(시안 3개 $8.91/$6.58/$5.79, SDD Task 6 $3.26).
# 같은 일을 sonnet으로 했으면 ~40% 싸다.
#
# 왜 env(CLAUDE_CODE_SUBAGENT_MODEL)를 쓰지 않는가: 그 변수는 우선순위가 최상위라
# Agent 호출의 명시적 model 인자와 에이전트 정의 frontmatter까지 **덮어쓴다**
# (2.1.220 바이너리 확인: env가 있으면 tool/frontmatter 값을 버리고 telemetry에 override_dropped 기록).
# 그러면 "최종 whole-branch 리뷰는 opus" 같은 의도적 승격이 조용히 깨진다.
# 그래서 PreToolUse의 updatedInput으로 **미지정일 때만** 채운다.
#
# 존중하는 것(주입하지 않음):
#   - 호출에 model이 이미 있는 경우
#   - 에이전트 정의(.claude/agents/<type>.md)에 model frontmatter가 있는 경우 (Explore=haiku, screenshot-verifier=sonnet)
#   - 플러그인 네임스페이스 타입(codex:… 등) — 정의 위치를 신뢰할 수 없어 건드리지 않는다

set -u

DEFAULT_MODEL=${SUBAGENT_DEFAULT_MODEL:-sonnet}

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

# 이미 명시된 model이 있으면 그대로 존중.
model=$(printf '%s' "$input" | jq -r '.tool_input.model // empty' 2>/dev/null)
[ -z "$model" ] || exit 0

atype=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // "general-purpose"' 2>/dev/null)
case "$atype" in
  *:*) exit 0 ;;   # 플러그인 에이전트는 그쪽 정의를 따른다
esac

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$(pwd)
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)

# 에이전트 정의에 model frontmatter가 있으면 그쪽이 정본.
for f in "$cwd/.claude/agents/$atype.md" "${root:-$cwd}/.claude/agents/$atype.md" "$HOME/.claude/agents/$atype.md"; do
  [ -f "$f" ] || continue
  if head -20 "$f" | grep -qE '^model:[[:space:]]*[^[:space:]]'; then
    exit 0
  fi
done

new_input=$(printf '%s' "$input" | jq -c --arg m "$DEFAULT_MODEL" '.tool_input + {model: $m}' 2>/dev/null)
[ -n "$new_input" ] || exit 0

# 세션 첫 주입에만 모델에게 한 줄 알린다(매 호출 주입은 그 자체가 토큰 낭비).
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
marker_dir="${TMPDIR:-/tmp}/claude-subagent-model-default"
notify=0
if [ -n "$session_id" ]; then
  marker="$marker_dir/$session_id"
  if [ ! -e "$marker" ]; then
    mkdir -p "$marker_dir" 2>/dev/null
    : > "$marker" 2>/dev/null
    notify=1
  fi
fi

note="model을 지정하지 않은 서브에이전트는 이 세션에서 ${DEFAULT_MODEL}으로 스폰됩니다(부모 모델 상속 아님).
난이도가 높아 상위 모델이 필요한 호출은 Agent 인자에 model을 **명시**하세요 — 명시값은 이 훅이 건드리지 않습니다."

if [ "$notify" = "1" ]; then
  jq -cn --argjson ui "$new_input" --arg m "$DEFAULT_MODEL" --arg note "$note" \
    '{systemMessage:("서브에이전트 model 미지정 → " + $m + " 기본값 적용"),
      hookSpecificOutput:{hookEventName:"PreToolUse",updatedInput:$ui,additionalContext:$note}}'
else
  jq -cn --argjson ui "$new_input" --arg m "$DEFAULT_MODEL" \
    '{systemMessage:("서브에이전트 model 미지정 → " + $m + " 기본값 적용"),
      hookSpecificOutput:{hookEventName:"PreToolUse",updatedInput:$ui}}'
fi
