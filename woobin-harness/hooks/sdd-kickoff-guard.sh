#!/bin/sh
# UserPromptSubmit — 플랜 구현 킥오프 프롬프트를 감지해 오케스트레이터가 플랜을 통째로 Read하지 않게 한다.
# (파일명의 "SDD"와 아래 주석의 "SDD"는 2026-07 실측 당시 세션 종류를 가리키는 역사적 표기다.
#  subagent-driven-development 스킬은 현재 설치돼 있지 않다 — 절약 근거는 스킬과 무관하게 유효하다.)
#
# 왜: 2026-07-30 실측(SDD 세션 2개, $52.64) — /clear 경계는 잘 작동했는데도 재시작 floor가
# 93~122k였다. 최대 항목이 플랜 문서 통독(1,650행 = 48k tok, Read 2회)이고, floor는
# 오케스트레이터의 매 요청에 cache read로 재청구된다(ec809b30: 158요청 × 141k = 22.8M = $11.39).
# plan-saved-session-boundary.sh가 큰 플랜을 분할 저장시키지만(②), 이미 존재하는 단일 파일
# 플랜에는 소급 적용되지 않는다 — 그 경우 결정론적 명령으로 목차·제약만 확보하게 한다(①).
#
# 소프트 개입: 차단하지 않고 additionalContext만 주입한다. 세션당 1회.

set -u

SPLIT_MIN_LINES=${PLAN_SPLIT_MIN_LINES:-500}
# docs/ 아래 플랜이 사는 디렉터리 이름(정규식 alternation). 이름이 바뀌면 여기만 고친다.
PLAN_DOCS_DIRS=${PLAN_DOCS_DIRS:-superpowers|woobin_plan}

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
[ -n "$prompt" ] || exit 0

# 킥오프 신호: 구현 착수 의도 + superpowers 플랜 경로(아래 24행).
# 구 SDD 스킬명도 계속 매칭한다 — 옛 핸드오프 문구를 그대로 붙여넣는 프롬프트가 남아 있다.
echo "$prompt" | grep -qiE '구현|진행|실행|착수|implement|execute|subagent-driven-development|\bsdd\b' || exit 0
target=$(echo "$prompt" | tr ' \t"'"'"'`' '\n\n\n\n\n' | grep -m1 -E "docs/(${PLAN_DOCS_DIRS})/plans/")
[ -n "$target" ] || exit 0
target=$(printf '%s' "$target" | sed 's:/*$::')

# 세션당 1회.
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
marker_dir="${TMPDIR:-/tmp}/claude-sdd-kickoff"
if [ -n "$session_id" ]; then
  key=$(printf '%s|%s' "$session_id" "$target" | shasum | cut -d' ' -f1)
  marker="$marker_dir/$key"
  [ -e "$marker" ] && exit 0
  mkdir -p "$marker_dir" 2>/dev/null
  : > "$marker" 2>/dev/null
fi

if [ -d "$target" ]; then
  # ② 분할된 플랜 — overview만 읽게 한다.
  body="플랜이 이미 분할되어 있습니다: ${target}/

- \`${target}/00-overview.md\` **만** Read하세요. 배경·Global Constraints·태스크 목록·기각 대안이 여기 있습니다.
- \`task-N.md\`는 **오케스트레이터가 읽지 마세요.** implementer 서브에이전트에 경로(\`${target}/task-N.md\`)로 넘기면
  그 에이전트가 자기 컨텍스트에서 읽습니다. 본문을 요약해 프롬프트에 넣지 말고 경로만 주세요.
- pre-flight conflict scan은 overview의 태스크 목록·Global Constraints로 수행하세요.
  특정 태스크의 세부가 정말 필요하면 그 \`task-N.md\`만 읽고, 다 읽지는 마세요."
elif [ -f "$target" ]; then
  lines=$(wc -l < "$target" 2>/dev/null | tr -d ' ')
  [ -n "$lines" ] || lines=0
  chars=$(wc -c < "$target" 2>/dev/null | tr -d ' ')
  [ -n "$chars" ] || chars=0
  [ "$lines" -lt "$SPLIT_MIN_LINES" ] && exit 0   # 작은 플랜은 통독해도 floor 부담이 작다
  est_tok=$((chars / 1550))
  body="플랜이 단일 파일이고 큽니다: ${target} (${lines}행, 약 ${est_tok}k 토큰)

**파라미터 없는 Read로 통째로 올리지 마세요.** 오케스트레이터 컨텍스트는 SDD 전 구간의 매 요청에
cache read로 재청구됩니다(실측: 1,650행 플랜 통독 → floor 93~122k → 세션당 \$2~11).
아래 순서로 필요한 만큼만 확보하세요:

1. 목차·태스크 목록: \`grep -nE '^#{1,4} ' ${target}\`
2. 제약: \`sed -n '/Global Constraints/,/^## /p' ${target}\` (해당 절이 없으면 \`sed -n '1,120p' ${target}\`)
3. 태스크 본문은 오케스트레이터 컨텍스트에 올리지 마세요. 해당 구간만 파일로 잘라
   (\`sed -n '<시작>,<끝>p' ${target} > /tmp/task-N.md\`) 서브에이전트에 **경로만** 넘기세요.
   행 번호는 1번의 grep 결과에서 나옵니다.
4. pre-flight conflict scan은 목차 + 제약 + 각 태스크의 대상 파일·완료 판정 줄로 수행하세요.
   그래도 모순 판단이 안 되는 구간만 \`Read(offset, limit)\`으로 부분 확인하세요.
5. (선택) 이 플랜을 앞으로 여러 세션에서 다시 쓸 거라면, 지금 \`${target%.md}/00-overview.md\` +
   \`task-N.md\`로 분할해두면 다음 킥오프부터는 위 우회가 불필요해집니다."
else
  body="프롬프트가 가리킨 플랜 경로를 이 훅이 확인하지 못했습니다: ${target}

플랜이 500행을 넘는다면 통째로 Read하지 말고, 목차(\`grep -nE '^#{1,4} '\`)와 Global Constraints만 확보한 뒤
태스크 본문은 \`sed -n\`으로 잘라 파일화해 서브에이전트에 경로로 넘기세요."
fi

ctx="[플랜 킥오프 가드] ${body}

예외 — 아래에 해당하면 이 지침을 무시하고 통독하되, 이유를 한 줄로 밝히세요:
- 태스크가 1~2개뿐이라 오케스트레이터 요청 수가 애초에 적다
- 플랜이 짧아(500행 미만) 통독 비용이 무의미하다
- 사용자가 전체 통독을 명시적으로 요구했다"

jq -cn --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
