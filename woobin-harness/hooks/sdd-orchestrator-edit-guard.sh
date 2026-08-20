#!/bin/sh
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit) — 메인 루프가 소스를 직접 고치는 것을 1회 막는다.
#
# 두 가지 모드로 발화한다.
#
# [A] SDD 모드 — SDD workspace(<repo>/.superpowers/sdd/*/progress.md)가 있을 때.
# 왜: 2026-07-30 실측 — 같은 날 같은 스킬인데 태스크당 메인 루프 요청이 5.3회(0234b399) vs 17.6회(ec809b30)였다.
# 차이의 정체는 후자의 오케스트레이터가 리뷰 findings를 **자기 컨텍스트에서** 처리한 것:
# Edit 9회 + pytest 11회 + tsc 8회 + grep/ls 49회를 130~271k 컨텍스트에서 돌렸다.
# 같은 수정을 서브에이전트(80k 컨텍스트)에 넘기면 턴당 비용이 1/2~1/3이고,
# 오케스트레이터 컨텍스트도 안 자라서 이후 모든 턴이 싸진다. 추정 낭비 ~$4/세션.
#
# [B] 대량 편집 모드 — SDD 원장이 없어도 컨텍스트가 크고 편집이 누적됐을 때.
# 왜: 2026-08-03 실측(94aff112, $40.55/274요청) — 당시 디자인 시안 스킬(현 show-design-sample)이
# "시안마다 에이전트 1개를 동시에 띄운다"고 규정하는데 서브에이전트 호출이 0회였다. 메인 루프 opus가
# Edit 66 + Write 30 + Bash 120을 직접 처리하며 컨텍스트가 41k→348k로 자랐고, 비용의 72%가
# 그 컨텍스트를 274번 다시 읽은 cache read($29.1)였다. 같은 성격의 UI 작업을 sonnet
# 서브에이전트가 한 대조군(bc9749a0)은 태스크당 $1.70~2.71이었다. 추정 낭비 ~$20/세션.
# [A]는 원장이 있을 때만 발화하므로 디자인·프로토타이핑 구간은 무방비였다 — 그 구멍을 [B]가 막는다.
#
# 소프트: 모드별로 세션당 1회만 deny(이유 전달)하고, 그 다음부터는 통과시킨다.
# 오탐 시 재시도로 즉시 진행되고, 정말 필요한 잔손질을 영구히 막지 않는다.
#
# 서브에이전트(agent_id 있음)는 두 모드 모두 대상이 아니다 — implementer가 코드를 고치는 건 정상 경로다.

set -u

# [B] 임계값
BULK_CTX_MIN=${BULK_EDIT_CTX_THRESHOLD:-150000}
BULK_EDIT_MIN=${BULK_EDIT_COUNT_THRESHOLD:-15}
# docs/ 아래 플랜·스펙이 사는 디렉터리 이름(정규식 alternation). 이름이 바뀌면 여기만 고친다.
PLAN_DOCS_DIRS=${PLAN_DOCS_DIRS:-superpowers|woobin_plan}

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

# 서브에이전트의 편집은 정상 — 메인 루프만 본다.
agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
[ -z "$agent_id" ] || exit 0

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
[ -n "$path" ] || exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$(pwd)
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0

# /tmp → /private/tmp 처럼 심링크로 접두사가 갈리면 경로 비교가 조용히 실패한다. 양쪽을 물리 경로로 맞춘다.
phys_dir() { (cd "$1" 2>/dev/null && pwd -P) }
root_phys=$(phys_dir "$root"); [ -n "$root_phys" ] && root="$root_phys"
path_parent=$(phys_dir "$(dirname "$path")")
[ -n "$path_parent" ] && path="$path_parent/$(basename "$path")"

# 오케스트레이터가 정당하게 쓰는 파일은 제외: SDD workspace, 플랜·스펙 문서, repo 밖 경로.
# 플랜·스펙 경로는 PLAN_DOCS_DIRS로 파라미터화 — case 글롭은 변수 alternation을 못 받으므로 grep으로 뺀다.
printf '%s' "$path" | grep -qE "/docs/(${PLAN_DOCS_DIRS})/(plans|specs)/" && exit 0
case "$path" in
  "$root"/.superpowers/*) exit 0 ;;
  "$root"/*) ;;
  *) exit 0 ;;
esac

session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
rel=$(printf '%s' "$path" | sed "s|^$root/||")

emit_deny() {
  jq -cn --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# 모드별 세션 1회 마커. 이미 발화한 모드면 통과.
marker_dir="${TMPDIR:-/tmp}/claude-sdd-edit-guard"
fire_once() {  # $1 = 모드 접미사. 이미 발화했으면 1을 리턴.
  [ -n "$session_id" ] || return 0
  m="$marker_dir/$session_id.$1"
  [ -e "$m" ] && return 1
  mkdir -p "$marker_dir" 2>/dev/null
  : > "$m" 2>/dev/null
  return 0
}

# ─── [A] SDD 모드 ─────────────────────────────────────────────────────────────
ledger=""
for f in "$root"/.superpowers/sdd/*/progress.md; do
  [ -f "$f" ] && ledger="$f" && break
done

if [ -n "$ledger" ]; then
  fire_once sdd || exit 0
  emit_deny "[SDD 오케스트레이터 편집 가드 — 세션 1회 경고] \`${rel}\` 을 직접 수정하려 했습니다.

SDD 실행 중(원장: ${ledger#$root/})입니다. 리뷰 findings 수정·테스트 재실행·타입 체크는
**implementer 서브에이전트에 넘기세요** — 지금 이 컨텍스트는 SDD 전 구간의 매 요청에 재청구되므로
같은 수정이 서브에이전트(약 80k)보다 2~3배 비싸고, 편집·테스트 출력이 쌓여 이후 모든 턴이 더 비싸집니다.
(2026-07-30 실측: 오케스트레이터가 직접 fix 라운드를 처리한 세션은 태스크당 17.6요청 / 그렇지 않은 세션은 5.3요청)

권장: 해당 태스크의 implementer를 재개(resume)하거나, findings를 담은 fix 브리프를 파일로 만들어
새 서브에이전트에 경로로 넘기고, 검증(pytest·tsc)도 그 에이전트가 실행해 결과 요약만 회수하세요.

그래도 오케스트레이터가 직접 고쳐야 하는 상황(한 줄 오타, 서브에이전트 스폰이 더 비싼 경우,
SDD 종료 후 정리 작업)이면 같은 편집을 다시 시도하세요 — 이번 세션에서는 다시 막지 않습니다."
fi

# ─── [B] 대량 편집 모드 ───────────────────────────────────────────────────────
# 세션 누적 메인 루프 편집 횟수.
count=0
if [ -n "$session_id" ]; then
  count_dir="${TMPDIR:-/tmp}/claude-mainloop-edits"
  mkdir -p "$count_dir" 2>/dev/null
  cfile="$count_dir/$session_id"
  count=$(cat "$cfile" 2>/dev/null)
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  count=$((count + 1))
  printf '%s' "$count" > "$cfile" 2>/dev/null
fi
[ "$count" -ge "$BULK_EDIT_MIN" ] || exit 0

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
[ "$ctx" -ge "$BULK_CTX_MIN" ] || exit 0

fire_once bulk || exit 0

ctx_k=$((ctx / 1000))
emit_deny "[대량 편집 가드 — 세션 1회 경고] 메인 루프에서 ${count}번째 편집(\`${rel}\`)이고, 현재 컨텍스트는 ${ctx_k}k입니다.

이 규모면 **손을 서브에이전트로 옮길 시점**입니다. 지금 이 컨텍스트는 남은 모든 요청에 cache read로
재청구되고, 편집·빌드·테스트 출력이 쌓일수록 요청당 단가가 계속 올라갑니다.
(2026-08-03 실측 94aff112: 디자인 시안을 메인 루프에서 직접 만들다 컨텍스트 41k→348k, 274요청 중
cache read만 58.2M = \$29.1 = 세션 비용의 72%. 같은 성격 작업을 sonnet 서브에이전트가 한 대조군은 태스크당 \$1.70~2.71)

권장 — 지금 하는 일이 아래 중 하나라면 해당 경로로 전환하세요:
- **디자인 시안 제작** → show-design-sample 규정대로 메인 루프는 편집하지 않습니다.
  N<=3은 Sonnet 빌더 1개, N>=4 또는 명시적 병렬 요청은 시안별 빌더를 사용합니다.
- **플랜의 태스크 구현** → 태스크 본문(\`task-N.md\`)을 implementer 서브에이전트에 **경로로** 넘기고, 메인 루프는 리뷰·판정만 하세요.
- **탐색 후 수정** → 조사는 Explore 서브에이전트에, 수정은 general-purpose 서브에이전트에 넘기고 결과 요약만 회수하세요.

그래도 메인 루프에서 직접 해야 하는 상황(한 줄 오타, 스폰이 더 비싼 소규모 수정, 서브에이전트가
방금 낸 결과의 잔손질)이면 같은 편집을 다시 시도하세요 — 이번 세션에서는 다시 막지 않습니다."
