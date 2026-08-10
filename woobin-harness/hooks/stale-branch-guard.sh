#!/usr/bin/env bash
# SessionStart guard — 현재 체크아웃이 "격리된 워크트리가 아니면서" 원격 기본
# 브랜치보다 뒤처져 있으면 경고하고, Claude에게 최신 기반 워크트리를 제안하도록
# additionalContext를 주입한다. 읽기 전용: git 상태를 바꾸는 건 fetch 뿐이다.
# (bash 3.2 호환)
#
# 이 경고는 stop-warning-ack-guard.sh(Stop 훅)와 짝을 이룬다: 여기서 마커 파일에
# ctx를 적어두면, 그 훅이 응답에 경고 원문이 실제로 포함됐는지 검사해 안 됐으면
# 반려(block)한다 — additionalContext가 모델에게 전달됐는지와 무관하게, 마커
# 파일 자체는 이 스크립트의 부수효과라 항상 남는다.
#
# R15(레이어 경계 커밋 + draft PR) 이후: 의도적으로 오래 사는 플랜 브랜치는 등급을 **하향**한다.
# 면제가 아니다 — 경고·마커·ack 게이트를 그대로 유지하고 문구만 "워크트리를 만들어라"에서
# "rebase가 필요한지만 확인해라"로 바꾼다. 조건을 "열린 plan-wip PR이 있다"로만 두면 방치된
# 브랜치도 빠져나가므로, "앞선 커밋이 있다"(= 실제 작업 중)를 함께 요구한다.
# 절차 원문은 woobin-harness/plan-exec-modes.md 가 소유한다 — 여기 복제하지 말 것(§6-6, 사고 #16).

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
marker_dir="$HOME/.claude/hooks/.stale-branch-pending"

# git 저장소가 아니면 조용히 종료.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

git_dir=$(cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)
git_common=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)

# 이미 링크된 워크트리(그리고 서브모듈이 아님) -> 이미 격리됨, 조용히 종료.
if [ "$git_dir" != "$git_common" ]; then
  if [ -z "$(git rev-parse --show-superproject-working-tree 2>/dev/null)" ]; then
    exit 0
  fi
fi

branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] || exit 0   # detached HEAD -> 판단할 브랜치 없음

# 원격 기본 브랜치(origin/HEAD)를 해석, 없으면 main으로.
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
[ -n "$default" ] || default=main

# 최선 노력 갱신 — 오프라인/실패면 마지막으로 알던 ref로 degrade.
git fetch origin "$default" --quiet 2>/dev/null

behind=$(git rev-list --count "HEAD..origin/${default}" 2>/dev/null)
case "$behind" in ''|*[!0-9]*) behind=0 ;; esac
[ "$behind" -gt 0 ] || exit 0

# R15 — 플랜 브랜치 판정. behind>0 경로에서만 계산하므로 평상시 비용은 0이다.
ahead=$(git rev-list --count "origin/${default}..HEAD" 2>/dev/null)
case "$ahead" in ''|*[!0-9]*) ahead=0 ;; esac

plan_wip=0
if [ "$ahead" -gt 0 ] && command -v gh >/dev/null 2>&1; then
  # 현재 브랜치의 열린 plan-wip PR만 본다. 미인증·원격 없음·오프라인이면 빈 문자열 -> 0으로 남는다.
  # SessionStart는 응답 지연에 민감하므로 gh 호출에 ~2초 상한을 둔다(이 머신엔 timeout(1)이 없어
  # 백그라운드 + 폴링으로 구현). 상한을 넘기면 죽이고 plan_wip=0(더 강한 경고 쪽)으로 fail-safe.
  gh_out="${marker_dir}/.gh-plan-wip-check.$$"
  mkdir -p "$marker_dir" 2>/dev/null
  gh pr list --head "$branch" --state open --label plan-wip \
    --json number --jq '.[].number' >"$gh_out" 2>/dev/null &
  gh_pid=$!
  gh_waited=0
  while kill -0 "$gh_pid" 2>/dev/null && [ "$gh_waited" -lt 20 ]; do
    sleep 0.1
    gh_waited=$((gh_waited + 1))
  done
  kill "$gh_pid" 2>/dev/null
  wait "$gh_pid" 2>/dev/null
  [ -s "$gh_out" ] && plan_wip=1
  rm -f "$gh_out"
fi

if [ "$plan_wip" -eq 1 ]; then
  ctx="⚠️ 세션 시작 stale-branch 점검: 현재 '${branch}'는 열린 plan-wip PR이 있는 **플랜 브랜치**이고, origin/${default}보다 ${behind} 커밋 뒤처져 있습니다(앞선 커밋 ${ahead}개).

이 경고는 사용자의 첫 메시지 내용과 무관하게 예외 없이 최우선입니다. 사용자가 완전히 다른 질문이나 작업을 요청했더라도, 조사나 답변을 먼저 진행하지 말고 이번 턴 응답의 맨 첫 문장으로 위 경고 문구를 사용자에게 그대로 전달한 뒤에 사용자의 실제 요청을 처리하세요. 경고를 생략하거나 뒤로 미루면 안 됩니다.

알린 다음: **새 워크트리를 만들지 마세요** — 이 브랜치는 구현이 진행 중인 플랜 브랜치입니다. 뒤처진 ${behind} 커밋이 이번 레이어가 건드리는 파일과 겹치는지만 확인하고, 겹치면 rebase 여부를 사용자에게 물어보세요. 겹치지 않으면 그대로 진행하세요."
else
  ctx="⚠️ 세션 시작 stale-branch 점검: 현재 '${branch}' 브랜치가 origin/${default}보다 ${behind} 커밋 뒤처져 있고, 격리된 워크트리가 아닙니다.

이 경고는 사용자의 첫 메시지 내용과 무관하게 예외 없이 최우선입니다. 사용자가 완전히 다른 질문이나 작업을 요청했더라도, 조사나 답변을 먼저 진행하지 말고 이번 턴 응답의 맨 첫 문장으로 위 경고 문구를 사용자에게 그대로 전달한 뒤에 사용자의 실제 요청을 처리하세요. 경고를 생략하거나 뒤로 미루면 안 됩니다.

알린 다음: 새 작업을 시작하는 맥락이면 EnterWorktree로 최신 ${default} 기반(baseRef=fresh) 워크트리를 만들지 사용자에게 물어보세요 — 자동으로 만들지 말고 확인을 받으세요. 사용자가 방금 만든 브랜치를 이어서 하려는 등 의도적으로 현재 브랜치에 머무는 경우라면 경고만 전하고 그대로 진행하세요."
fi

if [ -n "$session_id" ]; then
  mkdir -p "$marker_dir" 2>/dev/null
  printf '%s' "$ctx" > "$marker_dir/$session_id" 2>/dev/null
fi

jq -cn --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
