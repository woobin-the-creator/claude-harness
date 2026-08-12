#!/bin/sh
# 하네스 문서 동기화 검사 — 개수·인벤토리·동반 수정 여부를 기계가 센다.
#
# 왜: CLAUDE.md 는 "고칠 때 같이 고쳐야 하는 것"으로 문서 4종(README · docs/workflow.html ·
# docs/workflow-spec.md · 훅 헤더)을 이미 명시한다. 그런데 2026-08-10, 그 규칙이 있는 상태로
# workflow.html 이 빠졌다(사용자가 물어봐서 발견). 산문 체크리스트가 이미 한 번 실패했다는 뜻이고,
# 규율 2("소프트 지시로 못 막는 건 구조를 바꾼다")가 적용되는 자리다.
#
# 실패(✗)와 경고(⚠)를 나눈 이유: 훅을 **추가**하면 사람용 요약의 서술이 바뀐다(이번에 "유일한 세션
# 경계"가 거짓이 된 것처럼). 훅 **내용만** 고치면 안 바뀔 수도 있다. 모든 수정에 workflow.html 을
# 요구하면 오탐이 쌓여 무시당하고, 그게 산문 규칙이 죽은 것과 같은 경로다.
#
# 이 레포(claude-harness) 안에서만 의미가 있다. 다른 레포에서는 조용히 통과한다.

set -u

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0
[ -f "$root/woobin-harness/.claude-plugin/plugin.json" ] || exit 0
cd "$root" || exit 0

fail=0
warn=0
say()  { printf '  ✗ %s\n' "$1"; fail=1; }
warn() { printf '  ⚠ %s\n' "$1"; warn=1; }

# ── 실제 개수 ────────────────────────────────────────────────────────────────
n_hooks=$(ls woobin-harness/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')
n_skills=$(ls -d woobin-harness/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
n_agents=$(ls woobin-harness/agents/*.md 2>/dev/null | wc -l | tr -d ' ')

# 파일에서 "<정규식>" 첫 매치의 숫자를 뽑는다.
num() { grep -oE "$2" "$1" 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1; }

cmp_num() { # $1=라벨 $2=파일 $3=정규식 $4=실제값
  [ -f "$2" ] || { warn "$2 : 파일이 없다"; return; }
  d=$(num "$2" "$3")
  if [ -z "$d" ]; then
    warn "$2 : '$1' 개수 문구를 못 찾았다 (정규식: $3) — 서식이 바뀌었으면 이 스크립트를 고쳐라"
    return
  fi
  [ "$d" = "$4" ] || say "$2 : $1 ${d}개로 적혀 있는데 실제는 ${4}개"
}

echo "[개수]"
cmp_num "훅"       README.md                                  'hooks/\*\.sh +[0-9]+개'        "$n_hooks"
cmp_num "에이전트"  README.md                                  'agents/\*\.md +[0-9]+개'       "$n_agents"
cmp_num "스킬"      README.md                                  'SKILL\.md +[0-9]+개'           "$n_skills"
for f in woobin-harness/.claude-plugin/plugin.json .claude-plugin/marketplace.json docs/workflow-spec.md; do
  cmp_num "훅"      "$f" '훅 [0-9]+개'       "$n_hooks"
  cmp_num "에이전트" "$f" '에이전트 [0-9]+개' "$n_agents"
  cmp_num "스킬"     "$f" '스킬 [0-9]+개'     "$n_skills"
done

# ── 인벤토리: 훅·에이전트 파일이 workflow-spec §4 에 등재됐는가 ───────────────
echo "[인벤토리]"
for f in woobin-harness/hooks/*.sh; do
  b=$(basename "$f")
  grep -q "$b" docs/workflow-spec.md || say "docs/workflow-spec.md §4 에 \`$b\` 행이 없다"
done
for f in woobin-harness/agents/*.md; do
  b=$(basename "$f" .md)
  grep -q "\`$b\`" docs/workflow-spec.md || say "docs/workflow-spec.md §4 에 에이전트 \`$b\` 행이 없다"
done

# ── 동반 수정: 훅·에이전트가 바뀌었는데 문서가 안 바뀌었는가 ──────────────────
echo "[동반 수정]"
changed() {
  { git diff --name-only 2>/dev/null
    git diff --cached --name-only 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
    if git rev-parse --verify -q origin/main >/dev/null 2>&1; then
      b=$(git merge-base HEAD origin/main 2>/dev/null)
      [ -n "$b" ] && git diff --name-only "$b" HEAD 2>/dev/null
    fi
  } | sort -u
}
added() {
  { git diff --name-only --diff-filter=A 2>/dev/null
    git diff --cached --name-only --diff-filter=A 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
    if git rev-parse --verify -q origin/main >/dev/null 2>&1; then
      b=$(git merge-base HEAD origin/main 2>/dev/null)
      [ -n "$b" ] && git diff --name-only --diff-filter=A "$b" HEAD 2>/dev/null
    fi
  } | sort -u
}

ch=$(changed); ad=$(added)
has() { printf '%s\n' "$1" | grep -q "$2"; }

if has "$ch" '^woobin-harness/\(hooks\|agents\)/'; then
  has "$ch" '^docs/workflow-spec\.md$' \
    || say "훅·에이전트가 바뀌었는데 docs/workflow-spec.md 가 안 바뀌었다 (§3 규칙 · §4 인벤토리)"
  if has "$ad" '^woobin-harness/\(hooks\|agents\)/'; then
    has "$ch" '^docs/workflow\.html$' \
      || say "훅·에이전트가 **추가**됐는데 docs/workflow.html 이 안 바뀌었다 — 사람용 요약의 서술이 갈라진다"
  else
    has "$ch" '^docs/workflow\.html$' \
      || warn "훅·에이전트가 수정됐다. docs/workflow.html 의 서술이 여전히 참인지 확인해라(내용 수정만이면 무시해도 된다)"
  fi
  has "$ch" '^home/HARNESS-LOG\.md$' \
    || warn "훅·에이전트가 바뀌었는데 home/HARNESS-LOG.md 에 항목이 없다 — 왜 고쳤는지가 사라진다"
fi

if has "$ch" '^woobin-harness/'; then
  has "$ch" '^woobin-harness/\.claude-plugin/plugin\.json$' \
    || say "woobin-harness/ 가 바뀌었는데 Claude plugin.json 의 version 을 안 올렸다 — 설치본은 옛날 그대로 돈다"
  has "$ch" '^woobin-harness/\.codex-plugin/plugin\.json$' \
    || say "woobin-harness/ 가 바뀌었는데 Codex plugin.json 의 version 을 안 올렸다"
fi

claude_version=$(jq -r '.version // empty' woobin-harness/.claude-plugin/plugin.json 2>/dev/null)
codex_version=$(jq -r '.version // empty' woobin-harness/.codex-plugin/plugin.json 2>/dev/null)
[ -n "$claude_version" ] || say "Claude plugin.json version 이 없다"
[ -n "$codex_version" ] || say "Codex plugin.json version 이 없다"
[ "$claude_version" = "$codex_version" ] \
  || say "Claude/Codex plugin version 이 다르다: ${claude_version:-없음} != ${codex_version:-없음}"

echo
if [ "$fail" -ne 0 ]; then
  echo "동기화 안 됨 — 위 ✗ 를 고쳐라."
  exit 1
fi
[ "$warn" -ne 0 ] && echo "동기화됨 (⚠ 는 판단이 필요한 항목)." || echo "동기화됨."
exit 0
