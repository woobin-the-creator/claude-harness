#!/bin/sh
set -eu
S=woobin-harness/skills/show-design-sample/SKILL.md
R=woobin-harness/skills/show-design-sample/REFERENCE.md
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }
chk "candidate set first" "grep -q '후보 집합' '$S'"
chk "all candidates mapping" "grep -q '다.*전부' '$S'"
chk "bare count matching set size selects all" "grep -q 'bare \`3개\`.*즉시 생성' '$S'"
chk "ambiguous subset asks once" "grep -q '부분 집합.*한 번' '$S'"
chk "one builder fast path" "grep -q 'N <= 3.*에이전트 1개' '$S'"
chk "parallel threshold" "grep -q 'N >= 4' '$S'"
chk "pages default" "grep -q 'GitHub Pages.*기본' '$S'"
chk "local explicit only" "grep -q '로컬.*명시' '$S'"
chk "no browser contract" "grep -q 'Playwright.*사용하지 않는다' '$S'"
chk "local exclude" "grep -q 'info/exclude' '$S'"
chk "init script surface" "grep -q 'scripts/init-preview.sh <repo-root> \\[app-dir\\]' '$S'"
chk "build script surface" "grep -q 'scripts/build-preview.sh <app-dir>' '$S'"
chk "deploy script surface" "grep -q 'scripts/deploy-preview.sh <app-dir> \\[owner/repo\\]' '$S'"
chk "serve script surface" "grep -q 'scripts/serve-preview.sh <app-dir>' '$S'"
chk "app dir retry token" "grep -q 'APP_DIR_REQUIRED' '$S'"
chk "new public repo retry token" "grep -q 'NEW_PUBLIC_REPO_REQUIRED=<owner/repo>' '$S'"
chk "adaptive hook guidance" "grep -q 'N<=3.*빌더 1개' woobin-harness/hooks/sdd-orchestrator-edit-guard.sh"
chk "workflow route synchronized" "grep -q '브라우저 없이.*N<=3' docs/workflow-spec.md"
chk "plugin version" "grep -q '\"version\": \"1.6.0\"' woobin-harness/.claude-plugin/plugin.json"
chk "stale mandatory browser language removed" "! grep -Eq '브라우저 검증|스크린샷 검증|curl -sI <url>|Playwright smoke test' '$S'"
chk "stale per-variant-agent language removed" "! grep -Eq '시안마다 에이전트 1개|빌더 N개 동시|variant별 에이전트.*항상|worktree를 나누지 않는다' '$S'"
chk "reference split" "test -f '$R' && grep -q '^## 기각한 대안' '$R'"
bytes=$(wc -c < "$S" | tr -d ' ')
chk "runtime body compact" "test '$bytes' -le 6500"
test "$fail" -eq 0
echo ALL-OK
