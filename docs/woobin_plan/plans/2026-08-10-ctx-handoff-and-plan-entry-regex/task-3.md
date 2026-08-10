# Task 3: 컨텍스트 자동 핸드오프 훅 신설

**선행:** Task 2(`handoff` 스킬)가 끝나 있어야 한다. 이 훅은 스킬을 이름으로 부른다.

**Files:**
- Create: `woobin-harness/hooks/ctx-handoff-stop.sh`
- Modify: `woobin-harness/hooks/hooks.json` (Stop 배열)
- Modify: `woobin-harness/hooks/idle-handoff-stop.sh` (주석 1개 추가만 — 본문 문구는 건드리지 않는다)

**Interfaces:**
- Consumes: Stop 훅 입력 JSON — `session_id`, `transcript_path`, `stop_hook_active`
- Produces: 종료코드 `2` + stderr 메시지(모델에게 전달됨) / 조건 미충족 시 `0`.
  환경변수 `CTX_HANDOFF_THRESHOLD`(기본 `300000`). Task 4가 이 이름을 `docs/workflow-spec.md` §4 "조정 손잡이" 블록에 등재한다.

**배경:** `statusline/ctx-warn-statusline.sh`가 200k/300k를 이미 표시하지만 그건 statusline 텍스트다. HARNESS-LOG #3 재측정에서 경고 도입 뒤에도 351k 세션이 발생했고, 2026-08-10 7일 전수에서는 300k를 넘긴 뒤에도 계속 돈 세션이 10건 / 그 초과분 cache read만 $88.47이었다.

- [ ] **Step 1: 실패하는 테스트를 먼저 작성**

`/tmp/t2.sh`로 저장한다. 가짜 transcript를 만들어 훅에 먹인다. **레포 루트에서 실행한다.**

```sh
#!/bin/sh
HOOK=woobin-harness/hooks/ctx-handoff-stop.sh
TD=$(mktemp -d)
mk() { # $1=ctx토큰 → transcript 1줄
  printf '{"type":"assistant","message":{"usage":{"input_tokens":2,"cache_read_input_tokens":%s,"cache_creation_input_tokens":0}}}\n' "$1" > "$TD/t.jsonl"
}
run() { # $1=session_id  $2=stop_hook_active
  printf '{"session_id":"%s","transcript_path":"%s","stop_hook_active":%s}' "$1" "$TD/t.jsonl" "$2" | sh "$HOOK" 2>"$TD/err"; echo $?
}
rm -rf "${TMPDIR:-/tmp}/claude-ctx-handoff"

mk 100000; [ "$(run s-low false)" = "0" ] && echo "ok  : 100k → 통과" || echo "FAIL: 100k인데 발화"
mk 350000; [ "$(run s-hi false)" = "2" ] && echo "ok  : 350k → exit 2" || echo "FAIL: 350k인데 미발화"
grep -q "handoff 스킬" "$TD/err" && echo "ok  : stderr에 스킬 호출 지시" || echo "FAIL: 스킬 호출 지시 없음"
grep -q "idle-handoffs" "$TD/err" && echo "ok  : stderr에 저장 경로" || echo "FAIL: 경로 없음"
mk 350000; [ "$(run s-hi false)" = "0" ] && echo "ok  : 같은 세션 재발화 안 함" || echo "FAIL: 세션 2회 발화"
mk 350000; [ "$(run s-act true)" = "0" ] && echo "ok  : stop_hook_active면 통과" || echo "FAIL: 루프 위험"
rm -rf "$TD"
```

- [ ] **Step 2: 실행해서 실패를 확인**

Run: `sh /tmp/t2.sh`
Expected: 파일이 없으므로 전부 `FAIL` 또는 `sh: ...: No such file or directory`.

- [ ] **Step 3: 훅을 작성**

`woobin-harness/hooks/ctx-handoff-stop.sh`를 아래 내용 그대로 만든다.

```sh
#!/bin/sh
# 컨텍스트 자동 핸드오프 (Stop 훅) — 턴이 CTX_HANDOFF_THRESHOLD(기본 300k) 이상에서 끝나면
# exit 2 로 모델을 깨워 handoff 스킬로 핸드오프 문서를 쓰게 하고, 새 세션 전환을 안내한다.
#
# 왜: ctx-warn-statusline.sh 가 200k/300k 를 이미 표시하지만 그건 statusline 텍스트다.
# 2026-07-28(#3) 재측정에서 경고 도입 뒤에도 351k 세션이 발생했고 — "인지 수단만으로는 못 막는다" —
# 2026-08-10 7일 전수에서는 300k 를 넘긴 뒤에도 계속 돈 세션이 10건, 그 구간이 45k floor 대비
# 초과로 낸 cache read 가 $88.47(주간 총지출의 10.4%)였다.
# 이 하네스에서 ✅ 로 재측정된 개입(#1 핸드오프, #2 위임)은 전부 경고가 아니라 **대체 경로를
# 만들어 준** 형태였다. 그래서 여기서도 알리는 대신 문서를 만들게 한다.
#
# idle-handoff-stop.sh 와의 차이 — 복제할 때 이 세 줄을 같이 옮기지 말 것:
#   1. asyncRewake·폴링 루프 없음. 판정 대상이 "지금 끝난 턴의 크기"라 대기할 이유가 없다.
#   2. 재주입 방지가 mtime 신선도가 아니라 세션 1회 마커 + stop_hook_active 다.
#      mtime 방식은 "유휴 국면"이라는 **반복되는** 상태를 판정하려고 도입한 것이고(#1의 무한루프 사고),
#      여기서는 세션당 한 번뿐이라 마커가 더 단순하고 루프 위험이 없다.
#   3. 트리거가 시간이 아니라 크기다. 그래서 자리비움과 무관하게 발화한다.
#
# 문서 계약은 여기 쓰지 않고 handoff 스킬(woobin-harness/skills/handoff/SKILL.md)이 소유한다.
# 훅 2개가 같은 문장을 각자 갖고 있으면 한쪽만 고쳐져 갈라진다 — #16 이 그 사고였다.

set -u

TH=${CTX_HANDOFF_THRESHOLD:-300000}

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

# 우리가 깨워서 도는 턴에서 또 발화하면 무한 루프다.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0

tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$tp" ] || exit 0
[ -f "$tp" ] || exit 0

# /close-session 으로 닫힌 세션은 건드리지 않는다(마커 소유는 idle-return-guard.sh).
[ -f "$HOME/.claude/idle-handoff/$sid.handoff-done" ] && exit 0

# 세션 1회.
marker_dir="${TMPDIR:-/tmp}/claude-ctx-handoff"
marker="$marker_dir/$sid"
[ -e "$marker" ] && exit 0

# 현재 컨텍스트 = transcript 마지막 assistant usage.
# ctx-warn-statusline.sh · plan-session-boundary-guard.sh 와 **같은 식**을 쓴다.
# 세 곳이 다른 값을 말하면 사용자가 어느 쪽을 믿을지 몰라진다.
ctx=$(tail -n 40 "$tp" 2>/dev/null | jq -rR '
    fromjson? // empty
    | select(.type == "assistant")
    | .message.usage // empty
    | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)
  ' 2>/dev/null | tail -n 1)
case "$ctx" in ''|*[!0-9]*) ctx=0 ;; esac
[ "$ctx" -ge "$TH" ] || exit 0

mkdir -p "$marker_dir" 2>/dev/null
: > "$marker" 2>/dev/null

doc="$HOME/.claude/idle-handoffs/${sid}.md"
mkdir -p "$HOME/.claude/idle-handoffs" 2>/dev/null
ctx_k=$((ctx / 1000))

cat >&2 <<EOF
[컨텍스트 자동 핸드오프] 이번 턴이 ${ctx_k}k 컨텍스트에서 끝났습니다. 이 세션을 그대로 이어가면 남은 모든 요청이 이 ${ctx_k}k 를 cache read 로 다시 청구합니다(2026-08-10 7일 전수: 300k 초과 세션 10건이 그 초과분으로만 \$88.47).

handoff 스킬을 호출해 이 대화의 핸드오프 문서를 작성하세요. 문서는 반드시 다음 경로에 저장하세요: ${doc}

작성이 끝나면 다른 작업 없이 아래 한 줄만 남기고 턴을 마치세요. 사용자에게 질문하지 마세요.
"컨텍스트가 ${ctx_k}k 라 핸드오프 문서를 ${doc} 에 저장했어요. /clear 후 이 문서를 읽고 이어가면 이후 요청이 훨씬 쌉니다."
EOF
exit 2
```

- [ ] **Step 4: 실행 권한을 주고 테스트를 통과시킨다**

Run:
```sh
chmod +x woobin-harness/hooks/ctx-handoff-stop.sh && sh /tmp/t2.sh
```
Expected: `ok  :` 6줄. `FAIL`이 하나도 없어야 한다.

- [ ] **Step 5: `hooks.json`에 등록**

`woobin-harness/hooks/hooks.json`의 `"Stop"` 배열에 **세 번째 원소**로 아래를 추가한다. 기존 두 원소(`idle-handoff-stop.sh`, `stop-warning-ack-guard.sh`)는 건드리지 않는다. `asyncRewake`를 넣지 않는다 — 대기하지 않으므로 필요 없고, 넣으면 판정이 턴 종료 시점에서 벗어난다.

```json
  {
    "hooks": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/ctx-handoff-stop.sh",
        "timeout": 10,
        "statusMessage": "컨텍스트 크기 확인 중..."
      }
    ]
  }
```

참고 — 기존 Stop 배열의 형태(이 서식을 그대로 따른다):

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/idle-handoff-stop.sh",
        "timeout": 3900,
        "statusMessage": "자리비움 감시 대기 중...",
        "asyncRewake": true
      }
    ]
  },
  {
    "hooks": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-warning-ack-guard.sh",
        "timeout": 10,
        "statusMessage": "stale-branch 경고 전달 확인 중..."
      }
    ]
  }
]
```

- [ ] **Step 6: JSON 유효성과 플러그인 검증**

Run:
```sh
jq -e '.hooks.Stop | length == 3' woobin-harness/hooks/hooks.json && claude plugin validate ./woobin-harness
```
Expected: `true` 출력 후 validate 통과.
(경로 키가 `.hooks.Stop`이 아니면 `jq 'paths(scalars) | select(index("Stop"))' woobin-harness/hooks/hooks.json`으로 실제 경로를 먼저 확인한다.)

- [ ] **Step 7: `idle-handoff-stop.sh`에 스킬 실체화 사실을 주석으로 남긴다**

**본문 문구(80·85행)는 건드리지 않는다** — Task 2에서 `handoff` 스킬을 실제로 만들었으므로 그 참조는 이제 유효하다. 11행(`#  지우는 레이스로 50분 주기 무한 루프가 실제 발생 — 2026-07-24)`) 아래에 아래를 덧붙인다.

```sh
# 2026-08-10: 이 훅이 부르는 `handoff` 스킬이 그동안 존재하지 않았다(#16 과 같은 드리프트).
# woobin-harness/skills/handoff/SKILL.md 로 실체를 만들었고, 문서 계약은 그쪽이 단일 소유한다.
# 여기(80·85행)와 ctx-handoff-stop.sh 는 스킬 이름과 저장 경로만 넘긴다 — 계약을 복제하지 마라.
```

- [ ] **Step 8: 훅 2개가 같은 스킬·같은 경로 규약을 쓰는지 확인**

Run: `grep -n "handoff 스킬\|idle-handoffs" woobin-harness/hooks/idle-handoff-stop.sh woobin-harness/hooks/ctx-handoff-stop.sh`
Expected: 두 파일 모두 `handoff 스킬`과 `~/.claude/idle-handoffs/` 경로를 참조한다. 계약 본문(문서에 넣을 항목 목록)이 훅에 들어있지 않아야 한다.

- [ ] **Step 9: 커밋**

```bash
git add woobin-harness/hooks/ctx-handoff-stop.sh woobin-harness/hooks/hooks.json woobin-harness/hooks/idle-handoff-stop.sh
git commit -m "feat(hooks): 300k 초과 턴 종료 시 handoff 스킬로 자동 핸드오프"
```
