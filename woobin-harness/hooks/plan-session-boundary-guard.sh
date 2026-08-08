#!/bin/sh
# UserPromptSubmit — 플랜 작성에 **들어가기 전** 세션 경계를 상기시킨다.
#
# 왜: plan-saved-session-boundary.sh는 플랜을 저장한 **뒤**(PostToolUse Write) 경계를 알린다.
# 그런데 비싼 구간은 그 앞이다 — 설계 대화로 이미 부푼 컨텍스트 위에서 플랜용 코드베이스 탐색을
# 수십 번 돌리는 구간.
#
# 2026-08-03 실측(94aff112): 디자인 확정까지 대화한 뒤 "writing-plans 가자" 한 줄로 이어서 진행했고,
# 그 구간만 41요청 × 평균 198k ctx = $8.16였다. 그 41요청 중 45개가 grep/sed 코드베이스 탐색이었다
# (grep -rn "dept-hold\|DeptHold" backend/app, cat useDeptHoldTable.ts 등) — 전부 서브에이전트가
# 할 수 있는 일이고, 새 세션(floor ~46k)에서 했다면 같은 작업이 대략 1/3 비용이었다.
#
# 소프트: 차단하지 않고 additionalContext만 주입한다. 세션당 1회.
# 플랜 구현 킥오프 프롬프트는 sdd-kickoff-guard.sh 담당이라 여기서는 제외한다.

set -u

CTX_MIN=${PLAN_BOUNDARY_CTX_THRESHOLD:-120000}
# docs/ 아래 플랜이 사는 디렉터리 이름(정규식 alternation). 이름이 바뀌면 여기만 고친다.
PLAN_DOCS_DIRS=${PLAN_DOCS_DIRS:-superpowers|woobin_plan}

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
[ -n "$prompt" ] || exit 0

# 구현 킥오프는 다른 훅 담당 — 프롬프트에 플랜 경로가 있으면 킥오프다(스킬명에 의존하지 않는다).
echo "$prompt" | grep -qE "docs/(${PLAN_DOCS_DIRS})/plans/" && exit 0
echo "$prompt" | grep -qiE 'subagent-driven-development|\bsdd\b' && exit 0

# 플랜 작성 진입 신호.
echo "$prompt" | grep -qiE 'writing-plans|플랜 작성|플랜 짜|플랜 가자|플랜으로 가|계획 작성|계획 세워|구현 계획|implementation plan' || exit 0

# 현재 컨텍스트 크기 = transcript의 마지막 assistant usage (ctx-warn-statusline.sh와 동일 방식).
ctx=0
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$tp" ] && [ -f "$tp" ]; then
  ctx=$(tail -n 40 "$tp" 2>/dev/null | jq -rR '
      fromjson? // empty
      | select(.type == "assistant")
      | .message.usage // empty
      | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)
    ' 2>/dev/null | tail -n 1)
  case "$ctx" in ''|*[!0-9]*) ctx=0 ;; esac
fi
[ "$ctx" -ge "$CTX_MIN" ] || exit 0

# 세션당 1회.
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
if [ -n "$session_id" ]; then
  marker_dir="${TMPDIR:-/tmp}/claude-plan-entry-boundary"
  marker="$marker_dir/$session_id"
  [ -e "$marker" ] && exit 0
  mkdir -p "$marker_dir" 2>/dev/null
  : > "$marker" 2>/dev/null
fi

ctx_k=$((ctx / 1000))

ctx_msg="[플랜 진입 경계 알림] 현재 컨텍스트가 ${ctx_k}k인 상태에서 플랜 작성에 들어가려 합니다.

플랜 작성은 코드베이스 탐색(grep·Read·테스트 구조 확인)이 수십 회 붙는 구간입니다.
그 탐색 전부가 지금의 ${ctx_k}k 위에서 돌면 요청마다 그 컨텍스트를 cache read로 다시 청구합니다.
(2026-08-03 실측 94aff112: 설계 대화에 이어서 플랜을 쓴 구간이 41요청 × 평균 198k = \$8.16.
 같은 작업을 새 세션 floor(~46k)에서 했다면 대략 1/3)

**비싼 항은 인터뷰 대화가 아니라 탐색입니다** — 위 실측의 41요청 중 45개가 메인 루프의 grep/sed였습니다.
그 항만 빼면 이 세션에서 계속해도 됩니다. 순서대로 하세요:

1. **코드베이스 조사를 전부 \`Explore\` 서브에이전트에 위임하세요.** 파일 목록·심볼 위치·기존 패턴 확인을
   메인 루프에서 grep/Read로 훑지 않습니다. \`CLAUDE.md\`의 예외 3종(3파일 이하 / 편집 루프 검증 /
   스타일 원문 모방)에만 직접 읽습니다. 이것만 지키면 \`/clear\` 없이 플랜을 써도 됩니다.
2. 위임이 어려운 성격이 많아 메인이 계속 직접 훑어야 한다면, 그때만 경계를 세웁니다 —
   설계 결론을 \`docs/woobin_plan/specs/\`에 저장하고 \`/clear\` 후
   \"<스펙 경로> 기준으로 writing-plans 진행해줘\"로 이어갑니다.
3. 어느 쪽이든 **플랜 저장 뒤에 \`/clear\`가 한 번** 들어갑니다(구현 세션 진입).
   그게 이 워크플로의 유일한 필수 경계입니다.

예외 — 아래에 해당하면 이 알림을 무시하고 계속 진행하되, 그 이유를 한 줄로 밝히세요:
- 사용자가 이 세션에서 계속하라고 명시했다
- 지금 컨텍스트에만 있고 문서화되지 않은 결정이 많아 경계를 넘으면 되묻는 비용이 더 크다
- 플랜이 태스크 1~2개짜리다
- 지금 플랜을 쓰는 게 아니라 워크플로·설정을 논의하는 중이다"

jq -cn --arg ctx "$ctx_msg" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
