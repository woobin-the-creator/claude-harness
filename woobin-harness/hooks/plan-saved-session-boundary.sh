#!/bin/sh
# PostToolUse(Write) — superpowers 플랜 문서가 저장되면 구현 세션 경계를 상기시키고,
# 큰 플랜은 오케스트레이터가 통째로 읽지 못하도록 분할 저장을 지시한다.
#
# ⚠️ 아래 주석의 "SDD"는 2026-07 실측 당시의 세션 종류를 가리키는 역사적 표기다.
# subagent-driven-development 스킬은 현재 설치돼 있지 않으므로(superpowers 플러그인 비활성),
# 사용자에게 안내하는 킥오프 문장에는 그 스킬명을 넣지 않는다. 절약 근거 자체는 스킬과 무관하게 유효하다.
#
# 왜(경계): SDD는 플랜 단계에서 쌓인 컨텍스트(실측 중앙값 ~200k)를 그대로 물려받고,
# 이후 평균 95요청이 그걸 매번 캐시 리드로 재청구한다. 2026-07-29 실측(14일, SDD 세션 18개)에서
# 이 죽은 컨텍스트가 SDD 단계 캐시 비용의 44%($107.28/$242.65)였다.
#
# 왜(분할): 2026-07-30 실측 — 경계는 잘 끊겼는데도 SDD 세션이 비쌌다.
# /clear 후 재시작 floor가 가정했던 45k가 아니라 93~122k였고, 그 중 최대 항목이
# **플랜 문서 통독 48k tok**(1,650행/74KB, Read 2회)이었다. floor는 오케스트레이터의
# 모든 요청에 cache read로 재청구되므로(0234b399: 37요청 × 120k = 4.5M),
# "부분만 읽어라"는 소프트 지시로는 못 막는다 — 읽을 파일 자체를 작게 만들어야 한다.
#
# 단, 플랜 문서가 자기완결적이지 않으면 새 세션이 되묻느라 절약분이 날아간다 —
# 그래서 경계를 넘기 전에 자기완결성 점검을 먼저 시킨다.
#
# 2026-08-21 — writing-plans 스킬이 처음부터 plans/<slug>/ 로 분할 저장하도록 바뀌었다(같은 문서를
# 두 번 쓰지 않으려고). 그래서 이 훅도 분할 산출물에 발화해야 한다: `00-overview.md` 1개에만 울리고
# `task-N.md`는 침묵하며, 그 경우 분할 지시 대신 자기완결성 점검·모드 추천만 낸다.
#
# 2026-08-27 — 게이트가 0개인 플랜은 세션 경계를 넘지 않는다. 플랜 문서 리뷰어가 낸 게이트 수가
# 라우팅 입력이고, 0이면 이 세션이 그대로 구현까지 굴린다(모드 ①·②b·③). 1개 이상이면 종전대로
# ②a 킥오프 블록을 낸다 — 서브에이전트는 AskUserQuestion 이 제거돼 게이트에서 물을 수가 없어서,
# 무인으로 보내면 중단이 아니라 정지가 된다. 아래 본문은 세 갈래 최종 결론(0개/1개↑/1개↑+③)만
# 요약하고, 그 근거·표·상세 절차는 $MODES_FILE 이 소유한다(§9-1 이중 소유 회피) — ②a 킥오프의
# `claude` 커맨드도 $MODES_FILE에서 그대로 뽑아 쓴다, 하드코딩하지 않는다.

set -u

SPLIT_MIN_LINES=${PLAN_SPLIT_MIN_LINES:-500}
# 모드 정의 파일: 명시 override > 플러그인 동봉본 > ~/.claude 사본.
# 플러그인(woobin-harness)으로 설치되면 CLAUDE_PLUGIN_ROOT가 채워지므로 동봉본을 쓴다.
if [ -n "${PLAN_EXEC_MODES_FILE:-}" ]; then
  MODES_FILE=$PLAN_EXEC_MODES_FILE
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/plan-exec-modes.md" ]; then
  MODES_FILE=$CLAUDE_PLUGIN_ROOT/plan-exec-modes.md
else
  MODES_FILE=$HOME/.claude/plan-exec-modes.md
fi
# 리뷰어 프롬프트는 항상 $MODES_FILE과 같은 트리에 있다(플러그인 레이아웃: <root>/plan-exec-modes.md,
# <root>/skills/writing-plans/plan-document-reviewer-prompt.md) — $CLAUDE_PLUGIN_ROOT를 따로 참조하면
# 그 변수가 비어 있는 override·~/.claude 폴백 경로에서 존재하지 않는 경로가 된다.
REVIEWER_PROMPT="$(dirname "$MODES_FILE")/skills/writing-plans/plan-document-reviewer-prompt.md"
# docs/ 아래 플랜·스펙이 사는 디렉터리 이름(정규식 alternation). 이름이 바뀌면 여기만 고친다.
# 전환기 동안 옛 이름을 남겨둔다 — 아직 옛 경로인 브랜치·워크트리에서 훅이 조용히 죽지 않게.
PLAN_DOCS_DIRS=${PLAN_DOCS_DIRS:-superpowers|woobin_plan}

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$path" ] || exit 0

# 플랜 경로만 — SDD 작업 파일(.superpowers/sdd/)이나 일반 문서는 제외.
# case 글롭은 변수 alternation을 못 받으므로(| 가 확장 전에 파싱됨) grep으로 판정한다.
printf '%s' "$path" | grep -qE "/docs/(${PLAN_DOCS_DIRS})/plans/.*\.md$" || exit 0

# 분할 레이아웃(plans/<이름>/…)에서는 00-overview.md 하나에만 발화한다.
# writing-plans 스킬은 2026-08-21부터 **처음부터** plans/<slug>/ 로 쓴다. 예전처럼 여기서
# 통째로 exit하면 그 경로에서는 훅이 한 번도 안 울려서 R1의 자기완결성 4항목 점검과
# 모드 추천이 통째로 사라진다 — 스킬 없이 플랜을 쓰는 세션에는 이 훅이 유일한 발동원이다.
# task-N.md는 계속 침묵한다(플랜 하나당 N번 울릴 이유가 없다).
presplit=0
if printf '%s' "$path" | grep -qE "/docs/(${PLAN_DOCS_DIRS})/plans/.*/.*\.md$"; then
  printf '%s' "$path" | grep -qE "/00-overview\.md$" || exit 0
  presplit=1
fi

# 같은 플랜을 여러 번 Write해도 세션당 한 번만 알린다.
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
marker_dir="${TMPDIR:-/tmp}/claude-plan-boundary"
if [ -n "$session_id" ]; then
  key=$(printf '%s|%s' "$session_id" "$path" | shasum | cut -d' ' -f1)
  marker="$marker_dir/$key"
  [ -e "$marker" ] && exit 0
  mkdir -p "$marker_dir" 2>/dev/null
  : > "$marker" 2>/dev/null
fi

lines=$(wc -l < "$path" 2>/dev/null | tr -d ' ')
[ -n "$lines" ] || lines=0
chars=$(wc -c < "$path" 2>/dev/null | tr -d ' ')
[ -n "$chars" ] || chars=0
est_tok=$((chars / 1550))   # k 토큰. 한글 혼용 문서 실측 비율 1.55자/tok (74,448자 ≈ 48k tok)

plan_dir=$(printf '%s' "$path" | sed 's/\.md$//')

if [ "$presplit" -eq 1 ]; then
  # 이미 분할된 채로 저장됐다 — 분할 지시는 불필요하고, 킥오프 대상은 플랜 디렉터리다.
  split_step="   (이미 \`00-overview.md\` + \`task-N.md\` 로 분할 저장돼 있습니다. 분할 불필요 —
   overview가 400행/15,000자 이내인지, 태스크 목록 번호가 실제 \`task-N.md\` 파일과 일치하는지만 확인하세요.)"
  kickoff_target=$(dirname "$path")
  step_n=2
elif [ "$lines" -ge "$SPLIT_MIN_LINES" ]; then
  split_step="2. **이 플랜을 분할 저장하세요** — 현재 ${lines}행(${chars}자, 약 ${est_tok}k 토큰)입니다.
   오케스트레이터가 이걸 통째로 Read하면 그 토큰이 구현 세션 전 구간의 **매 요청**에 cache read로 재청구됩니다
   (2026-07-30 실측: 1,650행 플랜 = 48k tok, 오케스트레이터 floor 93~122k, 세션당 \$2~11).

   레이아웃 (디렉터리 이름은 원본 파일명과 동일):
   - \`${plan_dir}/00-overview.md\` — 배경, Global Constraints, 태스크 목록(번호+제목+대상 파일+완료 판정 명령만),
     기각한 대안과 사유. **400행/15,000자 이내로 유지하세요.** 오케스트레이터가 읽는 유일한 파일입니다.
   - \`${plan_dir}/task-1.md\`, \`task-2.md\`, … — 각 태스크의 본문 전체(파일 경로, 코드, 테스트, 완료 판정).
     implementer 서브에이전트가 읽는 유일한 파일입니다. 번호는 overview의 태스크 목록과 정확히 일치시키세요.
   - 원본 \`${path}\` 는 5행 이내 스텁으로 교체하세요:
     \"이 플랜은 \`${plan_dir}/\` 로 분할되었습니다. 오케스트레이터는 \`00-overview.md\`만 읽고,
     태스크 본문(\`task-N.md\`)은 서브에이전트에 경로로 넘깁니다.\"

   분할 시 주의: overview에 Global Constraints와 각 태스크의 완료 판정 명령이 빠지면
   구현 세션의 사전 충돌 점검이 무력해져 잘못된 순서·중복 편집으로 절약분이 날아갑니다.
   태스크 간 순서 의존성도 overview에 한 줄로 적으세요.
"
  kickoff_target="$plan_dir"
  step_n=3
else
  split_step="   (${lines}행 — 분할 임계(${SPLIT_MIN_LINES}행) 미만이라 통독해도 floor 부담이 작습니다. 분할 불필요.)"
  kickoff_target="$path"
  step_n=2
fi

if [ ! -f "$MODES_FILE" ]; then
  # 모드 정의 파일이 없으면 모드 선택 단계를 통째로 생략한다 — 없는 파일을 읽으라고 지시하지 않는다.
  mode_step="${step_n}. 사용자에게 안내하세요: \"\`/clear\` 후 \`${kickoff_target} 플랜으로 구현 진행해줘\`\"
$((step_n+1)). 그리고 이번 턴을 종료하세요. 사용자가 /clear를 실행할 차례입니다."
else
# ②a launch flag는 여기서 하드코딩하지 않는다 — 모드 파일 "## ② 절약" 절 첫 코드펜스에서 그대로 뽑는다.
a_launch_cmd=$(awk '
  /^## ② 절약/ { insec=1 }
  insec && /^```/ { if (infence) exit; infence=1; next }
  insec && infence { print; next }
' "$MODES_FILE")
[ -n "$a_launch_cmd" ] || a_launch_cmd="claude --effort medium --model sonnet"

mode_step="${step_n}. **플랜 문서 리뷰어를 먼저 띄우세요.** 프롬프트 템플릿은
   \`${REVIEWER_PROMPT}\` 에 있습니다.
   general-purpose 서브에이전트로 띄우고, 지적을 플랜 문서에 반영한 뒤 다음으로 가세요.
   리뷰어가 내는 \`**Gates:** N\`(사람 확인이 필요한 지점의 수)이 아래 라우팅의 입력입니다.

$((step_n+1)). **모드를 추천하고 게이트 수로 라우팅하세요.** 정의는 \`${MODES_FILE}\` 에 있습니다 — 지금 읽으세요.
   모드 추천의 유일한 근거는 방금 쓴 overview의 **태스크 간 순서 의존성**입니다. 그 판단은 지금 이 세션만 할 수 있습니다.
   - 파일을 공유하지 않는 트랙이 2개 이상 → ① 속도
   - 의존성 체인이거나 같은 파일 공유 → ② 절약  ← 대부분 여기
   - 되돌리기 비싼 작업(마이그레이션·prod 배포·자동 게이트가 못 잡는 UI) → ③ 최고 퀄리티

   그리고 게이트 수로 갈립니다. 상세 표와 절차는 모드 파일이 소유합니다:
   - **게이트 0개** → ①·②b·③ 그대로 **이 세션에서 full-auto로 실행**합니다. 킥오프 블록을 내지 마세요.
   - **게이트 1개 이상** → **②a**. 아래 킥오프를 출력하고 턴을 종료하세요.
   - **게이트 1개 이상 + ③ 성립 조건** → ③를 유지한 채 이 세션에서 실행하고, 게이트에서 멈춰 사용자에게 올리세요.

   ②a로 갈 때만 출력할 킥오프:

   \"이 세션을 종료(\`/exit\`)하고 이렇게 다시 띄우세요:
   \`\`\`
   ${a_launch_cmd}
   \`\`\`
   그리고 첫 프롬프트:
   \`\`\`
   ${kickoff_target} 플랜으로 구현 진행해줘 — 모드 ②a(${MODES_FILE})
   \`\`\`\"

   \`--effort\`는 **그 세션에만** 적용됩니다(문서: \"set it for a single session\").
   \`/effort\`와 달리 settings.json을 건드리지 않으므로 끝나고 되돌릴 것이 없습니다 — 되돌리기 안내를 붙이지 마세요.

$((step_n+2)). full-auto로 갈 경우 **이 턴을 종료하지 말고** 모드 파일의 full-auto 절차대로 계속하세요:
   \`plan/<slug>\` 브랜치 · 플랜 커밋 · draft PR → 레이어마다 구현자 1개 순차 → 커밋 → \`plan-reviewer\` → push."
fi

ctx="[세션 경계 알림] 구현 계획 문서가 저장되었습니다: ${path}

이 문서는 영속화되었으므로, 지금 이 세션의 스펙·플래닝 대화는 구현에 더 이상 필요하지 않습니다.
**아래 점검과 리뷰를 끝내기 전에는 구현을 시작하지 마세요.**

다음 순서로 진행하세요:

1. 플랜 자기완결성을 먼저 점검하고, 미흡한 항목은 지금 문서에 채워 넣으세요.
   컨텍스트가 살아있는 지금이 아니면 채울 수 없는 정보입니다.
   - 모든 파일 참조가 절대/repo 상대 경로인가 (함수명·컴포넌트명만 적힌 곳이 없는가)
   - 검토했다가 기각한 대안과 그 사유가 적혀 있는가 (없으면 새 세션이 같은 대안을 다시 제안한다)
   - '위에서 논의한 대로', '앞서 정한' 같은 대화 참조가 0건인가
   - 각 태스크의 완료 판정 방법(실행할 테스트·명령)이 적혀 있는가
${split_step}
${mode_step}

예외 — 아래에 해당하면 이 알림을 무시하고 계속 진행하되, 그 이유를 한 줄로 밝히세요:
- 사용자가 이 세션에서 계속하라고 명시했다
- 플랜이 태스크 1~2개짜리라 구현 요청 수가 애초에 적다
- 이미 /clear 직후라 현재 컨텍스트가 이미 얇다"

jq -cn --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
