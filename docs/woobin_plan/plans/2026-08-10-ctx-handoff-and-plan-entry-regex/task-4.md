# Task 4: 문서 동기화 검사기 + 가드 훅

**선행:** Task 3까지 끝나 있어야 한다(검사기가 새 훅을 인벤토리에서 찾을 수 있어야 한다).

**Files:**
- Create: `scripts/check-harness-docs.sh`
- Create: `woobin-harness/hooks/harness-doc-sync-guard.sh`
- Modify: `woobin-harness/hooks/hooks.json` (PostToolUse 배열)

**Interfaces:**
- Consumes: 없음(레포 상태를 직접 읽는다)
- Produces: `scripts/check-harness-docs.sh` — 종료코드 `0`(동기화됨) / `1`(불일치). 표준출력에 항목별 진단.
  Task 5가 이 스크립트를 마지막 검증 스텝에서 호출한다.

**배경 — 왜 체크리스트를 하나 더 쓰지 않는가:** `CLAUDE.md`는 "고칠 때 같이 고쳐야 하는 것"으로 문서 4종(README · `docs/workflow.html` · `docs/workflow-spec.md` · 훅 헤더)을 **이미 명시하고 있다.** 그런데 이 플랜을 쓰는 과정에서 그 규칙이 있는 상태로 `docs/workflow.html`이 빠졌고, 사용자가 물어봐서 발견됐다. 산문 체크리스트가 이미 한 번 실패했다는 뜻이다. HARNESS-LOG 규율 2 — **"소프트 지시로 못 막는 건 구조를 바꾼다"**(#6에서 "부분만 읽어라"가 안 먹혀 파일 자체를 쪼갠 것) — 가 적용되는 자리다. 개수와 인벤토리는 사람이 세지 않는다.

**설계 판단 — 실패와 경고를 나눈다:** 훅을 **추가**하면 사람용 요약(`workflow.html`)의 서술이 바뀐다(이번에 "유일한 세션 경계"가 거짓이 된 것처럼) → **실패**. 훅 내용만 **수정**하면 요약이 안 바뀔 수도 있다(Task 1의 정규식 수정이 그렇다) → **경고**. 모든 수정에 workflow.html을 요구하면 오탐이 쌓여 무시당하고, 그게 산문 규칙이 죽은 것과 같은 경로다.

- [ ] **Step 1: 검사기의 실패 케이스를 먼저 만든다**

지금 레포는 이미 드리프트 상태다(`docs/workflow-spec.md`가 스킬을 41개로 적고 있는데 실제는 42개). 이걸 검사기가 잡아야 한다.

Run:
```sh
echo "실제: hooks=$(ls woobin-harness/hooks/*.sh | wc -l | tr -d ' ') skills=$(ls -d woobin-harness/skills/*/ | wc -l | tr -d ' ') agents=$(ls woobin-harness/agents/*.md | wc -l | tr -d ' ')"
grep -n "### 스킬 [0-9]*개" docs/workflow-spec.md
```
Expected: 실제 스킬 개수와 `### 스킬 41개`가 어긋난다. 이 불일치를 Step 3의 검사기가 잡아내야 한다.

- [ ] **Step 2: 검사기를 작성**

`scripts/check-harness-docs.sh`를 아래 내용 그대로 만든다.

```sh
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
    || say "woobin-harness/ 가 바뀌었는데 plugin.json 의 version 을 안 올렸다 — 설치본은 옛날 그대로 돈다"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "동기화 안 됨 — 위 ✗ 를 고쳐라."
  exit 1
fi
[ "$warn" -ne 0 ] && echo "동기화됨 (⚠ 는 판단이 필요한 항목)." || echo "동기화됨."
exit 0
```

- [ ] **Step 3: 실행 권한을 주고 현재 드리프트를 잡는지 확인**

Run:
```sh
chmod +x scripts/check-harness-docs.sh && sh scripts/check-harness-docs.sh; echo "exit=$?"
```
Expected: `[개수]` 아래에 `docs/workflow-spec.md : 스킬 41개로 적혀 있는데 실제는 43개` 가 나오고 `exit=1`.
(Task 2에서 `handoff` 스킬을 추가했으므로 실제는 43이다.) 이 줄이 안 나오면 정규식을 고친다.

- [ ] **Step 4: 가드 훅을 작성**

`woobin-harness/hooks/harness-doc-sync-guard.sh`를 아래 내용 그대로 만든다.

```sh
#!/bin/sh
# 하네스 문서 동기화 가드 (PostToolUse:Edit|Write|MultiEdit)
# claude-harness 레포에서 woobin-harness/ 아래를 고치면 scripts/check-harness-docs.sh 를 돌려
# 불일치를 additionalContext 로 알린다. 세션 1회, 차단하지 않는다.
#
# 왜: CLAUDE.md 의 "같이 고쳐야 하는 것" 목록이 산문이라 2026-08-10 에 실제로 한 항목이 빠졌다.
# 규율 1(소프트 개입 우선)에 따라 차단은 안 하지만, 규율 2(구조를 바꾼다)에 따라 판정은
# 사람이 아니라 스크립트가 한다.

set -u

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$path" ] || exit 0
case "$path" in *woobin-harness/*) ;; *) exit 0 ;; esac

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$(pwd)
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
checker="$root/scripts/check-harness-docs.sh"
[ -x "$checker" ] || exit 0

# 세션 1회.
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
if [ -n "$session_id" ]; then
  marker_dir="${TMPDIR:-/tmp}/claude-harness-doc-sync"
  marker="$marker_dir/$session_id"
  [ -e "$marker" ] && exit 0
  mkdir -p "$marker_dir" 2>/dev/null
  : > "$marker" 2>/dev/null
fi

report=$(sh "$checker" 2>&1) || :
printf '%s' "$report" | grep -q '✗\|⚠' || exit 0

msg="[하네스 문서 동기화 검사] \`woobin-harness/\` 를 수정했습니다. 아래는 \`scripts/check-harness-docs.sh\` 결과입니다.

$report

✗ 는 반드시 고치고, ⚠ 는 판단해서 처리하세요. CLAUDE.md의 '고칠 때 같이 고쳐야 하는 것'이 산문이라
2026-08-10에 실제로 \`docs/workflow.html\` 이 빠진 적이 있어서 판정을 스크립트로 옮겼습니다.
이 알림은 세션 1회만 뜹니다."

jq -cn --arg ctx "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
```

- [ ] **Step 5: 훅에 실행 권한을 주고 단독 실행을 확인**

Run:
```sh
chmod +x woobin-harness/hooks/harness-doc-sync-guard.sh
rm -rf "${TMPDIR:-/tmp}/claude-harness-doc-sync"
printf '{"session_id":"t1","cwd":"%s","tool_input":{"file_path":"%s/woobin-harness/hooks/ctx-handoff-stop.sh"}}' "$PWD" "$PWD" \
  | sh woobin-harness/hooks/harness-doc-sync-guard.sh | jq -r '.hookSpecificOutput.additionalContext' | head -20
```
Expected: 검사 결과가 담긴 텍스트가 나온다(`[개수]` 등).

세션 1회 동작 확인:
```sh
printf '{"session_id":"t1","cwd":"%s","tool_input":{"file_path":"%s/woobin-harness/hooks/ctx-handoff-stop.sh"}}' "$PWD" "$PWD" \
  | sh woobin-harness/hooks/harness-doc-sync-guard.sh; echo "두번째=빈출력이어야 함"
```
Expected: 두 번째 호출은 아무것도 출력하지 않는다.

레포 밖에서는 조용한지 확인:
```sh
printf '{"session_id":"t2","cwd":"/tmp","tool_input":{"file_path":"/tmp/woobin-harness/x.sh"}}' \
  | sh woobin-harness/hooks/harness-doc-sync-guard.sh; echo "빈출력이어야 함"
```
Expected: 빈 출력.

- [ ] **Step 6: `hooks.json`의 PostToolUse에 등록**

`woobin-harness/hooks/hooks.json`의 `"PostToolUse"` 배열에 원소를 추가한다. 기존 원소(`plan-saved-session-boundary.sh`)는 건드리지 않는다. `matcher`는 기존 PostToolUse 엔트리의 서식을 그대로 따른다 — 먼저 확인한다.

Run: `jq '.hooks.PostToolUse' woobin-harness/hooks/hooks.json`

그 서식에 맞춰 추가:

```json
  {
    "matcher": "Edit|Write|MultiEdit",
    "hooks": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/harness-doc-sync-guard.sh",
        "timeout": 15,
        "statusMessage": "하네스 문서 동기화 확인 중..."
      }
    ]
  }
```

⚠️ `command`가 플러그인 캐시 경로를 가리키지만 검사기(`scripts/check-harness-docs.sh`)는 **작업 중인 레포**에서 찾는다(`git rev-parse --show-toplevel` 기준). 이게 의도다 — 검사 대상은 설치본이 아니라 지금 편집 중인 소스다.

- [ ] **Step 7: JSON 유효성과 플러그인 검증**

Run:
```sh
jq -e '[.hooks.PostToolUse[].hooks[].command] | map(select(test("harness-doc-sync-guard"))) | length == 1' \
  woobin-harness/hooks/hooks.json && claude plugin validate ./woobin-harness
```
Expected: `true` 출력 후 validate 통과.

- [ ] **Step 8: 커밋**

```bash
git add scripts/check-harness-docs.sh woobin-harness/hooks/harness-doc-sync-guard.sh woobin-harness/hooks/hooks.json
git commit -m "feat(hooks): 하네스 문서 동기화 검사기 + PostToolUse 가드 — 개수·인벤토리를 기계가 센다"
```
