#!/usr/bin/env bash
# SessionStart guard — 설치된 woobin-harness가 마켓플레이스 소스보다 뒤처졌으면 경고한다.
#
# 왜 있나: 플러그인 설치본은 ~/.claude/plugins/cache/<mp>/<plugin>/<version>/ 에 버전별로
# 굳은 복사본이다. 레포를 고쳐도 version을 안 올리거나 plugin update를 안 돌리면 설치본은
# 옛날 그대로 돈다. 2026-08-08(스킬 추가 후 version 누락)과 2026-08-19(레포 1.5.0 · 설치본
# 1.6.0으로 번호가 역전돼 갱신이 막힘) 두 번 실제로 났다. CLAUDE.md가 확인 명령을 적어
# 두는 방식으로만 대응하고 있었는데, 사람이 기억해서 쳐야 하는 검사는 안 쳐진다.
#
# 왜 codex 구현을 안 베꼈나: codex 쪽은 `codex plugin list`의 사람용 텍스트를 정규식으로
# 판다. Claude Code에는 대응 명령이 없고 대신 두 상태 파일이 JSON으로 있어서 jq로 읽는다.
# 파싱이 안전하고, gitCommitSha 덕에 드리프트 신호를 하나 더 얻는다(버전 + 커밋).
#
# 읽기 전용이다 — fetch 하지 않는다. 이미 로컬에 있는 커밋만 센다.
# fail-open: jq·상태 파일·소스 디렉터리 중 하나라도 없으면 조용히 exit 0. 세션을 막지 않는다.
# (bash 3.2 호환)

set -u
cat >/dev/null   # stdin을 비운다. 이 훅은 session_id를 쓰지 않는다.

command -v jq >/dev/null 2>&1 || exit 0

plugin="woobin-harness"
key="$plugin@$plugin"
known="$HOME/.claude/plugins/known_marketplaces.json"
installed="$HOME/.claude/plugins/installed_plugins.json"
[ -r "$known" ] && [ -r "$installed" ] || exit 0

src=$(jq -r --arg m "$plugin" '.[$m].installLocation // empty' "$known" 2>/dev/null)
[ -n "$src" ] && [ -d "$src" ] || exit 0

inst_ver=$(jq -r --arg k "$key" '.plugins[$k][0].version // empty' "$installed" 2>/dev/null)
inst_sha=$(jq -r --arg k "$key" '.plugins[$k][0].gitCommitSha // empty' "$installed" 2>/dev/null)
src_ver=$(jq -r '.version // empty' "$src/$plugin/.claude-plugin/plugin.json" 2>/dev/null)

detail=""
if [ -n "$inst_ver" ] && [ -n "$src_ver" ] && [ "$inst_ver" != "$src_ver" ]; then
  detail="설치본 $inst_ver · 레포 $src_ver"
elif [ -n "$inst_sha" ]; then
  behind=$(git -C "$src" rev-list --count "$inst_sha..HEAD" 2>/dev/null)
  case "$behind" in
    ''|0|*[!0-9]*) ;;
    *) detail="같은 버전($inst_ver)인데 설치본이 소스보다 ${behind}커밋 뒤" ;;
  esac
fi
[ -n "$detail" ] || exit 0

ctx="⚠ woobin-harness 설치본이 레포보다 뒤처져 있다 — ${detail}. 지금 세션에는 옛 스킬·훅·에이전트가 로드돼 있다. 레포 변경을 반영하려면: (1) woobin-harness/.claude-plugin/plugin.json 과 .codex-plugin/plugin.json 의 version 을 올린다 — 올릴 번호가 ~/.claude/plugins/cache/woobin-harness/woobin-harness/ 에 이미 있으면 그 번호는 막히므로 캐시를 먼저 확인한다. (2) claude plugin marketplace update woobin-harness. (3) claude plugin update woobin-harness@woobin-harness — 짧은 이름은 not found 로 실패한다. (4) Claude Code 재시작."

jq -cn --arg ctx "$ctx" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
