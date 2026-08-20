#!/bin/sh
# 새 머신에 하네스를 올린다.
#
# 훅·에이전트·스킬은 이 스크립트가 건드리지 않는다 — 플러그인(woobin-harness)이 나른다.
# 여기서 하는 건 "플러그인이 못 나르는 것"뿐이다:
#   ① ~/.claude/CLAUDE.md 등 홈 문서   ② statusline 스크립트
#   ③ settings.json 병합(권한·statusLine·마켓플레이스 등록)   ④ 손으로 해야 하는 것 안내
#
# 심링크를 쓰지 않는다. Claude Code가 settings.json을 직접 rewrite하고(예: /effort),
# 심링크된 설정 파일에서 퍼미션 무시·심링크 소실이 보고돼 있다
# (anthropics/claude-code #3575 · #40857 · #25367 — 전부 봇이 닫았고 수정 근거는 없다).

set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
CLAUDE_HOME=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
DRY=${DRY_RUN:-0}

say()  { printf '%s\n' "$*"; }
run()  { if [ "$DRY" = "1" ]; then say "  [dry] $*"; else eval "$@"; fi; }

say "== 대상: $CLAUDE_HOME"
[ "$DRY" = "1" ] && say "== DRY_RUN=1 — 아무것도 쓰지 않는다"
run "mkdir -p '$CLAUDE_HOME' '$CLAUDE_HOME/statusline'"

say
say "== ① 홈 문서 (덮어쓰기 전 .orig 백업)"
for f in CLAUDE.md HARNESS-LOG.md RTK.md; do
  src="$REPO/home/$f"; dst="$CLAUDE_HOME/$f"
  [ -f "$src" ] || continue
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
    run "cp '$dst' '$dst.orig'"; say "  기존 $f → $f.orig 로 보존"
  fi
  run "cp '$src' '$dst'"; say "  $f"
done

say
say "== ② statusline"
run "cp '$REPO/statusline/ctx-warn-statusline.sh' '$CLAUDE_HOME/statusline/'"
run "chmod +x '$CLAUDE_HOME/statusline/ctx-warn-statusline.sh'"

say
say "== ③ settings.json 병합"
if ! command -v jq >/dev/null 2>&1; then
  say "  jq가 없다 — 건너뛴다. 설치 후 다시 돌려라: brew install jq"
else
  S="$CLAUDE_HOME/settings.json"
  [ -f "$S" ] || run "printf '{}' > '$S'"
  # 이 레포를 마켓플레이스로 등록하고 플러그인을 켠다. 머신 고유 키(permissions·env·
  # enabledMcpjsonServers 등)는 건드리지 않는다 — 기존 값 위에 얹기만 한다.
  run "jq --arg repo '$REPO' '
        .extraKnownMarketplaces = ((.extraKnownMarketplaces // {}) + {
          \"woobin-harness\": { source: { source: \"directory\", path: \$repo } } })
        | .enabledPlugins = ((.enabledPlugins // {}) + {
          \"woobin-harness@woobin-harness\": true })
        | .statusLine = { type: \"command\", command: \"\$HOME/.claude/statusline/ctx-warn-statusline.sh\" }
        | .crossSessionInbound = \"refuse\"
        | .outputStyle = \"fluent-korean\"
       ' '$S' > '$S.tmp' && mv '$S.tmp' '$S'"
  say "  extraKnownMarketplaces·enabledPlugins·statusLine·crossSessionInbound·outputStyle 갱신"
  # crossSessionInbound: 머신 고유 키가 아니라 하네스 정책이라 statusLine 과 같이 무조건 덮는다.
  # 근거·기각안은 docs/workflow-spec.md §7-A, home/HARNESS-LOG.md #18.
  # 이 값을 지우면 기본값이 "사람이 없어도 피어가 내 세션을 깨움"으로 돌아간다.
  #
  # outputStyle: 플러그인의 settings.json 은 agent·subagentStatusLine 두 키만 지원하므로
  # 출력 스타일 파일은 플러그인이 나르지만 "그걸 켜는 일"은 플러그인이 못 한다. 그래서 여기 있다.
  # 스타일 실체는 woobin-harness/output-styles/, 출처와 개조 내역은 그 디렉터리의 ATTRIBUTION.md.
  # 근거는 home/HARNESS-LOG.md #21.
fi

say
say "== ④ 손으로 해야 하는 것 (자동화 안 됨)"
say "  1) 마켓플레이스 스킬 61개 복원:"
say "       cp '$REPO/agents-skill-lock.json' ~/.agents/.skill-lock.json"
say "       그리고 k-skill 셋업을 다시 돌려라 (스킬 실체는 이 레포에 없다 — 심링크만 있었다)"
say "  2) claude-buddy 훅 (없어도 죽지 않는다 — settings.json에 [ -x ] 가드가 걸려 있다):"
say "       git clone <claude-buddy> ~/codespace/claude-buddy"
say "  3) orca 훅: ~/.orca/agent-hooks/claude-hook.sh — orca를 설치하면 생긴다"
say "  4) gptaku 플러그인: /plugin 에서 gptaku-plugins 마켓플레이스를 추가"
say "  5) Claude Code 재시작 후 확인:"
say "       /plugin        → woobin-harness 가 enabled 인지"
say "       /context       → Custom Agents 에 plan-implementer·plan-reviewer 가 보이는지"
say "       /config        → Output Style 이 fluent-korean 인지 (플러그인 스타일은 재시작 후에 잡힌다)"
say "       claude --debug → 훅이 매칭되는지 (플랜 문서를 하나 Write 해보면 가장 빠르다)"
say
say "완료."
