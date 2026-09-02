### Task 4: Re-sync the four R15 documents

Four documents describe R15 and they silently diverge when only one is edited — the failure recorded in `CLAUDE.md` ("스킬에서 문구를 지웠는데 훅에 하드코딩된 사본이 남아, 없어진 스킬을 5회 더 권했다"). Tasks 1–3 changed the procedure and the hook; this task updates the three documents that describe them.

**Files:**
- Modify: `docs/workflow-spec.md:442-527` (§3 R15)
- Modify: `docs/workflow.html:203-210` (the R15 step card)
- Modify: `home/HARNESS-LOG.md` (append entry `## 35.`)

**Interfaces:**
- Consumes: from Task 1 the phrases `왜 이걸 하나` / `어떻게 풀었나` and the two-invocation rule; from Task 2 the section name `Consumers outside the chat`; from Task 3 the hook bullet text.
- Produces: nothing later tasks consume. Task 5 only re-runs validators.

**Do not touch any `[0-9]+개` count** in these files. No skill, hook, or agent was created or deleted.

---

- [ ] **Step 1: Update the 기전 line in `docs/workflow-spec.md`**

Line 444 currently begins:

```
**기전** 절차 + **킥오프 훅 주입 + 구현자 정의**. 실행 절차의 단일 소유자는
```

Change that opening to:

```
**기전** 절차 + **킥오프 훅 주입 + 구현자 정의 + `explain` 호출**. 실행 절차의 단일 소유자는
```

Leave the rest of the sentence and the following two lines (445–446) unchanged.

- [ ] **Step 2: Add the narrative paragraph**

Insert this paragraph immediately **after** the paragraph that ends at line 461 (`**마지막 레이어를 push하면 \`gh pr ready\`로 draft를 벗기고**, 머지는 **squash**로 한다.`) and before the `**근거**` paragraph at line 463. Keep a blank line on each side.

```markdown
**2026-09-02(2) — PR이 무슨 작업인지 못 말하고 있었다.** 제목 템플릿이 플랜 slug 그대로였고
(`--title "<plan-name>"`), 본문은 플랜 디렉터리 포인터 + 레이어 체크리스트였다. 둘 다 "이 PR이
무엇을 바꾸는가"는 말하지만 **"사용자가 무슨 문제로 아팠는가"는 아무도 말하지 않았다** — 그 문장을
소유한 문서가 레포에 없다. `00-overview.md`의 `Goal:`은 이미 엔지니어링 언어로 번역된 뒤다.
그래서 제목·본문을 서사로 바꾸고(`<문제> — <해결 요지>`), 문장 규칙은 새로 쓰지 않고 `explain`
스킬을 **실제로 호출해서** 쓰기로 했다(그 스킬의 `## Consumers outside the chat` 절이 이 소비처를
명시한다). 호출은 두 번이다 — draft PR을 열 때 "왜 이걸 하나"를, 마지막 레이어를 push한 뒤
`gh pr edit`로 "어떻게 풀었나"를 채운다. **create 시점에는 후자가 존재할 수 없다**(코드가 아직
없다). 훅은 새로 만들지 않고 `sdd-kickoff-guard.sh`의 기존 R15 블록에 포인터 두 줄을 얹었다.
**"PR 본문은 포인터만"은 그대로다** — 이 레포에서 머지된 플랜 디렉터리는 실제로 남아 있어
포인터가 살아 있고, 서사는 그 규칙의 예외가 아니라 플랜이 애초에 소유하지 않는 항목이다.
```

- [ ] **Step 3: Add three 대가 items**

Append these to the `**대가**` list, after the existing final bullet (`- **플랜이 아닌 draft PR과 섞인다.** …` ending at line 511):

```markdown
- **플랜당 `explain` 호출이 2회 는다.** create와 ready 각 1회. 서사를 안 쓰던 때보다 확실히 비싸다 —
  교환 대상은 "머지 후 남는 유일한 기록이 읽히는가"다.
- **제목이 conventional commit 규격을 벗어난다.** PR 제목은 squash 머지 커밋 제목이 되므로
  `main` 이력이 산문이 된다. 사람이 읽기엔 이 편이 낫지만, 자동 changelog·semantic-release를
  도입하면 이 선택이 그걸 막는다.
- **1차 사료가 gitignore돼 있다.** `.claude/kickoff.local.md`는 워크트리 로컬이라 다른 워크트리나
  다른 머신에서 PR을 손보면 이미 없다. 폴백 사료(원장 → overview → 커밋 로그)가 있지만
  사용자의 **원래 표현**은 거기서 복원되지 않는다.
```

- [ ] **Step 4: Add four 무효화 조건**

Append to the `**무효화 조건**` list, after the existing final bullet (the one ending `**먼저 훅을 만들지 않는다** — R13도 경고 → 실패 관측 → 훅 순서였다`):

```markdown
- **자동 changelog·semantic-release를 도입** → 제목 형식을 `<type>: <문제 서술>`로 되돌린다.
  기각 사유(접두어가 서사 앞자리를 먹는다)보다 규격 준수의 값이 커지는 지점이다
- **PR 목록에서 어느 플랜인지 못 찾겠다는 게 관측됨** → 본문 포인터로 부족한 것이므로
  제목을 `[<slug>] <문제 서술>`로 옮긴다. `main` 이력이 다시 slug가 되는 걸 감수한다
- **create와 ready의 `explain` 출력이 사실상 같은 문장** → create 호출을 뺀다. 두 시점으로 나눈
  전제("create 시점에는 해결이 존재하지 않는다")가 실무에서 성립하지 않은 것이다
- **서사가 `00-overview.md`의 `Goal:`과 같은 문장이 되기 시작** → 서사가 중복이 된 것이므로
  포인터로 되돌린다. 이 규칙의 존재 이유는 그 문장을 소유한 문서가 없다는 것이었다
```

- [ ] **Step 5: Update the R15 card in `docs/workflow.html`**

The card spans lines 203–210. Modify the `<h3>` and add one `<p class="why">`:

Change line 205 from:

```html
      <h3>구현 시작 = 브랜치 + draft PR <span class="tag">R15</span></h3>
```

to:

```html
      <h3>구현 시작 = 브랜치 + draft PR, 끝 = 서사 <span class="tag">R15</span></h3>
```

Then insert this as a new paragraph immediately **after** the existing `<p class="why">이 규칙은 <b>2026-09-02까지 죽어 있었다</b>…</p>` at line 208, before the closing `</div>`:

```html
      <p class="why">PR 제목·본문은 <b>변경 파일 목록이 아니라 서사</b>다 — "사용자가 겪던 문제 → 어떻게 풀었나". 문장은 <code>explain</code> 스킬을 <b>실제로 호출해서</b> 쓴다. 호출은 두 번: draft를 열 때 <b>문제</b>를, 마지막 레이어를 push한 뒤 <code>gh pr edit</code>으로 <b>해결</b>을 채운다(create 시점엔 코드가 없어 후자가 존재하지 않는다). 제목은 <b>squash 머지 커밋 제목</b>이 되므로 slug가 아니라 산문이다.</p>
```

Verify the card still has balanced tags:

Run: `sed -n '203,212p' docs/workflow.html`
Expected: `<li class="step">` → `<div class="step-card">` → one `<h3>` → four `<p>` → `</div>` → `</li>`.

- [ ] **Step 6: Append `home/HARNESS-LOG.md` entry 35**

The last entry is `## 34. 규칙은 있었고, 그 규칙을 부정하는 문장이 에이전트 정의에 있었다 (2026-09-02)` at line 969, and the file ends with a `## 규율 (이 이력에서 반복 확인된 것)` section. Insert entry 35 **before** that `## 규율` section, not at the end of the file.

```markdown
## 35. PR은 무엇을 바꿨는지만 말하고 무엇이 아팠는지는 말하지 않았다 (2026-09-02)

**문제** — #35를 머지한 직후 사용자가 물었다: PR 제목과 본문만 봐서는 이 PR에서 무슨 작업을
했는지 파악이 안 된다. 확인해 보니 규칙이 그렇게 시켰다. R15의 템플릿은 제목이 `<plan-name>`
슬러그 그대로였고 본문은 플랜 디렉터리 포인터 + `- [ ] L1 …` 체크리스트였다. `main`의 이력이
그 결과다 — `2026-08-28-debugging-skill-replace (#34)`, `2026-08-27-full-auto-plan-execution (#33)`.

**진단** — "설명이 부족하다"가 아니라 **그 문장을 소유한 문서가 없다**였다. 플랜
`00-overview.md`의 `Goal:`은 이미 엔지니어링 언어로 번역된 뒤고("Delete the 274-line skill
and replace with…"), 사용자가 원래 무엇 때문에 아팠는지는 `interview` 대화와
`.claude/kickoff.local.md`에만 있는데 전자는 세션과 함께 사라지고 후자는 gitignore돼 있다.
포인터 규칙이 막고 있던 게 아니었다 — 이 레포에서 머지된 플랜 디렉터리는 실제로 안 지워지므로
포인터는 살아 있고, 서사는 그것과 경쟁하지 않는 **빈자리**였다.

**수단** — 제목을 `<문제> — <해결 요지>`로, 본문을 "왜 이걸 하나 / 어떻게 풀었나" 두 절로 바꿨다.
문장 규칙은 새로 쓰지 않고 `explain`을 **실제로 호출**한다. 그 스킬에 `## Consumers outside the
chat` 절을 넣어 PR이 소비처임을 명시했다 — 규칙을 `plan-exec-modes.md`에 인라인하는 대안은
기각했다. 스킬에서 지운 문구가 훅에 남아 5회 더 권해진 사고(#28 계열)가 이 레포의 반복 실패다.

**설계에서 갈린 지점** — 서사를 **언제** 쓰느냐. draft PR은 구현 첫 턴에 열리므로 그 시점엔
"어떻게 풀었나"가 물리적으로 존재하지 않는다. ready에서만 쓰면 구현 기간 내내 PR 목록에 slug만
떠서 리뷰어가 draft를 열 이유가 없고, create에서만 쓰면 해결이 영원히 안 들어간다. 그래서 둘 다
쓴다 — create에 문제, `gh pr edit`으로 해결. 강제는 새 훅이 아니라 `sdd-kickoff-guard.sh`의
기존 R15 블록에 포인터 두 줄을 얹는 것으로 했다. 같은 조건에 훅이 둘이면 소유자가 둘이 된다(§6-6).

**감수한 것** — 제목이 conventional commit 규격을 벗어난다. `main` 이력이 산문이 되는 대신
자동 changelog를 도입하면 이 선택이 막는다. 그 지점을 R15 무효화 조건에 적어뒀다.

**재측정** — 다음 플랜 5개에서 (a) 머지된 PR 제목만 읽고 무슨 문제를 풀었는지 판정 가능한 건수,
(b) `gh pr edit` 없이 create 시점 본문 그대로 ready된 건수. (b)가 0이 아니면 포인터로는 부족한
것이고, R15 무효화 조건대로 다음 수단은 Stop 훅 차단이다.
```

- [ ] **Step 7: Verify**

Run: `grep -n '^## 35\.' home/HARNESS-LOG.md`
Expected: one hit, at a line number **smaller** than the `## 규율` heading:

Run: `grep -n '^## 규율' home/HARNESS-LOG.md`
Expected: one hit, after entry 35.

`docs/workflow-spec.md` already contains six unrelated `explain` mentions at baseline, so a bare `grep -c explain` proves nothing. Check each of the four edits by a phrase that exists only in the new text:

```bash
grep -q '구현자 정의 + `explain` 호출' docs/workflow-spec.md   # Step 1
grep -q '그 문장을 소유한 문서가 레포에 없다' docs/workflow-spec.md   # Step 2
grep -q '플랜당 `explain` 호출이 2회 는다' docs/workflow-spec.md   # Step 3
grep -q '자동 changelog·semantic-release를 도입' docs/workflow-spec.md   # Step 4
grep -q 'PR 제목·본문은 <b>변경 파일 목록이 아니라 서사</b>' docs/workflow.html   # Step 5
```

Expected: all five exit `0`. Run them as one chained command so a single miss fails loudly. The single quotes protect the backticks from the shell — keep them:

```bash
grep -q '구현자 정의 + `explain` 호출' docs/workflow-spec.md \
  && grep -q '그 문장을 소유한 문서가 레포에 없다' docs/workflow-spec.md \
  && grep -q '플랜당 `explain` 호출이 2회 는다' docs/workflow-spec.md \
  && grep -q '자동 changelog·semantic-release를 도입' docs/workflow-spec.md \
  && grep -q 'PR 제목·본문은 <b>변경 파일 목록이 아니라 서사</b>' docs/workflow.html \
  && echo OK
```

Expected: `OK`

This matters because `./scripts/check-harness-docs.sh` only verifies that these files **appear in the changed-file list** when a hook changed — it never inspects what changed. Without the greps above, a truncated or misplaced insertion passes every other gate in this task.

Run: `./scripts/check-harness-docs.sh`
Expected: PASS. This is the gate that Task 3 deliberately deferred.

- [ ] **Step 8: Commit**

```bash
git add docs/workflow-spec.md docs/workflow.html home/HARNESS-LOG.md
git commit -m "docs(L3): R15 서사 규칙을 spec·workflow.html·HARNESS-LOG에 동기화"
```
