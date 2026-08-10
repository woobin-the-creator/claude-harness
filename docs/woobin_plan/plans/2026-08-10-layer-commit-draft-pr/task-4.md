### Task 4: `stale-branch-guard.sh` 등급 하향 (면제 아님)

**Files:**
- Modify: `woobin-harness/hooks/stale-branch-guard.sh` — 헤더 주석에 1문단 추가 + 43행 `ctx=` 대입을 분기로 교체

**Interfaces:**
- Consumes: task-1의 `plan-wip` 라벨 이름. 문자열이 정확히 일치해야 한다.
- Produces: 없음. 이 훅의 출력 계약(`hookSpecificOutput.additionalContext` + 마커 파일)은 **바뀌지 않는다** — `stop-warning-ack-guard.sh`가 마커의 ctx 원문을 응답과 대조하므로, 마커에 쓰는 값과 주입하는 값이 계속 같아야 한다.

**왜 이걸 고치나:** `hooks.json`의 SessionStart에는 matcher가 없어 `/clear`에도 발화한다. 모드 ②a는 레이어마다 `/clear`하므로, 플랜 브랜치가 origin/main보다 한 커밋이라도 뒤처지면 **레이어 경계마다** 경고가 뜨고 `stop-warning-ack-guard.sh`가 응답 첫 문장에 경고 원문을 강제한다. 오탐이 누적되면 규칙이 죽는다(§6-1).

**면제하지 않는 이유:** 조건을 "열린 `plan-wip` PR이 있다"로만 두면 정말 방치된 브랜치도 빠져나간다. 그래서 **앞선 커밋이 있음**(= 실제 작업 중)을 함께 요구하고, 경고·마커·ack 게이트는 전부 유지한 채 **문구만** 바꾼다.

- [ ] **Step 1: 현재 동작 기준선 기록**

```bash
sh -n woobin-harness/hooks/stale-branch-guard.sh && echo "문법 OK"
printf '{"session_id":"smoke-before"}' | sh woobin-harness/hooks/stale-branch-guard.sh; echo "exit=$?"
```
기대: 문법 OK. 두 번째는 현재 브랜치 상태에 따라 빈 출력(뒤처지지 않음) 또는 `{"hookSpecificOutput":...}` JSON. 어느 쪽이 나왔는지 적어둔다 — Step 4에서 비교한다.

- [ ] **Step 2: 헤더 주석에 1문단 추가**

파일 헤더의 마지막 주석 줄(`# 파일 자체는 이 스크립트의 부수효과라 항상 남는다.`) 다음에 붙인다:

```sh
#
# R15(레이어 경계 커밋 + draft PR) 이후: 의도적으로 오래 사는 플랜 브랜치는 등급을 **하향**한다.
# 면제가 아니다 — 경고·마커·ack 게이트를 그대로 유지하고 문구만 "워크트리를 만들어라"에서
# "rebase가 필요한지만 확인해라"로 바꾼다. 조건을 "열린 plan-wip PR이 있다"로만 두면 방치된
# 브랜치도 빠져나가므로, "앞선 커밋이 있다"(= 실제 작업 중)를 함께 요구한다.
# 절차 원문은 woobin-harness/plan-exec-modes.md 가 소유한다 — 여기 복제하지 말 것(§6-6, 사고 #16).
```

- [ ] **Step 3: `ctx=` 대입을 분기로 교체**

찾을 블록 — `behind` 계산 다음의 `ctx="⚠️ 세션 시작 stale-branch 점검: 현재 '${branch}' 브랜치가 ...`로 시작해서 `...경고만 전하고 그대로 진행하세요."`로 끝나는 **하나의 대입문 전체**를 아래로 교체한다. 그 아래 `if [ -n "$session_id" ]; then` 블록은 **손대지 않는다**.

```sh
# R15 — 플랜 브랜치 판정. behind>0 경로에서만 계산하므로 평상시 비용은 0이다.
ahead=$(git rev-list --count "origin/${default}..HEAD" 2>/dev/null)
case "$ahead" in ''|*[!0-9]*) ahead=0 ;; esac

plan_wip=0
if [ "$ahead" -gt 0 ] && command -v gh >/dev/null 2>&1; then
  # 현재 브랜치의 열린 plan-wip PR만 본다. 미인증·원격 없음·오프라인이면 빈 문자열 -> 0으로 남는다.
  if [ -n "$(gh pr list --head "$branch" --state open --label plan-wip \
               --json number --jq '.[].number' 2>/dev/null)" ]; then
    plan_wip=1
  fi
fi

if [ "$plan_wip" -eq 1 ]; then
  ctx="⚠️ 세션 시작 stale-branch 점검: 현재 '${branch}'는 열린 plan-wip PR이 있는 **플랜 브랜치**이고, origin/${default}보다 ${behind} 커밋 뒤처져 있습니다(앞선 커밋 ${ahead}개).

이 경고는 사용자의 첫 메시지 내용과 무관하게 예외 없이 최우선입니다. 사용자가 완전히 다른 질문이나 작업을 요청했더라도, 조사나 답변을 먼저 진행하지 말고 이번 턴 응답의 맨 첫 문장으로 위 경고 문구를 사용자에게 그대로 전달한 뒤에 사용자의 실제 요청을 처리하세요.

알린 다음: **새 워크트리를 만들지 마세요** — 이 브랜치는 구현이 진행 중인 플랜 브랜치입니다. 뒤처진 ${behind} 커밋이 이번 레이어가 건드리는 파일과 겹치는지만 확인하고, 겹치면 rebase 여부를 사용자에게 물어보세요. 겹치지 않으면 그대로 진행하세요."
else
  ctx="⚠️ 세션 시작 stale-branch 점검: 현재 '${branch}' 브랜치가 origin/${default}보다 ${behind} 커밋 뒤처져 있고, 격리된 워크트리가 아닙니다.

이 경고는 사용자의 첫 메시지 내용과 무관하게 예외 없이 최우선입니다. 사용자가 완전히 다른 질문이나 작업을 요청했더라도, 조사나 답변을 먼저 진행하지 말고 이번 턴 응답의 맨 첫 문장으로 위 경고 문구를 사용자에게 그대로 전달한 뒤에 사용자의 실제 요청을 처리하세요. 경고를 생략하거나 뒤로 미루면 안 됩니다.

알린 다음: 새 작업을 시작하는 맥락이면 EnterWorktree로 최신 ${default} 기반(baseRef=fresh) 워크트리를 만들지 사용자에게 물어보세요 — 자동으로 만들지 말고 확인을 받으세요. 사용자가 방금 만든 브랜치를 이어서 하려는 등 의도적으로 현재 브랜치에 머무는 경우라면 경고만 전하고 그대로 진행하세요."
fi
```

`else` 쪽 문구는 **기존 문장 그대로**다. 한 글자도 바꾸지 마라 — `stop-warning-ack-guard.sh`가 마커의 원문과 응답을 대조한다.

- [ ] **Step 4: 스모크 테스트 — 두 경로**

```bash
sh -n woobin-harness/hooks/stale-branch-guard.sh && echo "문법 OK"

# (a) plan-wip 경로: 현재 브랜치에 라벨이 붙은 열린 PR이 있어야 한다.
#     Layer 0에서 이미 만들었으므로, main보다 뒤처져 있으면 하향 문구가 나온다.
printf '{"session_id":"smoke-planwip"}' | sh woobin-harness/hooks/stale-branch-guard.sh \
  | jq -r '.hookSpecificOutput.additionalContext' | head -1

# (b) 기존 경로: gh를 못 찾는 상황을 흉내내 fallback이 도는지 본다.
printf '{"session_id":"smoke-plain"}' | env PATH=/usr/bin:/bin sh woobin-harness/hooks/stale-branch-guard.sh \
  | jq -r '.hookSpecificOutput.additionalContext' | head -1
```
기대:
- (a) → `... 열린 plan-wip PR이 있는 **플랜 브랜치**이고 ...` (뒤처진 커밋이 0이면 빈 출력이다 — 그 경우 이 확인은 건너뛰고 Step 5의 강제 경로로 검증한다)
- (b) → `... 격리된 워크트리가 아닙니다.` (기존 문구)

- [ ] **Step 5: 뒤처진 커밋이 0이라 (a)를 못 봤을 때의 강제 검증**

`behind`가 0이면 훅이 조기 종료하므로 문구를 볼 수 없다. 임시 사본으로 분기만 확인한다:

```bash
tmp=$(mktemp) && sed 's#^\[ "\$behind" -gt 0 \] || exit 0#behind=1#' \
  woobin-harness/hooks/stale-branch-guard.sh > "$tmp"
printf '{"session_id":"smoke-forced"}' | sh "$tmp" | jq -r '.hookSpecificOutput.additionalContext' | head -1
rm -f "$tmp"
```
기대: plan-wip PR이 열려 있으면 하향 문구가 나온다. 원본 파일은 건드리지 않았다.

- [ ] **Step 6: 마커 파일 청소**

스모크 테스트가 `~/.claude/hooks/.stale-branch-pending/`에 마커를 남겼다. 지우지 않으면 이 세션의 Stop 훅이 존재하지 않는 경고를 응답에서 찾다가 반려한다.

```bash
rm -f "$HOME/.claude/hooks/.stale-branch-pending/smoke-"*
ls "$HOME/.claude/hooks/.stale-branch-pending/" 2>/dev/null
```
기대: `smoke-`로 시작하는 파일이 없다.

- [ ] **Step 7: Layer 2 마감 — 커밋까지만 한다**

```bash
git add woobin-harness/plan-exec-modes.md woobin-harness/hooks/stale-branch-guard.sh
git commit -m "feat(L2): R15 절차를 모드 파일에 신설 + stale-branch 경고 등급 하향"
```

**여기서 멈춘다.** 위임받아 실행 중이면(②b) 커밋 SHA와 발견을 보고하고 끝낸다 — 리뷰·push는 오케스트레이터 몫이다(`plan-implementer`에는 `Agent` 툴이 없다). 메인 루프면(②a) `plan-reviewer` 1회(`task-3.md`·`task-4.md` 경로 + `main..HEAD`) 후 `git push` + PR 코멘트.

⚠️ 이 커밋으로 `woobin-harness/hooks/`가 바뀌었으므로 `harness-doc-sync-guard.sh`가 additionalContext를 주입한다. **task-5가 그 요구를 처리한다** — 지금 대응하지 말고 L3로 넘어가라.
