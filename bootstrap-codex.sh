#!/bin/sh
# Install the parts of Woobin Harness that a Codex plugin cannot carry itself:
# global AGENTS.md, custom agent profiles, and the repo marketplace/plugin install.

set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
CODEX_DIR=${CODEX_HOME:-$HOME/.codex}
DRY=${DRY_RUN:-0}

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY" = "1" ]; then say "  [dry] $*"; else eval "$@"; fi; }

say "== 대상: $CODEX_DIR"
[ "$DRY" = "1" ] && say "== DRY_RUN=1 — 아무것도 쓰지 않는다"
run "mkdir -p '$CODEX_DIR' '$CODEX_DIR/agents'"

say
say "== ① 전역 AGENTS.md (덮어쓰기 전 .orig 백업)"
src="$REPO/home/CLAUDE.md"
dst="$CODEX_DIR/AGENTS.md"
if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
  run "cp '$dst' '$dst.orig'"
  say "  기존 AGENTS.md → AGENTS.md.orig 로 보존"
fi
run "cp '$src' '$dst'"
say "  home/CLAUDE.md 정책 본문 → AGENTS.md"

say
say "== ② Codex 커스텀 에이전트"
for src in "$REPO"/codex/agents/*.toml; do
  [ -f "$src" ] || continue
  name=$(basename "$src")
  dst="$CODEX_DIR/agents/$name"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
    run "cp '$dst' '$dst.orig'"
    say "  기존 $name → $name.orig 로 보존"
  fi
  run "cp '$src' '$dst'"
  say "  $name"
done

say
say "== ③ Codex 마켓플레이스·플러그인 설치"
if ! command -v codex >/dev/null 2>&1; then
  say "  codex CLI가 없어 건너뛴다. 설치 후 아래 두 명령을 실행해라:"
  say "    codex plugin marketplace add '$REPO'"
  say "    codex plugin add woobin-harness@woobin-harness"
elif [ "$DRY" = "1" ]; then
  say "  [dry] codex plugin marketplace add '$REPO'"
  say "  [dry] codex plugin add woobin-harness@woobin-harness"
else
  if codex plugin marketplace add "$REPO"; then
    say "  woobin-harness 마켓플레이스 등록 완료"
  else
    say "  등록 명령이 실패했다. 이미 등록됐다면 무시하고 'codex plugin marketplace list'로 확인해라."
  fi
  if codex plugin add woobin-harness@woobin-harness; then
    say "  woobin-harness 플러그인 설치 완료"
  else
    say "  설치 명령이 실패했다. 'codex plugin list --available --json'으로 상태를 확인해라."
  fi
fi

say
say "== ④ 손으로 해야 하는 것"
say "  1) ChatGPT 데스크톱 앱을 재시작"
say "  2) Plugins Directory에서 woobin-harness가 설치·활성 상태인지 확인"
say "  3) 새 Codex 대화에서 /hooks를 열어 플러그인 훅 검토·신뢰"
say "  4) /skills 또는 \$로 woobin-harness 스킬이 보이는지 확인"
say
say "완료."
