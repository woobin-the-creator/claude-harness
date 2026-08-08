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
[ -n "$behind" ] || behind=0
[ "$behind" -gt 0 ] || exit 0

ctx="⚠️ 세션 시작 stale-branch 점검: 현재 '${branch}' 브랜치가 origin/${default}보다 ${behind} 커밋 뒤처져 있고, 격리된 워크트리가 아닙니다.

이 경고는 사용자의 첫 메시지 내용과 무관하게 예외 없이 최우선입니다. 사용자가 완전히 다른 질문이나 작업을 요청했더라도, 조사나 답변을 먼저 진행하지 말고 이번 턴 응답의 맨 첫 문장으로 위 경고 문구를 사용자에게 그대로 전달한 뒤에 사용자의 실제 요청을 처리하세요. 경고를 생략하거나 뒤로 미루면 안 됩니다.

알린 다음: 새 작업을 시작하는 맥락이면 EnterWorktree로 최신 ${default} 기반(baseRef=fresh) 워크트리를 만들지 사용자에게 물어보세요 — 자동으로 만들지 말고 확인을 받으세요. 사용자가 방금 만든 브랜치를 이어서 하려는 등 의도적으로 현재 브랜치에 머무는 경우라면 경고만 전하고 그대로 진행하세요."

if [ -n "$session_id" ]; then
  mkdir -p "$marker_dir" 2>/dev/null
  printf '%s' "$ctx" > "$marker_dir/$session_id" 2>/dev/null
fi

jq -cn --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
