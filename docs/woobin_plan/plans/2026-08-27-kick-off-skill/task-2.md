### Task 2: kickoff-guard hook + wiring + hook-count sync

**Files:**
- Create: `woobin-harness/hooks/kickoff-guard.sh` (mode 755)
- Modify: `woobin-harness/hooks/claude-hooks.json`
- Modify: `woobin-harness/hooks/hooks.json`
- Modify: `.gitignore`
- Modify: `scripts/test-hooks.sh`
- Modify: `scripts/test-skills.sh` (1 place)
- Modify: `README.md` (4 places)
- Modify: `docs/workflow-spec.md` (3 places)
- Modify: `docs/workflow.html` (1 place)
- Modify: `.claude-plugin/marketplace.json` (1 place)
- Modify: `woobin-harness/.claude-plugin/plugin.json` (1 place)

**Interfaces:**
- Consumes: the state-file contract from Task 1 — `.claude/kickoff.local.md` with frontmatter keys `active: true|false` and `stage: spec|plan|impl`. Also consumes the runtime path `${CLAUDE_PLUGIN_ROOT}/skills/kick-off/SKILL.md`, which the hook emits verbatim.
- Produces: env knobs `KICKOFF_STATE_FILE`, `KICKOFF_KEYWORD_PATTERN`, `KICKOFF_DRIFT_PATTERN`, and the marker directory `${TMPDIR}/claude-kickoff-drift/<session_id>`. Task 3 cites these in rule R20.

---

- [ ] **Step 1: Write the hook fixture first (it will fail)**

Append this block to `scripts/test-hooks.sh`, immediately before the final summary/`pass` lines at the end of the file (if the file ends with fixtures only, append at the end):

```sh
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
```

- [ ] **Step 2: Run the fixture to verify it fails**

Run: `./scripts/test-hooks.sh`
Expected: FAIL — the shell reports that `woobin-harness/hooks/kickoff-guard.sh` does not exist (`No such file or directory`).

- [ ] **Step 3: Write the hook**

Write `woobin-harness/hooks/kickoff-guard.sh` with exactly this content:

```sh
#!/bin/sh
# UserPromptSubmit — kick-off 워크플로우의 두 경로를 연다.
#
# 왜 훅이 필요한가: `kick-off` 스킬은 `disable-model-invocation: true`라 모델이 켤 수 없다.
# 그게 목적이다 — `brainstorming`이 `grill-me`와 트리거가 겹쳐 3일 246세션 발동 0회로 죽었다.
# 대신 사용자가 "킥오프"라고 **글자 그대로** 쓴 경우는 열어줘야 하고, 그 판정은 모델의 추론이
# 아니라 정규식이 한다. 모델이 "이건 kick-off 같은데?" 하고 고민할 여지가 없다.
#
# 두 번째 분기(이탈): 진입은 시켜도 그 뒤 대화가 새는 건 못 막는다. stage가 spec/plan인데
# 구현 의도 프롬프트가 오면 세션 1회만 알린다. **차단하지 않는다** — §6-1 소프트 개입 우선.
#
# 스킬 이름을 부르지 않고 파일 경로를 준다. `disable-model-invocation`이 걸린 스킬은 모델의
# Skill 목록에서 빠질 수 있고, 없는 스킬을 부르는 훅은 조용히 죽는다(#22·#28의 전례).

set -u

# 기본값에 괄호·파이프가 들어가므로 확장 전체를 반드시 큰따옴표로 감싼다.
# 안 감싸면 dash 계열 sh가 `(` 를 문법 오류로 읽는다.
STATE_FILE="${KICKOFF_STATE_FILE:-.claude/kickoff.local.md}"
# 하이픈으로 이어진 파일명(sdd-kickoff-guard.sh, kickoff-guard.sh) 안의 매치는 제외한다.
KEYWORD_PATTERN="${KICKOFF_KEYWORD_PATTERN:-(^|[^A-Za-z-])(kickoff|kick-off)([^A-Za-z-]|\$)|킥오프}"
DRIFT_PATTERN="${KICKOFF_DRIFT_PATTERN:-구현|코딩|코드 짜|바로 만들|implement}"

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
[ -n "$prompt" ] || exit 0

skill_path="${CLAUDE_PLUGIN_ROOT:-woobin-harness}/skills/kick-off/SKILL.md"

emit() {
  jq -cn --arg ctx "$1" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
  exit 0
}

# ── 분기 A: 키워드. 슬래시 호출은 이미 스킬이 뜨므로 건너뛴다.
case "$prompt" in
  /kick-off*|/woobin-harness:kick-off*) ;;
  *)
    if printf '%s' "$prompt" | grep -qiE "$KEYWORD_PATTERN"; then
      emit "[kick-off] 프롬프트에 킥오프 키워드가 있습니다.

\`${skill_path}\` 를 Read하고 그 지시를 따르세요. **스킬 이름으로 호출하지 말고 파일을 직접 읽으세요** —
이 스킬은 사람만 부를 수 있게 막혀 있어(\`disable-model-invocation\`) 모델의 Skill 목록에 없을 수 있습니다.

사용자가 킥오프를 뜻한 게 아니라면(예: 이 훅 자체를 고치는 중) 한 줄로 밝히고 그냥 진행하세요."
    fi
    ;;
esac

# ── 분기 B: 이탈. 상태 파일이 살아 있고 stage가 spec/plan인데 구현 의도가 왔다.
[ -f "$STATE_FILE" ] || exit 0
grep -qE '^active:[[:space:]]*true[[:space:]]*$' "$STATE_FILE" || exit 0
stage=$(sed -n 's/^stage:[[:space:]]*\([a-z][a-z]*\).*/\1/p' "$STATE_FILE" | head -1)
case "$stage" in
  spec) next="스펙을 굳히는 중입니다(\`grill-me\`). 결정 원장의 미결이 비기 전에는 코드로 넘어가지 마세요." ;;
  plan) next="플랜을 쓰는 중입니다(\`writing-plans\`). 플랜이 저장되기 전에는 코드로 넘어가지 마세요." ;;
  *) exit 0 ;;
esac
printf '%s' "$prompt" | grep -qiE "$DRIFT_PATTERN" || exit 0

# 세션당 1회.
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
marker_dir="${TMPDIR:-/tmp}/claude-kickoff-drift"
if [ -n "$session_id" ]; then
  marker="$marker_dir/$session_id"
  [ -e "$marker" ] && exit 0
  mkdir -p "$marker_dir" 2>/dev/null
  : > "$marker" 2>/dev/null
fi

emit "[kick-off 이탈 알림] ${STATE_FILE} 의 stage가 \`${stage}\` 입니다.

${next}

지금 단계를 끝냈다면 ${STATE_FILE} 의 stage를 다음 값으로 갱신하고 계속하세요
(\`spec\` → \`plan\` → \`impl\`). 작업이 끝났으면 \`active: false\`로 바꾸면 이 알림은 멈춥니다.

이 알림은 세션당 한 번만 뜹니다. 차단하지 않으니 판단은 당신이 하세요 — 사용자가 의도적으로
지금 코드를 건드리라고 했다면 한 줄로 밝히고 그대로 진행하세요."
```

Then make it executable:

```bash
chmod 755 woobin-harness/hooks/kickoff-guard.sh
```

- [ ] **Step 4: Run the fixture to verify it passes**

Run: `./scripts/test-hooks.sh`
Expected: PASS, including the line `✓ kickoff-guard keyword/drift/once`

If the drift assertion fails while the keyword one passes, check that the `stage` value parsed out of the fixture state file is exactly `spec` — the `sed` expression stops at the first non-lowercase character.

- [ ] **Step 5: Wire the hook into both manifests**

`woobin-harness/hooks/claude-hooks.json` — inside `hooks.UserPromptSubmit`, append this object as the **last** element of that array:

```json
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/kickoff-guard.sh",
            "timeout": 10,
            "statusMessage": "kick-off 진입·이탈 점검 중..."
          }
        ]
      }
```

`woobin-harness/hooks/hooks.json` — inside `hooks.UserPromptSubmit`, append this object as the last element (note the Codex quoting style, which differs from the Claude file):

```json
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/kickoff-guard.sh\"",
            "timeout": 10,
            "statusMessage": "kick-off 진입·이탈 점검 중..."
          }
        ]
      }
```

Verify both files are still valid JSON:

```bash
jq empty woobin-harness/hooks/claude-hooks.json && jq empty woobin-harness/hooks/hooks.json && echo JSON-OK
```
Expected: `JSON-OK`

- [ ] **Step 6: Ignore the state file**

Append this line to `.gitignore`, after the existing `.claude/agent-memory-local/` line:

```
.claude/kickoff.local.md
```

Verify:

```bash
printf -- '---\nactive: true\n---\n' > .claude/kickoff.local.md 2>/dev/null || mkdir -p .claude && printf -- '---\nactive: true\n---\n' > .claude/kickoff.local.md
git check-ignore -v .claude/kickoff.local.md && rm .claude/kickoff.local.md
```
Expected: a line naming `.gitignore` and the new pattern, then the file is removed.

- [ ] **Step 7: Update the hook counts — 12 → 13**

`scripts/test-skills.sh` at line 82, replace:

```python
expected = {"hooks": 12, "agents": 4, "skills": 21}
```
with:
```python
expected = {"hooks": 13, "agents": 4, "skills": 21}
```

`README.md` — four edits:
- line 11: `훅 12개를 붙인다` → `훅 13개를 붙인다`
- line 12: `검증된 훅 4개를 붙이고` → `검증된 훅 5개를 붙이고`
- line 33: `│   ├── hooks/claude-hooks.json       Claude Code 훅 12개` → `… Claude Code 훅 13개`
- line 34: `│   ├── hooks/hooks.json              Codex가 자동 발견하는 안전한 훅 4개` → `… 안전한 훅 5개`
- line 35: `│   ├── hooks/*.sh                    12개 (공유 훅 스크립트)` → `│   ├── hooks/*.sh                    13개 (공유 훅 스크립트)`

`.claude-plugin/marketplace.json` — in `plugins[0].description`, `훅 12개` → `훅 13개`.

`woobin-harness/.claude-plugin/plugin.json` — in `description`, `훅 12개` → `훅 13개`. **Do not bump the version again** — Task 1 already set `1.15.0`.

- [ ] **Step 8: Update `docs/workflow-spec.md` §4**

Three edits.

(a) Line 616: `### 훅 12개` → `### 훅 13개`

(b) Append this row to the end of the hook table in that section:

```
| `kickoff-guard.sh` | UserPromptSubmit | [A] 킥오프 키워드(하이픈 파일명 제외) / [B] 상태 파일 `active: true` + `stage: spec\|plan` + 구현 의도 정규식 | additionalContext. [A]는 매번, [B]는 세션 1회 | R20 |
```

(c) In the paragraph that begins `Codex는 이 12개 중`, change `이 12개 중` → `이 13개 중`, and change the wired list `` `sdd-kickoff-guard.sh`, `harness-doc-sync-guard.sh`, `stale-branch-guard.sh`, `stop-warning-ack-guard.sh` 4개만 연결한다`` → `` `sdd-kickoff-guard.sh`, `kickoff-guard.sh`, `harness-doc-sync-guard.sh`, `stale-branch-guard.sh`, `stop-warning-ack-guard.sh` 5개만 연결한다``.

(d) In the `**조정 손잡이**` fenced block in that same section, append this line at the end of the block:

```
KICKOFF_STATE_FILE=.claude/kickoff.local.md   KICKOFF_KEYWORD_PATTERN   KICKOFF_DRIFT_PATTERN
```

- [ ] **Step 9: Update `docs/workflow.html`**

At line 411, replace:

```html
  <li><b>Codex 훅 4개</b>
  플랜 킥오프, 문서 동기화, stale-branch 경고와 응답 검사만 연결한다. 비동기 idle handoff와 Claude transcript·모델명 의존 훅은 미연결이다.</li>
```

with:

```html
  <li><b>Codex 훅 5개</b>
  플랜 킥오프, kick-off 진입·이탈, 문서 동기화, stale-branch 경고와 응답 검사만 연결한다. 비동기 idle handoff와 Claude transcript·모델명 의존 훅은 미연결이다.</li>
```

- [ ] **Step 10: Run the full check for this task**

Run: `./scripts/test-hooks.sh && ./scripts/check-harness-docs.sh`
Expected: `test-hooks.sh` all `✓` (a pre-existing `stale-branch-guard` failure is a known defect recorded in PR #26 — if it appears, note it and continue); `check-harness-docs.sh` prints no `✗`.

A `⚠ 훅·에이전트가 바뀌었는데 home/HARNESS-LOG.md 에 항목이 없다` warning is expected here — Task 3 adds that entry.

- [ ] **Step 11: Commit**

```bash
git add woobin-harness/hooks/kickoff-guard.sh woobin-harness/hooks/claude-hooks.json \
        woobin-harness/hooks/hooks.json .gitignore \
        scripts/test-hooks.sh scripts/test-skills.sh README.md \
        docs/workflow-spec.md docs/workflow.html \
        .claude-plugin/marketplace.json woobin-harness/.claude-plugin/plugin.json
git commit -m "feat(hooks): kickoff-guard — 키워드 진입 + stage 이탈 시 세션 1회 알림"
```
