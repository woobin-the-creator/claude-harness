#!/bin/sh
# UserPromptSubmit — kick-off 워크플로우의 두 경로를 연다.
#
# 왜 훅이 필요한가: `kick-off` 스킬은 `disable-model-invocation: true`라 모델이 켤 수 없다.
# 그게 목적이다 — `brainstorming`이 `grill-me`와 트리거가 겹쳐 3일 246세션 발동 0회로 죽었다.
# 대신 사용자가 "킥오프"라고 **글자 그대로** 쓴 경우는 열어줘야 하고, 그 판정은 모델의 추론이
# 아니라 정규식이 한다. 모델이 "이건 kick-off 같은데?" 하고 고민할 여지가 없다.
#
# 두 번째 분기(이탈): 진입은 시켜도 그 뒤 대화가 새는 건 못 막는다. stage가 spec/plan인데
# 구현 의도 프롬프트가 오면 세션 1회만 알린다. **차단하지 않는다** — §6-1 소프트 개입 우선.
#
# 스킬 이름을 부르지 않고 파일 경로를 준다. `disable-model-invocation`이 걸린 스킬은 모델의
# Skill 목록에서 빠질 수 있고, 없는 스킬을 부르는 훅은 조용히 죽는다(#22·#28의 전례).

set -u

# 기본값에 괄호·파이프가 들어가므로 확장 전체를 반드시 큰따옴표로 감싼다.
# 안 감싸면 dash 계열 sh가 `(` 를 문법 오류로 읽는다.
STATE_FILE="${KICKOFF_STATE_FILE:-.claude/kickoff.local.md}"
# 하이픈으로 이어진 파일명(sdd-kickoff-guard.sh, kickoff-guard.sh) 안의 매치는 제외한다.
KEYWORD_PATTERN="${KICKOFF_KEYWORD_PATTERN:-(^|[^A-Za-z-])(kickoff|kick-off)([^A-Za-z-]|\$)|킥오프}"
DRIFT_PATTERN="${KICKOFF_DRIFT_PATTERN:-구현|코딩|코드 짜|바로 만들|implement}"

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
[ -n "$prompt" ] || exit 0

skill_path="${CLAUDE_PLUGIN_ROOT:-woobin-harness}/skills/kick-off/SKILL.md"

emit() {
  jq -cn --arg ctx "$1" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
  exit 0
}

# ── 분기 A: 키워드. 슬래시 호출은 이미 스킬이 뜨므로 건너뛴다.
case "$prompt" in
  /kick-off*|/woobin-harness:kick-off*) ;;
  *)
    if printf '%s' "$prompt" | grep -qiE "$KEYWORD_PATTERN"; then
      emit "[kick-off] 프롬프트에 킥오프 키워드가 있습니다.

\`${skill_path}\` 를 Read하고 그 지시를 따르세요. **스킬 이름으로 호출하지 말고 파일을 직접 읽으세요** —
이 스킬은 사람만 부를 수 있게 막혀 있어(\`disable-model-invocation\`) 모델의 Skill 목록에 없을 수 있습니다.

사용자가 킥오프를 뜻한 게 아니라면(예: 이 훅 자체를 고치는 중) 한 줄로 밝히고 그냥 진행하세요."
    fi
    ;;
esac

# ── 분기 B: 이탈. 상태 파일이 살아 있고 stage가 spec/plan인데 구현 의도가 왔다.
[ -f "$STATE_FILE" ] || exit 0
grep -qE '^active:[[:space:]]*true[[:space:]]*$' "$STATE_FILE" || exit 0
stage=$(sed -n 's/^stage:[[:space:]]*\([a-z][a-z]*\).*/\1/p' "$STATE_FILE" | head -1)
case "$stage" in
  spec) next="스펙을 굳히는 중입니다(\`interview\`). 결정 원장의 미결이 비기 전에는 코드로 넘어가지 마세요." ;;
  plan) next="플랜을 쓰는 중입니다(\`writing-plans\`). 플랜이 저장되기 전에는 코드로 넘어가지 마세요." ;;
  *) exit 0 ;;
esac
printf '%s' "$prompt" | grep -qiE "$DRIFT_PATTERN" || exit 0

# 세션당 1회.
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
marker_dir="${TMPDIR:-/tmp}/claude-kickoff-drift"
if [ -n "$session_id" ]; then
  marker="$marker_dir/$session_id"
  [ -e "$marker" ] && exit 0
  mkdir -p "$marker_dir" 2>/dev/null
  : > "$marker" 2>/dev/null
fi

emit "[kick-off 이탈 알림] ${STATE_FILE} 의 stage가 \`${stage}\` 입니다.

${next}

지금 단계를 끝냈다면 ${STATE_FILE} 의 stage를 다음 값으로 갱신하고 계속하세요
(\`spec\` → \`plan\` → \`impl\`). 작업이 끝났으면 \`active: false\`로 바꾸면 이 알림은 멈춥니다.

이 알림은 세션당 한 번만 뜹니다. 차단하지 않으니 판단은 당신이 하세요 — 사용자가 의도적으로
지금 코드를 건드리라고 했다면 한 줄로 밝히고 그대로 진행하세요."
