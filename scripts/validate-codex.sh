#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
CODEX_DIR=${CODEX_HOME:-$HOME/.codex}
PLUGIN_VALIDATOR="$CODEX_DIR/skills/.system/plugin-creator/scripts/validate_plugin.py"
SKILL_VALIDATOR="$CODEX_DIR/skills/.system/skill-creator/scripts/quick_validate.py"

fail() { printf '✗ %s\n' "$*" >&2; exit 1; }
pass() { printf '✓ %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || fail "jq가 필요하다"
[ -f "$PLUGIN_VALIDATOR" ] || fail "Codex plugin validator를 못 찾았다: $PLUGIN_VALIDATOR"
[ -f "$SKILL_VALIDATOR" ] || fail "Codex skill validator를 못 찾았다: $SKILL_VALIDATOR"

python3 "$PLUGIN_VALIDATOR" "$ROOT/woobin-harness"
pass "Codex plugin manifest"

for skill in "$ROOT"/woobin-harness/skills/*; do
  [ -f "$skill/SKILL.md" ] || continue
  python3 "$SKILL_VALIDATOR" "$skill" >/dev/null
done
pass "all skill frontmatter"

jq -e '.hooks and (.hooks | type == "object")' "$ROOT/woobin-harness/hooks/hooks.json" >/dev/null
jq -e '.hooks and (.hooks | type == "object")' "$ROOT/woobin-harness/hooks/claude-hooks.json" >/dev/null
jq -e '.plugins[0].source.path == "./woobin-harness"' "$ROOT/.agents/plugins/marketplace.json" >/dev/null
pass "hook and marketplace JSON"

python3 - "$ROOT" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
hook_dir = root / "woobin-harness" / "hooks"
scripts = {path.name for path in hook_dir.glob("*.sh")}

def referenced(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    commands = []
    for groups in data["hooks"].values():
        for group in groups:
            commands.extend(hook["command"] for hook in group["hooks"])
    names = set()
    for command in commands:
        names.update(re.findall(r"(?:hooks/)([A-Za-z0-9._-]+\.sh)", command))
    return data, names

claude, claude_names = referenced(hook_dir / "claude-hooks.json")
codex, codex_names = referenced(hook_dir / "hooks.json")
expected_codex = {
    "sdd-kickoff-guard.sh",
    "harness-doc-sync-guard.sh",
    "stop-warning-ack-guard.sh",
    "stale-branch-guard.sh",
}
if claude_names != scripts:
    raise SystemExit(f"Claude hook wiring mismatch: expected {sorted(scripts)}, got {sorted(claude_names)}")
if codex_names != expected_codex:
    raise SystemExit(f"Codex hook wiring mismatch: expected {sorted(expected_codex)}, got {sorted(codex_names)}")
if "asyncRewake" in json.dumps(codex):
    raise SystemExit("Codex hooks must not use unsupported asyncRewake")
PY
pass "Claude 11-hook and Codex 4-hook wiring"

python3 - "$ROOT" <<'PY'
import glob
import pathlib
import sys
try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

root = pathlib.Path(sys.argv[1])
paths = sorted(glob.glob(str(root / "codex/agents/*.toml")))
if len(paths) != 4:
    raise SystemExit(f"expected 4 Codex agents, found {len(paths)}")
expected = {
    "explorer": {"model": "gpt-5.6-terra", "model_reasoning_effort": "low", "sandbox_mode": "read-only"},
    "plan-implementer": {"model": "gpt-5.6", "model_reasoning_effort": "medium"},
    "plan-reviewer": {"model": "gpt-5.6", "model_reasoning_effort": "high", "sandbox_mode": "read-only"},
    "screenshot-verifier": {"model": "gpt-5.6-terra", "model_reasoning_effort": "low", "sandbox_mode": "read-only"},
}
for raw_path in paths:
    path = pathlib.Path(raw_path)
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    missing = {"name", "description", "developer_instructions"} - data.keys()
    if missing:
        raise SystemExit(f"{path}: missing {', '.join(sorted(missing))}")
    if not all(isinstance(data[key], str) and data[key].strip() for key in ("name", "description", "developer_instructions")):
        raise SystemExit(f"{path}: required string fields must be non-empty")
    if data["name"] not in expected:
        raise SystemExit(f"{path}: unexpected agent name {data['name']!r}")
    for key, value in expected[data["name"]].items():
        if data.get(key) != value:
            raise SystemExit(f"{path}: expected {key}={value!r}, got {data.get(key)!r}")
PY
pass "Codex agent TOML"

for script in "$ROOT"/woobin-harness/hooks/*.sh "$ROOT"/woobin-harness/scripts/*.sh "$ROOT"/woobin-harness/skills/git-guardrails-codex/scripts/*.sh "$ROOT"/bootstrap-codex.sh; do
  case "$(sed -n '1p' "$script")" in
    *bash*) bash -n "$script" ;;
    *) sh -n "$script" ;;
  esac
done
pass "shell syntax"

guard="$ROOT/woobin-harness/skills/git-guardrails-codex/scripts/block-dangerous-git.sh"
set +e
printf '%s' '{"tool_input":{"command":"git push origin main"}}' | "$guard" >/dev/null 2>&1
blocked_rc=$?
set -e
[ "$blocked_rc" -eq 2 ] || fail "Git guardrail block fixture: expected 2, got $blocked_rc"
printf '%s' '{"tool_input":{"command":"git status --short"}}' | "$guard" >/dev/null
pass "Git guardrail fixtures"

"$ROOT/scripts/test-hooks.sh" >/dev/null
pass "all shared hook fixtures"

"$ROOT/scripts/test-skills.sh" >/dev/null
pass "bundled skill asset fixtures"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

if command -v codex >/dev/null 2>&1; then
  mkdir -p "$tmp/codex-home"
  plugin_version=$(jq -r '.version' "$ROOT/woobin-harness/.codex-plugin/plugin.json")
  CODEX_HOME="$tmp/codex-home" "$ROOT/bootstrap-codex.sh" >/dev/null
  [ -f "$tmp/codex-home/AGENTS.md" ] || fail "bootstrap이 AGENTS.md를 설치하지 않았다"
  [ "$(find "$tmp/codex-home/agents" -type f -name '*.toml' | wc -l | tr -d ' ')" -eq 4 ] \
    || fail "bootstrap이 Codex agent 4개를 설치하지 않았다"
  CODEX_HOME="$tmp/codex-home" codex plugin list --json \
    | jq -e --arg version "$plugin_version" \
        '.installed[] | select(.pluginId == "woobin-harness@woobin-harness" and .version == $version)' >/dev/null
  cache="$tmp/codex-home/plugins/cache/woobin-harness/woobin-harness/$plugin_version"
  [ -f "$cache/hooks/hooks.json" ] || fail "Codex cache에 hooks/hooks.json이 없다"
  [ -f "$cache/scripts/codex-apply-patch-adapter.sh" ] || fail "Codex cache에 apply_patch adapter가 없다"
  [ "$(find "$cache/skills" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' ';' -print | wc -l | tr -d ' ')" -eq 19 ] \
    || fail "Codex cache가 스킬 19개를 모두 포함하지 않는다"

  prompt_dump="$tmp/codex-home/prompt-input.json"
  (cd "$ROOT" && CODEX_HOME="$tmp/codex-home" codex debug prompt-input 'component discovery probe') >"$prompt_dump"
  python3 - "$ROOT" "$prompt_dump" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
text = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
expected = {f"woobin-harness:{path.parent.name}" for path in (root / "woobin-harness" / "skills").glob("*/SKILL.md")}
found = set(re.findall(r"woobin-harness:[a-z0-9][a-z0-9-]*", text))
if found != expected:
    raise SystemExit(f"Codex prompt skill discovery mismatch: missing={sorted(expected-found)}, extra={sorted(found-expected)}")
if "This repository is the shared source for a personal Claude Code and Codex harness." not in text:
    raise SystemExit("project AGENTS.md was not loaded into the Codex prompt")
if "메모리 스코프 규칙 (소프트 2계층)" not in text:
    raise SystemExit("global AGENTS.md was not loaded into the Codex prompt")
PY
  pass "bootstrap + cache install + actual Codex discovery"
else
  printf '⚠ codex CLI가 없어 bootstrap install smoke test를 건너뛴다.\n' >&2
fi

probe="$tmp/probe.sh"
cat >"$probe" <<'EOF'
#!/bin/sh
jq -e '.tool_input.file_path | endswith("/woobin-harness/test.txt")' >/dev/null
EOF
chmod +x "$probe"
printf '%s' '{"cwd":"/tmp/project","tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: woobin-harness/test.txt\n*** End Patch"}}' \
  | "$ROOT/woobin-harness/scripts/codex-apply-patch-adapter.sh" "$probe"
pass "Codex apply_patch adapter fixture"

mkdir -p "$tmp/state/hooks/.stale-branch-pending"
printf 'stored warning' >"$tmp/state/hooks/.stale-branch-pending/test-session"
printf '%s' '{"session_id":"test-session","stop_hook_active":false,"last_assistant_message":"stale-branch 점검 완료"}' \
  | HARNESS_HOST=codex HARNESS_STATE_DIR="$tmp/state" "$ROOT/woobin-harness/hooks/stop-warning-ack-guard.sh"
[ ! -e "$tmp/state/hooks/.stale-branch-pending/test-session" ] || fail "Stop guard가 확인된 marker를 지우지 않았다"
pass "Codex Stop hook fixture"

DRY_RUN=1 "$ROOT/bootstrap-codex.sh" >/dev/null
pass "bootstrap-codex dry-run"

printf 'Codex validation complete.\n'
