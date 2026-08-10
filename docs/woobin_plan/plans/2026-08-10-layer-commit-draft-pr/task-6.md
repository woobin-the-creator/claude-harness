### Task 6: 검사기·validate 통과 + 설치본 반영

**Files:**
- 읽기 전용 검증. 검사기가 ✗를 내면 해당 파일을 고친다(대상은 task-1~5가 이미 건드린 파일들뿐이다).

**Interfaces:**
- Consumes: task-1~5의 모든 변경.
- Produces: 없음. 이 태스크가 플랜의 마지막이다.

- [ ] **Step 1: 문서 동기화 검사기**

```bash
./scripts/check-harness-docs.sh; echo "exit=$?"
```
기대: `exit=0`. `[개수]`·`[인벤토리]`·`[동반 수정]` 세 섹션에 **✗가 없어야** 한다.

✗가 나오면 이렇게 읽는다:
- `... 훅 N개로 적혀 있는데 실제는 M개` → 개수를 건드렸다. task-5 Step 1의 경고를 어겼다는 뜻이니 `plugin.json`·`marketplace.json`·`README.md`·`workflow-spec.md`의 개수 문구를 **원래대로** 되돌린다(훅 11 · 에이전트 4 · 스킬 25).
- `docs/workflow-spec.md §4 에 \`...\` 행이 없다` → 훅 파일을 추가·개명했다. 이 플랜은 추가하지 않으므로 개명 실수다.
- `plugin.json 의 version 을 안 올렸다` → task-5 Step 1 미완.
- `docs/workflow.html 이 안 바뀌었다` → task-5 Step 2·3 미완.

⚠는 판단 항목이다. 이 플랜에서 정상적으로 뜰 수 있는 ⚠: 없음(`workflow.html`·`HARNESS-LOG.md` 둘 다 고쳤으므로). ⚠가 뜨면 해당 파일이 실제로 저장됐는지 확인하라.

- [ ] **Step 2: 플러그인 validate**

```bash
claude plugin validate ./woobin-harness; echo "exit=$?"
```
기대: `exit=0`. 이 명령만 YAML frontmatter 파싱 실패를 잡는다. 이번 변경은 frontmatter를 건드리지 않았지만, `plugin.json`을 편집했으므로 JSON 구조 확인을 겸한다.

- [ ] **Step 3: 훅이 여전히 유효한 JSON을 내는지**

```bash
for s in woobin-harness/hooks/*.sh; do sh -n "$s" || echo "문법 실패: $s"; done; echo "문법 검사 끝"
printf '{"session_id":"final-check"}' | sh woobin-harness/hooks/stale-branch-guard.sh \
  | { read -r out; [ -z "$out" ] && echo "출력 없음(뒤처지지 않음) — 정상" || printf '%s' "$out" | jq -e . >/dev/null && echo "유효한 JSON"; }
rm -f "$HOME/.claude/hooks/.stale-branch-pending/final-check"
```
기대: 문법 실패 0건, 그리고 "출력 없음" 또는 "유효한 JSON". 마커를 지우는 마지막 줄을 빼먹지 마라.

- [ ] **Step 4: Layer 3 마감 — 커밋까지만 한다**

```bash
git add docs/workflow.html home/HARNESS-LOG.md woobin-harness/.claude-plugin/plugin.json
git commit -m "docs(L3): 사람용 요약·이력 동기화 + plugin 1.4.0"
```

위임받아 실행 중이면(②b) 커밋 SHA와 Step 1·2 결과를 보고하고 끝낸다. 메인 루프면(②a) `plan-reviewer` 1회(`task-5.md`·`task-6.md` 경로 + `main..HEAD`) 후 `git push` + PR 코멘트.

- [ ] **Step 5: 사용자 확인 게이트 — 여기서 멈추고 보고한다**

**서브에이전트는 여기서 멈춘다.** 아래는 사용자가 판단·실행할 몫이다.

보고에 담을 것:
1. `check-harness-docs.sh` 결과(✗·⚠ 개수)와 `plugin validate` 결과
2. PR URL
3. 아래 두 항목을 사용자에게 그대로 제시

**(a) 설치본 반영** — 레포를 고쳐도 설치본은 버전별로 굳은 사본이라 옛날 그대로 돈다:
```
claude plugin marketplace update woobin-harness
claude plugin update woobin-harness@woobin-harness
```
그리고 Claude Code 재시작. **짧은 이름(`woobin-harness`)은 "not found"로 실패한다.**

**(b) 머지 — squash 규칙 + 플랜 삭제 권장**
```bash
git rm -r docs/woobin_plan/plans/2026-08-10-layer-commit-draft-pr/
git commit -m "chore: 플랜 문서 제거 — 구현 완료"
git push
gh pr ready && gh pr merge --squash
```
플랜 삭제는 **권장**이다(§3 R15). squash는 **규칙**이다.

- [ ] **Step 6: 미해결로 남기는 것을 명시한다**

보고 마지막에 한 줄로 적는다: **O14(하드 컷 빈도 vs 방향 오류 빈도)는 여전히 미계측이고, R15의 핵심 교환이 거기 매달려 있다.** 다음 `token-waste-audit`에서 세야 한다. 이 플랜에서 세지 않은 것은 의도다 — 규칙을 먼저 두고 다음 audit에서 재측정하는 것이 §6-3이다.
