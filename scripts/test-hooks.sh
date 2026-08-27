#!/bin/sh
# Deterministic branch fixtures for every shared hook script.
# All repositories, transcripts, markers, and HOME state live under one temp dir.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
HOOKS="$ROOT/woobin-harness/hooks"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

TEST_HOME="$TEST_ROOT/home"
TEST_TMP="$TEST_ROOT/tmp"
mkdir -p "$TEST_HOME/.claude" "$TEST_TMP"

fail() { printf '✗ %s\n' "$*" >&2; exit 1; }
pass() { printf '✓ %s\n' "$*"; }
assert_silent() { [ -z "$1" ] || fail "$2: expected no output"; }
assert_json() { printf '%s' "$1" | jq -e "$2" >/dev/null || fail "$3"; }

# ctx-handoff-stop: high context blocks once and creates the session marker.
ctx_transcript="$TEST_ROOT/ctx.jsonl"
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":120,"cache_read_input_tokens":80,"cache_creation_input_tokens":0}}}' >"$ctx_transcript"
ctx_err="$TEST_ROOT/ctx.err"
set +e
printf '%s' "{\"session_id\":\"ctx-session\",\"transcript_path\":\"$ctx_transcript\",\"stop_hook_active\":false}" \
  | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" CTX_HANDOFF_THRESHOLD=100 "$HOOKS/ctx-handoff-stop.sh" \
      >/dev/null 2>"$ctx_err"
ctx_rc=$?
set -e
[ "$ctx_rc" -eq 2 ] || fail "ctx-handoff-stop: expected exit 2, got $ctx_rc"
grep -q '컨텍스트 자동 핸드오프' "$ctx_err" || fail "ctx-handoff-stop: missing handoff reason"
[ -f "$TEST_TMP/claude-ctx-handoff/ctx-session" ] || fail "ctx-handoff-stop: marker missing"
pass "ctx-handoff-stop trigger"

# idle-handoff-stop: a one-second idle window reaches the async wakeup branch.
idle_transcript="$TEST_ROOT/idle.jsonl"
printf '%s\n' '{}' >"$idle_transcript"
idle_err="$TEST_ROOT/idle.err"
set +e
printf '%s' "{\"session_id\":\"idle-session\",\"transcript_path\":\"$idle_transcript\"}" \
  | HOME="$TEST_HOME" IDLE_HANDOFF_DELAY=1 IDLE_HANDOFF_POLL=1 IDLE_HANDOFF_MAXGAP=999999 \
      "$HOOKS/idle-handoff-stop.sh" >/dev/null 2>"$idle_err"
idle_rc=$?
set -e
[ "$idle_rc" -eq 2 ] || fail "idle-handoff-stop: expected exit 2, got $idle_rc"
grep -q '자리비움 자동 핸드오프' "$idle_err" || fail "idle-handoff-stop: missing wakeup reason"
[ -f "$TEST_HOME/.claude/idle-handoff/idle-session.last-inject" ] || fail "idle-handoff-stop: inject marker missing"
pass "idle-handoff-stop async trigger"

# idle-return-guard: first stale prompt blocks, immediate retry passes, close marks done.
idle_input="{\"session_id\":\"return-session\",\"transcript_path\":\"$idle_transcript\",\"cwd\":\"$TEST_ROOT\",\"prompt\":\"continue\"}"
out=$(printf '%s' "$idle_input" | HOME="$TEST_HOME" IDLE_GUARD_THRESHOLD=-1 "$HOOKS/idle-return-guard.sh")
assert_json "$out" '.decision == "block" and (.reason | contains("프롬프트 캐시"))' "idle-return-guard: stale prompt did not block"
out=$(printf '%s' "$idle_input" | HOME="$TEST_HOME" IDLE_GUARD_THRESHOLD=-1 "$HOOKS/idle-return-guard.sh")
assert_silent "$out" "idle-return-guard immediate retry"
out=$(printf '%s' '{"session_id":"return-session","cwd":"/tmp","prompt":"/close-session"}' \
  | HOME="$TEST_HOME" "$HOOKS/idle-return-guard.sh")
assert_json "$out" '.decision == "block" and (.reason | contains("세션을 닫았습니다"))' "idle-return-guard: close-session did not block"
[ -f "$TEST_HOME/.claude/idle-handoff/return-session.handoff-done" ] || fail "idle-return-guard: close marker missing"
pass "idle-return-guard stale/retry/close branches"

# plan-saved-session-boundary: a plan write emits once and uses the no-mode fallback.
plan_root="$TEST_ROOT/plan-project"
plan_file="$plan_root/docs/woobin_plan/plans/sample.md"
mkdir -p "$(dirname "$plan_file")"
printf '# Plan\n\n- task\n' >"$plan_file"
plan_input="{\"session_id\":\"plan-save-session\",\"tool_input\":{\"file_path\":\"$plan_file\"}}"
out=$(printf '%s' "$plan_input" \
  | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" PLAN_EXEC_MODES_FILE="$TEST_ROOT/missing-modes.md" \
      "$HOOKS/plan-saved-session-boundary.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | contains("세션 경계 알림"))' "plan-saved-session-boundary: missing context"
out=$(printf '%s' "$plan_input" \
  | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" PLAN_EXEC_MODES_FILE="$TEST_ROOT/missing-modes.md" \
      "$HOOKS/plan-saved-session-boundary.sh")
assert_silent "$out" "plan-saved-session-boundary once-only"
pass "plan-saved-session-boundary trigger/once"

# plan-saved-session-boundary: 분할 저장된 플랜은 00-overview.md 에만 발화하고 task-N.md 는 침묵한다.
split_overview="$plan_root/docs/woobin_plan/plans/2026-08-21-sample/00-overview.md"
split_task="$plan_root/docs/woobin_plan/plans/2026-08-21-sample/task-1.md"
mkdir -p "$(dirname "$split_overview")"
printf '# Plan\n\n- task\n' >"$split_overview"
printf '### Task 1\n' >"$split_task"
out=$(printf '%s' "{\"session_id\":\"plan-split-session\",\"tool_input\":{\"file_path\":\"$split_overview\"}}" \
  | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" PLAN_EXEC_MODES_FILE="$TEST_ROOT/missing-modes.md" \
      "$HOOKS/plan-saved-session-boundary.sh")
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("이미") and contains("분할 불필요")' \
  "plan-saved-session-boundary: overview did not use the presplit branch"
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("2026-08-21-sample 플랜으로 구현")' \
  "plan-saved-session-boundary: kickoff target is not the plan directory"
out=$(printf '%s' "{\"session_id\":\"plan-split-session\",\"tool_input\":{\"file_path\":\"$split_task\"}}" \
  | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" PLAN_EXEC_MODES_FILE="$TEST_ROOT/missing-modes.md" \
      "$HOOKS/plan-saved-session-boundary.sh")
assert_silent "$out" "plan-saved-session-boundary task-N.md silence"
pass "plan-saved-session-boundary presplit overview/task branches"

# plan-session-boundary-guard: high-context plan-entry prompt emits once.
plan_ctx_transcript="$TEST_ROOT/plan-context.jsonl"
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":130000,"cache_read_input_tokens":1000,"cache_creation_input_tokens":0}}}' >"$plan_ctx_transcript"
entry_input="{\"session_id\":\"plan-entry-session\",\"transcript_path\":\"$plan_ctx_transcript\",\"prompt\":\"구현 계획을 작성하자\"}"
out=$(printf '%s' "$entry_input" | TMPDIR="$TEST_TMP" "$HOOKS/plan-session-boundary-guard.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | contains("플랜 진입 경계"))' "plan-session-boundary-guard: missing context"
out=$(printf '%s' "$entry_input" | TMPDIR="$TEST_TMP" "$HOOKS/plan-session-boundary-guard.sh")
assert_silent "$out" "plan-session-boundary-guard once-only"
pass "plan-session-boundary-guard trigger/once"

# sdd-kickoff-guard: a split plan directory tells the orchestrator to read overview only.
split_dir="$plan_root/docs/woobin_plan/plans/split-plan"
mkdir -p "$split_dir"
printf '# Overview\n' >"$split_dir/00-overview.md"
kick_input='{"session_id":"kick-session","prompt":"docs/woobin_plan/plans/split-plan 구현 진행해줘"}'
out=$(cd "$plan_root" && printf '%s' "$kick_input" | TMPDIR="$TEST_TMP" "$HOOKS/sdd-kickoff-guard.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | contains("00-overview.md"))' "sdd-kickoff-guard: missing split-plan context"
out=$(cd "$plan_root" && printf '%s' "$kick_input" | TMPDIR="$TEST_TMP" "$HOOKS/sdd-kickoff-guard.sh")
assert_silent "$out" "sdd-kickoff-guard once-only"
pass "sdd-kickoff-guard split-plan/once"

# sdd-orchestrator-edit-guard: SDD ledger causes a one-time deny for main-loop source edits.
edit_root="$TEST_ROOT/edit-project"
mkdir -p "$edit_root/.superpowers/sdd/run" "$edit_root/src"
git -C "$edit_root" init -q
printf 'progress\n' >"$edit_root/.superpowers/sdd/run/progress.md"
printf 'source\n' >"$edit_root/src/main.txt"
edit_input="{\"session_id\":\"edit-session\",\"cwd\":\"$edit_root\",\"tool_input\":{\"file_path\":\"$edit_root/src/main.txt\"}}"
out=$(printf '%s' "$edit_input" | TMPDIR="$TEST_TMP" "$HOOKS/sdd-orchestrator-edit-guard.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.permissionDecision == "deny"' "sdd-orchestrator-edit-guard: missing deny"
out=$(printf '%s' "$edit_input" | TMPDIR="$TEST_TMP" "$HOOKS/sdd-orchestrator-edit-guard.sh")
assert_silent "$out" "sdd-orchestrator-edit-guard once-only"
pass "sdd-orchestrator-edit-guard deny/once"

# harness-doc-sync-guard: run against a synthetic repo/checker to force a warning.
sync_root="$TEST_ROOT/sync-project"
mkdir -p "$sync_root/scripts" "$sync_root/woobin-harness"
git -C "$sync_root" init -q
cat >"$sync_root/scripts/check-harness-docs.sh" <<'EOF'
#!/bin/sh
printf '  ✗ fixture mismatch\n'
exit 1
EOF
chmod +x "$sync_root/scripts/check-harness-docs.sh"
sync_input="{\"session_id\":\"sync-session\",\"cwd\":\"$sync_root\",\"tool_input\":{\"file_path\":\"$sync_root/woobin-harness/file.txt\"}}"
out=$(printf '%s' "$sync_input" | TMPDIR="$TEST_TMP" HARNESS_HOST=codex "$HOOKS/harness-doc-sync-guard.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | contains("AGENTS.md"))' "harness-doc-sync-guard: missing Codex context"
out=$(printf '%s' "$sync_input" | TMPDIR="$TEST_TMP" HARNESS_HOST=codex "$HOOKS/harness-doc-sync-guard.sh")
assert_silent "$out" "harness-doc-sync-guard once-only"
pass "harness-doc-sync-guard trigger/once"

# subagent-model-default: inject only when neither call nor agent definition owns a model.
agent_root="$TEST_ROOT/agent-project"
git -C "$agent_root" init -q 2>/dev/null || { mkdir -p "$agent_root"; git -C "$agent_root" init -q; }
agent_input="{\"session_id\":\"agent-session\",\"cwd\":\"$agent_root\",\"tool_input\":{\"subagent_type\":\"general-purpose\",\"prompt\":\"inspect\"}}"
out=$(printf '%s' "$agent_input" | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" "$HOOKS/subagent-model-default.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.updatedInput.model == "sonnet"' "subagent-model-default: model not injected"
out=$(printf '%s' '{"cwd":"/tmp","tool_input":{"subagent_type":"general-purpose","model":"opus"}}' \
  | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" "$HOOKS/subagent-model-default.sh")
assert_silent "$out" "subagent-model-default explicit model"
mkdir -p "$agent_root/.claude/agents"
printf '%s\n' '---' 'name: explorer' 'model: haiku' '---' >"$agent_root/.claude/agents/explorer.md"
out=$(printf '%s' "{\"cwd\":\"$agent_root\",\"tool_input\":{\"subagent_type\":\"explorer\"}}" \
  | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" "$HOOKS/subagent-model-default.sh")
assert_silent "$out" "subagent-model-default agent-owned model"
pass "subagent-model-default inject/override guards"

# stale-branch + stop-warning pair: create a real local remote and a behind checkout.
origin="$TEST_ROOT/origin.git"
seed="$TEST_ROOT/seed"
behind="$TEST_ROOT/behind"
git init -q --bare --initial-branch=main "$origin"
git init -q --initial-branch=main "$seed"
git -C "$seed" config user.name fixture
git -C "$seed" config user.email fixture@example.invalid
printf 'one\n' >"$seed/file.txt"
git -C "$seed" add file.txt
git -C "$seed" commit -qm one
git -C "$seed" remote add origin "$origin"
git -C "$seed" push -q -u origin main
git clone -q "$origin" "$behind"
printf 'two\n' >>"$seed/file.txt"
git -C "$seed" commit -qam two
git -C "$seed" push -q

stale_input='{"session_id":"stale-session","source":"startup"}'
out=$(cd "$behind" && printf '%s' "$stale_input" \
  | HARNESS_HOST=codex HARNESS_STATE_DIR="$TEST_ROOT/codex-state" "$HOOKS/stale-branch-guard.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext | contains("새 worktree"))' "stale-branch-guard: missing Codex context"
[ -f "$TEST_ROOT/codex-state/hooks/.stale-branch-pending/stale-session" ] || fail "stale-branch-guard: marker missing"

out=$(printf '%s' '{"session_id":"stale-session","stop_hook_active":false,"last_assistant_message":"unrelated"}' \
  | HARNESS_HOST=codex HARNESS_STATE_DIR="$TEST_ROOT/codex-state" "$HOOKS/stop-warning-ack-guard.sh")
assert_json "$out" '.decision == "block" and (.reason | contains("stale-branch 경고"))' "stop-warning-ack-guard: missing block"
out=$(printf '%s' '{"session_id":"stale-session","stop_hook_active":true,"last_assistant_message":"still unrelated"}' \
  | HARNESS_HOST=codex HARNESS_STATE_DIR="$TEST_ROOT/codex-state" "$HOOKS/stop-warning-ack-guard.sh")
assert_silent "$out" "stop-warning-ack-guard active retry"
[ ! -e "$TEST_ROOT/codex-state/hooks/.stale-branch-pending/stale-session" ] || fail "stop-warning-ack-guard: active marker not removed"

out=$(cd "$behind" && printf '%s' '{"session_id":"stale-ack","source":"resume"}' \
  | HARNESS_HOST=codex HARNESS_STATE_DIR="$TEST_ROOT/codex-state" "$HOOKS/stale-branch-guard.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "SessionStart"' "stale-branch-guard: second session did not trigger"
out=$(printf '%s' '{"session_id":"stale-ack","stop_hook_active":false,"last_assistant_message":"stale-branch 점검 경고 전달"}' \
  | HARNESS_HOST=codex HARNESS_STATE_DIR="$TEST_ROOT/codex-state" "$HOOKS/stop-warning-ack-guard.sh")
assert_silent "$out" "stop-warning-ack-guard acknowledged response"
[ ! -e "$TEST_ROOT/codex-state/hooks/.stale-branch-pending/stale-ack" ] || fail "stop-warning-ack-guard: acknowledged marker not removed"
pass "stale-branch + stop-warning block/ack/loop guard"

# plugin-update-guard: 버전 드리프트 / 커밋 드리프트 / 정상 / 판단불가 네 갈래.
pug_src="$TEST_ROOT/pug-src"
mkdir -p "$pug_src/woobin-harness/.claude-plugin" "$TEST_HOME/.claude/plugins"
printf '{"name":"woobin-harness","version":"1.13.0"}\n' \
  >"$pug_src/woobin-harness/.claude-plugin/plugin.json"
git -C "$pug_src" init -q
git -C "$pug_src" -c user.email=t@t -c user.name=t add -A
git -C "$pug_src" -c user.email=t@t -c user.name=t commit -qm first
pug_first=$(git -C "$pug_src" rev-parse HEAD)
printf 'second\n' >"$pug_src/woobin-harness/second.txt"
git -C "$pug_src" -c user.email=t@t -c user.name=t add -A
git -C "$pug_src" -c user.email=t@t -c user.name=t commit -qm second

cat >"$TEST_HOME/.claude/plugins/known_marketplaces.json" <<PUGMP
{"woobin-harness":{"installLocation":"$pug_src"}}
PUGMP

pug_installed() {
  cat >"$TEST_HOME/.claude/plugins/installed_plugins.json" <<PUGIP
{"plugins":{"woobin-harness@woobin-harness":[{"version":"$1","gitCommitSha":"$2"}]}}
PUGIP
}

# (a) 버전이 다르면 경고한다.
pug_installed "1.12.0" "$(git -C "$pug_src" rev-parse HEAD)"
out=$(printf '%s' '{"session_id":"pug-a"}' \
  | HOME="$TEST_HOME" "$HOOKS/plugin-update-guard.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "SessionStart"' \
  "plugin-update-guard: missing SessionStart output"
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("1.12.0") and contains("1.13.0")' \
  "plugin-update-guard: version drift not reported"

# (b) 버전은 같은데 커밋이 뒤처지면 경고한다.
pug_installed "1.13.0" "$pug_first"
out=$(printf '%s' '{"session_id":"pug-b"}' \
  | HOME="$TEST_HOME" "$HOOKS/plugin-update-guard.sh")
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("커밋 뒤")' \
  "plugin-update-guard: commit drift not reported"

# (c) 버전도 커밋도 같으면 조용하다.
pug_installed "1.13.0" "$(git -C "$pug_src" rev-parse HEAD)"
out=$(printf '%s' '{"session_id":"pug-c"}' \
  | HOME="$TEST_HOME" "$HOOKS/plugin-update-guard.sh")
assert_silent "$out" "plugin-update-guard: healthy install must stay silent"

# (d) 상태 파일이 없으면 조용히 빠진다 (fail-open).
out=$(printf '%s' '{"session_id":"pug-d"}' \
  | HOME="$TEST_ROOT/no-such-home" "$HOOKS/plugin-update-guard.sh")
assert_silent "$out" "plugin-update-guard: missing state must be silent"

pass "plugin-update-guard drift/healthy/absent branches"

# kickoff-guard: keyword opens the door, a filename mention does not, drift warns once.
kick_root="$TEST_ROOT/kickoff-project"
mkdir -p "$kick_root/.claude"
kick_state="$kick_root/.claude/kickoff.local.md"   # 아직 없는 경로 — 앞의 두 단언은 상태 파일 없이 돈다
out=$(printf '%s' '{"session_id":"kickoff-a","prompt":"킥오프 해줘"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT/woobin-harness" KICKOFF_STATE_FILE="$kick_state" TMPDIR="$TEST_TMP" "$HOOKS/kickoff-guard.sh")
assert_json "$out" '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | contains("skills/kick-off/SKILL.md"))' "kickoff-guard: keyword did not open"
out=$(printf '%s' '{"session_id":"kickoff-a","prompt":"sdd-kickoff-guard.sh 고쳐줘"}' \
  | CLAUDE_PLUGIN_ROOT="$ROOT/woobin-harness" KICKOFF_STATE_FILE="$kick_state" TMPDIR="$TEST_TMP" "$HOOKS/kickoff-guard.sh")
assert_silent "$out" "kickoff-guard: filename mention must not fire"
printf -- '---\nactive: true\nstage: spec\ntopic: fixture\n---\nfixture\n' >"$kick_state"
out=$(printf '%s' '{"session_id":"kickoff-b","prompt":"이제 구현 시작해줘"}' \
  | KICKOFF_STATE_FILE="$kick_state" TMPDIR="$TEST_TMP" "$HOOKS/kickoff-guard.sh")
assert_json "$out" '(.hookSpecificOutput.additionalContext | contains("이탈 알림"))' "kickoff-guard: drift did not warn"
out=$(printf '%s' '{"session_id":"kickoff-b","prompt":"이제 구현 시작해줘"}' \
  | KICKOFF_STATE_FILE="$kick_state" TMPDIR="$TEST_TMP" "$HOOKS/kickoff-guard.sh")
assert_silent "$out" "kickoff-guard drift once-only"
printf -- '---\nactive: false\nstage: spec\n---\nfixture\n' >"$kick_state"
out=$(printf '%s' '{"session_id":"kickoff-c","prompt":"이제 구현 시작해줘"}' \
  | KICKOFF_STATE_FILE="$kick_state" TMPDIR="$TEST_TMP" "$HOOKS/kickoff-guard.sh")
assert_silent "$out" "kickoff-guard: inactive state must be silent"
pass "kickoff-guard keyword/drift/once"

printf 'All 12 shared hook scripts passed deterministic fixtures.\n'
