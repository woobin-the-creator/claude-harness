### Task 1: 스테일 설치본 SessionStart 훅

플러그인 설치본은 `~/.claude/plugins/cache/<mp>/<plugin>/<version>/`에 **버전별로 굳은 복사본**이다. 레포를 고쳐도 `version`을 안 올리거나 `plugin update`를 안 돌리면 설치본은 옛날 그대로 돈다. 이 레포에서 2026-08-08과 2026-08-19에 실제로 두 번 났고, `CLAUDE.md`가 사람에게 수동 확인 명령을 적어 두는 방식으로만 대응하고 있다. 이 태스크는 그 확인을 SessionStart 훅으로 자동화한다.

**지금 이 머신이 그 상태다** — 설치본 `1.12.0`(`gitCommitSha` `d95004b`), 레포 `1.13.0`(HEAD `9bd3634`). Step 6의 라이브 검증에서 이 훅이 실제로 발화해야 한다.

**Files:**
- Create: `woobin-harness/hooks/plugin-update-guard.sh`
- Modify: `woobin-harness/hooks/claude-hooks.json` (`SessionStart` 배열에 항목 추가)
- Modify: `scripts/test-hooks.sh` (fixture 추가)

`woobin-harness/hooks/hooks.json`(Codex용)은 **건드리지 않는다.** Codex는 자기 `plugin_update_guard.py`를 이미 갖고 있고, 이 훅은 `~/.claude/plugins/` 레이아웃에만 의존한다.

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: `woobin-harness/hooks/plugin-update-guard.sh` — SessionStart 훅. stdin으로 `{"session_id": "..."}` 를 받고, 드리프트가 있으면 `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}`를 stdout에 한 줄 JSON으로 낸다. 드리프트가 없거나 판단 불가면 **아무것도 출력하지 않고 `exit 0`**. Task 7이 이 파일명을 `docs/workflow-spec.md` §4 인벤토리에 적는다.

읽는 파일 두 개의 실제 모양(2026-08-26 확인):

```jsonc
// ~/.claude/plugins/known_marketplaces.json
{ "woobin-harness": {
    "source": { "source": "directory", "path": "/Volumes/LinuxVM/mac_wb_data/codespace/claude-harness" },
    "installLocation": "/Volumes/LinuxVM/mac_wb_data/codespace/claude-harness" } }

// ~/.claude/plugins/installed_plugins.json
{ "plugins": { "woobin-harness@woobin-harness": [
    { "installPath": ".../cache/woobin-harness/woobin-harness/1.12.0",
      "version": "1.12.0", "gitCommitSha": "d95004b27ad4c7c3d6618c8861da49d2f2ffb4d1" } ] } }
```

---

- [ ] **Step 1: 실패하는 fixture를 먼저 쓴다**

`scripts/test-hooks.sh`의 마지막 `pass "..."` 줄 **뒤**, `printf 'All ...'` 요약줄 **앞**에 아래를 추가한다. 이 스크립트는 `set -eu`이고 `TEST_HOME`·`TEST_ROOT`·`assert_json`·`assert_silent`·`fail`·`pass`가 이미 정의돼 있다.

```sh
# plugin-update-guard: 버전 드리프트 / 커밋 드리프트 / 정상 / 판단불가 네 갈래.
pug_src="$TEST_ROOT/pug-src"
mkdir -p "$pug_src/woobin-harness/.claude-plugin" "$TEST_HOME/.claude/plugins"
printf '{"name":"woobin-harness","version":"1.13.0"}\n' \
  >"$pug_src/woobin-harness/.claude-plugin/plugin.json"
git -C "$pug_src" init -q
git -C "$pug_src" -c user.email=t@t -c user.name=t add -A
git -C "$pug_src" -c user.email=t@t -c user.name=t commit -qm first
pug_first=$(git -C "$pug_src" rev-parse HEAD)
printf 'second\n' >"$pug_src/second.txt"
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
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("1")' \
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
```

- [ ] **Step 2: 실패를 확인한다**

Run: `./scripts/test-hooks.sh`
Expected: FAIL — `plugin-update-guard.sh` 파일이 없어서 `assert_json`이 빈 문자열을 받고 `plugin-update-guard: missing SessionStart output`로 죽는다.

- [ ] **Step 3: 훅을 구현한다**

Create `woobin-harness/hooks/plugin-update-guard.sh` (실행 권한 필요):

```bash
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
```

그다음:

```bash
chmod +x woobin-harness/hooks/plugin-update-guard.sh
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `./scripts/test-hooks.sh`
Expected: PASS — `✓ plugin-update-guard drift/healthy/absent branches`

`stale-branch-guard: marker missing` 실패가 같이 보일 수 있다. **이건 이 태스크와 무관한 기존 결함**이고 `home/HARNESS-LOG.md` #26에 기록돼 있다. 고치려 들지 말고 그대로 둔다.

- [ ] **Step 5: 훅을 wiring 한다**

`woobin-harness/hooks/claude-hooks.json`의 `SessionStart` 배열에 두 번째 그룹으로 추가한다. 기존 `stale-branch-guard` 그룹은 그대로 둔다:

```json
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stale-branch-guard.sh",
            "timeout": 15,
            "statusMessage": "stale-branch 점검 중..."
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/plugin-update-guard.sh",
            "timeout": 10,
            "statusMessage": "플러그인 설치본 최신 여부 점검 중..."
          }
        ]
      }
    ]
```

Run: `jq -e '.hooks.SessionStart | length == 2' woobin-harness/hooks/claude-hooks.json`
Expected: `true`

- [ ] **Step 6: 이 머신에서 라이브로 확인한다**

fixture가 아니라 실제 상태 파일로 발화하는지 본다. 계획 시점(2026-08-26) 이 머신은 설치본 `1.12.0` · 레포 `1.13.0`이라 **경고가 나와야 한다**:

```bash
printf '{"session_id":"live"}' | ./woobin-harness/hooks/plugin-update-guard.sh | jq -r '.hookSpecificOutput.additionalContext'
```

Expected: `⚠ woobin-harness 설치본이 레포보다 뒤처져 있다 — 설치본 1.12.0 · 레포 1.13.0. ...`

출력이 비어 있으면 그 사이에 누가 `plugin update`를 돌린 것이다. 그때는 아래로 두 값을 직접 비교해 원인을 확인하고, 훅이 아니라 상태가 바뀐 것임을 확인한 뒤 넘어간다:

```bash
jq -r '.plugins["woobin-harness@woobin-harness"][0].version' ~/.claude/plugins/installed_plugins.json
jq -r '.version' woobin-harness/.claude-plugin/plugin.json
```

- [ ] **Step 7: 훅 개수를 단언하는 곳들을 갱신한다**

훅이 11개 → **12개**가 된다. `scripts/check-harness-docs.sh`가 개수를 실제로 세서 문서와 대조하므로, 아래를 안 고치면 하드 실패(`✗`)한다.

| 파일 | 현재 | 바꿀 값 |
|---|---|---|
| `README.md` (`hooks/*.sh … 11개` 줄) | 11 | 12 |
| `README.md:11` (`훅 11개를 붙인다`) | 11 | 12 |
| `README.md:33` (`hooks/claude-hooks.json  Claude Code 훅 11개`) | 11 | 12 |
| `woobin-harness/.claude-plugin/plugin.json` (`description`의 `훅 11개`) | 11 | 12 |
| `.claude-plugin/marketplace.json:11` (`훅 11개`) | 11 | 12 |
| `docs/workflow-spec.md:569` (`### 훅 11개`) | 11 | 12 |
| `scripts/test-skills.sh:82` (`expected = {"hooks": 11, ...}`) | 11 | 12 |

`README.md`의 정확한 문구는 `grep -n '11개' README.md`로 먼저 확인한다.

- [ ] **Step 8: `docs/workflow-spec.md` §3 규칙과 §4 인벤토리를 채운다**

**§4 인벤토리 표** — `:581`의 `stale-branch-guard.sh` 행 바로 아래에 한 행을 추가한다. 열 구성은 그 표를 그대로 따른다:

```
| `plugin-update-guard.sh` | SessionStart | 설치본 version ≠ 소스 version, 또는 같은 version인데 설치본 커밋이 소스보다 뒤 | additionalContext로 갱신 절차 4단계 안내. 차단하지 않음 | R20 |
```

규칙 번호는 §3의 마지막 번호 +1을 쓴다. `grep -n '^### R' docs/workflow-spec.md | tail -3`으로 확인하고, 위의 `R20`을 실제 번호로 바꾼다.

**§3 규칙** — 같은 번호로 §3에 절을 추가한다. `무효화 조건`을 반드시 채운다. 못 채우면 아직 규칙이 아니다:

```markdown
### R20 설치본이 소스보다 뒤처지면 세션 시작에 알린다

**문제** 플러그인 설치본은 `~/.claude/plugins/cache/<mp>/<plugin>/<version>/`에 버전별로 굳은
복사본이다. 레포를 고쳐도 `version`을 안 올리거나 `plugin update`를 안 돌리면 설치본은 옛날
그대로 돈다. 2026-08-08(스킬 추가 후 version 누락)과 2026-08-19(레포 1.5.0 · 설치본 1.6.0으로
번호가 역전돼 갱신이 막힘) 두 번 났다. `CLAUDE.md`가 확인 명령을 적어 두는 방식으로만 대응했는데,
사람이 기억해서 쳐야 하는 검사는 안 쳐진다 — 그 실패 형태는 §4의 "게이트가 9일간 죽어 있었다"와 같다.

**기전** `plugin-update-guard.sh` (SessionStart) — `known_marketplaces.json`에서 소스 경로를,
`installed_plugins.json`에서 설치 버전과 `gitCommitSha`를 읽어 소스의 `plugin.json`과 대조한다.
버전이 다르거나, 버전이 같은데 설치 커밋이 소스 HEAD보다 뒤면 갱신 절차를 additionalContext로 준다.
읽기 전용이고 fetch하지 않는다 — 이미 로컬에 있는 커밋만 센다. 차단하지 않는다.

**대가** 소스가 로컬 디렉터리 마켓플레이스일 때만 의미가 있다. github 소스로 설치한 플러그인은
`installLocation`이 클론 경로라 커밋 비교는 되지만 사용자가 그 클론을 직접 갱신하지 않으면 항상
"뒤처짐"으로 보일 수 있다. 그래서 이 훅은 `woobin-harness` 한 플러그인만 본다.

**무효화 조건** — (1) Claude Code가 `~/.claude/plugins/` 레이아웃(두 JSON 파일의 키 구조)을 바꾸면
훅은 조용히 `exit 0`으로 빠진다. 이때는 훅이 죽은 게 아니라 **판단 불가**로 빠지는 것이라 티가
안 난다. 레이아웃 변경을 발견하면 `scripts/test-hooks.sh`의 fixture부터 고쳐라. (2) 설치본 갱신이
사람 개입 없이 자동으로 되도록 바뀌면 이 규칙은 불필요해진다.
```

- [ ] **Step 9: `docs/workflow.html`에 한 줄 반영한다**

`check-harness-docs.sh`는 훅이 **추가**되면 `docs/workflow.html`이 같이 바뀌었는지 하드 검사한다(`✗`). 게이트를 통과시키려고 아무 줄이나 고치지 마라 — 사람용 요약에 실제로 새 동작이 하나 생겼다.

세션 시작 시 무엇이 자동으로 점검되는지 서술하는 위치를 찾는다:

```bash
grep -n 'stale-branch\|세션 시작\|SessionStart' docs/workflow.html
```

그 근처에 한 줄을 추가한다:

```html
  <li><b>설치본 최신 여부</b>
  세션이 열릴 때 플러그인 설치본이 레포보다 뒤처졌는지 본다. 뒤처졌으면 갱신 절차를 알려준다 — 레포를 고쳐도 <code>version</code>을 안 올리면 설치본은 옛날 그대로 돈다.</li>
```

주변 마크업(`<li><b>…</b>` 형태)이 다르면 그 파일의 관례를 따른다.

- [ ] **Step 10: 버전을 올린다**

`woobin-harness/` 아래가 바뀌면 두 `plugin.json`의 `version`을 **같이** 올려야 한다(`check-harness-docs.sh`가 하드 검사한다). 이 플랜 전체가 하나의 변경 묶음이므로 **여기서 한 번만** 올리고, Task 2~7은 다시 올리지 않는다.

먼저 캐시에 이미 굳은 버전을 확인한다 — 레포 값이 설치본보다 뒤처져 있으면 +1이 이미 굳은 디렉터리에 떨어져 갱신이 조용히 안 된다:

```bash
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/
jq -r '.version' woobin-harness/.claude-plugin/plugin.json
```

계획 시점 확인값: 캐시 최대 `1.12.0`, 레포 `1.13.0`. **`1.14.0`으로 올린다.** 캐시에 `1.13.0`도 `1.14.0`도 없으므로 안전하다. 위 두 명령의 출력이 이와 다르면 캐시에 없는 다음 번호를 고르고, 무엇을 골랐는지 커밋 메시지에 적는다.

```bash
jq '.version = "1.14.0"' woobin-harness/.claude-plugin/plugin.json > /tmp/pj.json && mv /tmp/pj.json woobin-harness/.claude-plugin/plugin.json
jq '.version = "1.14.0"' woobin-harness/.codex-plugin/plugin.json > /tmp/pjc.json && mv /tmp/pjc.json woobin-harness/.codex-plugin/plugin.json
```

`jq`가 들여쓰기를 바꿀 수 있다 — `git diff`로 `version` 줄 하나만 바뀌었는지 확인하고, 아니면 에디터로 그 줄만 고친다.

- [ ] **Step 11: 문서 동기화 게이트를 통과시킨다**

Run: `./scripts/check-harness-docs.sh`
Expected: `동기화됨.` 또는 `동기화됨 (⚠ 는 판단이 필요한 항목).`

`⚠ home/HARNESS-LOG.md 에 항목이 없다`는 경고는 여기서 무시한다 — Task 7이 이 플랜 전체를 한 항목으로 기록한다.

`✗`가 하나라도 남으면 Step 7~10에서 빠뜨린 게 있다. 메시지가 어느 파일의 어느 숫자인지 정확히 알려준다.

- [ ] **Step 12: 커밋**

```bash
git add woobin-harness scripts README.md docs/workflow-spec.md docs/workflow.html .claude-plugin/marketplace.json
git commit -m "feat(hooks): SessionStart에서 스테일 플러그인 설치본을 감지한다"
```
