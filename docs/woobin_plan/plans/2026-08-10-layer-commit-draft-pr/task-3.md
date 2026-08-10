### Task 3: 실행 절차를 `plan-exec-modes.md`에 신설

**Files:**
- Modify: `woobin-harness/plan-exec-modes.md` — "## 모든 모드 공통" 절의 마지막 불릿 다음, `---` 앞에 소절을 추가

**Interfaces:**
- Consumes: task-1의 `R15`, `plan-wip`, `plan/` 접두어.
- Produces: 절차 텍스트. 이 파일이 **절차의 단일 소유자**다. 같은 절차를 `workflow-spec.md`나 훅 헤더에 복제하지 마라(§6-6).

**앵커:** `## 모든 모드 공통` 절은 `- 리뷰는 \`plan-reviewer\` 에이전트(...)로 띄운다.`로 시작하는 불릿으로 끝나고, 그 다음이 `---`다. 그 `---` **앞**에 아래 소절을 넣는다.

- [ ] **Step 1: 삽입 지점 확인**

```bash
grep -n "^---$" woobin-harness/plan-exec-modes.md | head -1
grep -n "^## ① 속도" woobin-harness/plan-exec-modes.md
```
첫 `---`가 공통 절의 끝이다. 그 앞에 삽입한다(`## ① 속도` 앞).

- [ ] **Step 2: 아래 소절을 그대로 삽입**

````markdown
### 중단 대비 — 레이어 경계 커밋 + 리뷰 후 push (R15)

관측된 실패는 컨텍스트 성장이 아니라 **사용량 하드 컷**이다. 그 순간 모델은 도구를 쓸 수 없으므로
방어는 미리 배치돼 있어야 한다. 근거·대가·무효화 조건은 `docs/workflow-spec.md` §3 R15가 소유한다 —
여기는 **절차만** 적는다. 원격이 없는 레포에서는 이 절 전체가 비적용이다.

**구현 첫 턴에 이것부터 한다**

```bash
git switch -c plan/<plan-name>
git add docs/woobin_plan/plans/<plan-name>/
git commit -m "docs(plan): <plan-name> 구현 시작"
git push -u origin plan/<plan-name>
gh pr create --draft --label plan-wip --title "<plan-name>" --body "플랜: \`docs/woobin_plan/plans/<plan-name>/\`
진행 상태: \`git log --oneline\`

- [ ] L1 …
- [ ] L2 …
- [ ] 머지 전 플랜 디렉터리 삭제(권장)"
```

- 라벨이 없으면 먼저 만든다: `gh label create plan-wip --description "구현 중인 플랜 브랜치" --color FBCA04`
- **PR 본문은 포인터만.** 플랜 내용을 옮겨 적으면 소유자가 둘이 되고 갈라진다(§6-6).
- **열린 `plan-wip` PR은 워크트리당 1개.** 이미 있으면 그것을 먼저 처리한다 —
  목록만 보고 어느 게 살아있는지 판정할 수 없어지면 진입점의 값이 사라진다.
- 플랜 문서를 **커밋한다.** untracked로 두면 새 워크트리에 따라오지 않는다.

**레이어가 끝날 때 — 순서를 지킨다: 커밋 → 리뷰 → (수정) → push**

1. `git add -A && git commit -m "<type>(L<n>): <레이어 요약>"` — **리뷰 전이다.**
   레이어 끝의 리뷰가 그 세션에서 토큰을 가장 많이 쓰는 단계라 하드 컷 확률이 가장 높다.
2. `plan-reviewer` 1회. `task-N.md` **경로**와 `main..HEAD` **범위**만 넘긴다(diff 본문 금지).
3. 지적을 반영하고 `git commit --amend` 또는 fixup 커밋.
4. `git push` + PR 코멘트 **5행 이내**: 이 레이어에서 발견한 것(플랜에 없던 환경 사실, 고친 완료 판정 등).
   **커밋 message body에 쓰지 마라** — squash가 날린다.

**머지**

```bash
gh pr ready && gh pr merge --squash
```

- `--squash`는 **규칙**이다. 레이어 커밋은 개별로 테스트를 통과하지 않을 수 있어, merge commit으로
  들어가면 main의 `git bisect`가 못 믿을 것이 된다.
- 머지 전 플랜 디렉터리 삭제(`git rm -r docs/woobin_plan/plans/<plan-name>/`)는 **권장**이다.
  squash면 추가·삭제가 상쇄돼 main 히스토리에 blob이 안 들어가고, 브랜치를 지워도 PR의 커밋
  목록에서 플랜 원문을 계속 볼 수 있다. 잊어도 피해는 main 트리의 디렉터리 하나다.

**모드별 차이**

- **②a** — 커밋은 `/clear` **직전**에 한다. git 출력이 한 턴만 살고 버려져서 이후 요청에 재청구되지 않는다.
- **②b** — **커밋은 레이어 `plan-implementer`가, push는 리뷰를 돌린 오케스트레이터가** 한다.
  이렇게 갈라두면 "리뷰 전에는 원격에 안 올라간다"가 절차가 아니라 **구조**로 보장된다.
  구현자 프롬프트에 "커밋하고 보고해라"까지만 넣는다 — push를 시키지 마라.
- **①** — 트랙마다 워크트리이므로 **트랙당 draft PR 1개**다. 워크트리당 1개 불변식이 여기서 자연히 성립한다.
````

- [ ] **Step 3: 검증**

```bash
grep -c "중단 대비 — 레이어 경계 커밋" woobin-harness/plan-exec-modes.md
grep -c "plan-wip" woobin-harness/plan-exec-modes.md
grep -n "^## ① 속도" woobin-harness/plan-exec-modes.md
```
기대: 첫째 → `1` / 둘째 → **3 이상** / 셋째 → 삽입한 소절보다 **큰** 줄 번호(공통 절 안에 들어갔다)

- [ ] **Step 4: 근거 링크 절이 망가지지 않았는지 확인**

```bash
tail -8 woobin-harness/plan-exec-modes.md
```
기대: `## 근거` 절의 링크 목록이 그대로 남아 있다. 소절을 파일 끝에 붙였다면 잘못 넣은 것이다 — 공통 절 안이어야 한다.

- [ ] **Step 5: 커밋하지 않는다**

task-4가 같은 레이어(L2)다. 커밋은 L2가 끝난 뒤 한 번이다.
