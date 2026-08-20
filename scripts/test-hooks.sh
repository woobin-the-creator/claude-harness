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

printf 'All 11 shared hook scripts passed deterministic fixtures.\n'
