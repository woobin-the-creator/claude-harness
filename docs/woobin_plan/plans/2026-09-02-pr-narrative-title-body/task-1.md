### Task 1: Rewrite the R15 create/ready procedure

This is the single owner of the R15 execution procedure. Everything else in this plan points at the wording produced here.

**Files:**
- Modify: `woobin-harness/plan-exec-modes.md:51-98`
- Modify: `woobin-harness/plan-exec-modes-codex.md:30-35`

**Interfaces:**
- Produces: the two literal Korean phrases `어떻게 풀었나` and `왜 이걸 하나`, which Task 3's fixture and Task 4's spec text both reference. Do not rename them.
- Produces: the decision that `explain` is invoked at **two** points (before `gh pr create`, and before `gh pr edit` + `gh pr ready`). Task 2 documents that consumer, Task 3 injects a pointer to it.

---

- [ ] **Step 1: Read the current subsection**

Run: `sed -n '45,110p' woobin-harness/plan-exec-modes.md`

Expected, in this order:

| Lines | What is there |
|---|---|
| 45 | the `### 중단 대비 — 레이어 경계 커밋 + 리뷰 후 push (R15)` heading |
| 51–64 | `**구현 첫 턴에 이것부터 한다**` and the `gh pr create` fenced block |
| 66–76 | five bullets, the third of which is `- **PR 본문은 포인터만.**` and the fourth `- **예외 하나 — 자동 확정된 결정.**` |
| 78–85 | `**레이어가 끝날 때 …**` and its four numbered items |
| 87–91 | `**마지막 레이어를 push한 직후 — ready로 전환한다**` and the `gh pr ready` fenced block |
| 93–98 | two prose bullets (`- draft는 …`, `- 머지까지 미루면 안 되는 이유:…`) — **not** part of the fenced block; Step 5 edits these separately |
| 100– | `**머지**` and the `gh pr merge --squash` block |

- [ ] **Step 2: Replace the create block**

Replace lines 51–64 (from `**구현 첫 턴에 이것부터 한다**` through the closing ` ``` ` of the `gh pr create` block) with exactly this:

````markdown
**구현 첫 턴에 이것부터 한다**

```bash
git switch -c plan/<plan-name>
git add docs/woobin_plan/plans/<plan-name>/
git commit -m "docs(plan): <plan-name> 구현 시작"
git push -u origin plan/<plan-name>
gh pr create --draft --title "<사용자가 겪던 문제>" --body "$(cat <<'EOF'
## 왜 이걸 하나

<사용자가 겪던 문제. 이 스레드를 못 본 사람이 읽는다>

## 어떻게 풀었나

*(마지막 레이어를 push한 뒤 `gh pr ready` 직전에 채운다)*

---

플랜: `docs/woobin_plan/plans/<plan-name>/`
진행 상태: `git log --oneline`

- [ ] L1 …
- [ ] L2 …
- [ ] 머지 전 플랜 디렉터리 삭제(권장)
EOF
)"
```
````

- [ ] **Step 3: Insert the narrative bullets**

The bullet list currently starting at what was line 66 (`- **라벨을 붙이지 마라.**`) keeps all five of its existing bullets **unchanged** — including the `interview` exception bullet. Insert these three bullets **immediately before** the existing `- **라벨을 붙이지 마라.**` bullet:

```markdown
- **제목과 본문은 서사다 — 변경 파일 목록이 아니다.** 최종 제목 형식은 `<문제> — <해결 요지>`이고,
  create 시점에는 `<해결 요지>`가 아직 존재하지 않으므로 `<문제>`만 쓴다. ready에서 완성한다.
  **이 제목은 squash 머지 커밋 제목이 된다** — `main`의 `git log --oneline`에 이 문장이 남는다.
  그래서 slug가 아니라 산문이다.
- **서사는 `explain`을 실제로 호출해서 쓴다.** Claude Code에서는 `Skill` 툴로 `explain`을 부른다.
  어느 층에서 시작할지, 무엇을 검증된 사실로 분리할지 같은 문장 규칙의 소유자는 그 스킬이고
  여기에 복제하지 않는다(§6-6). 독자는 이 세션을 못 본 사람이므로 기본은 *situated* 층이다.
- **서사의 사료는 이 순서로 찾는다.** `.claude/kickoff.local.md`(사용자가 처음 준 원문) →
  `interview`의 결정 원장 → `00-overview.md` → 레이어 커밋 로그. 앞이 없으면 다음으로 내려간다.
  `kickoff.local.md`는 `.gitignore`에 있어 **이 워크트리 안에서만** 읽힌다 — 다른 워크트리에서
  열면 이미 없으므로 그때는 다음 사료로 간다.
```

- [ ] **Step 4: Replace the ready block**

Replace what is currently lines 87–91 (`**마지막 레이어를 push한 직후 — ready로 전환한다**` plus its `gh pr ready` fenced block) with:

````markdown
**마지막 레이어를 push한 직후 — 서사를 완성하고 ready로 전환한다**

```bash
gh pr edit --title "<문제> — <해결 요지>" --body "$(cat <<'EOF'
## 왜 이걸 하나

<create 시점에 쓴 것. 구현하며 문제 이해가 바뀌었으면 여기서 고친다>

## 어떻게 풀었나

<무엇을 어떻게 고쳤길래 위 문제가 사라지는지. 파일 나열이 아니라 인과로>

---

플랜: `docs/woobin_plan/plans/<plan-name>/`
진행 상태: `git log --oneline`
EOF
)"
gh pr ready
```
````

- [ ] **Step 5: Add the two ready-time bullets**

The two existing bullets after that block (`- draft는 **"구현 중"** 표시지…` and `- 머지까지 미루면 안 되는 이유:…`) stay unchanged. Insert these two **before** them:

```markdown
- **ready 직전에 제목·본문을 다시 쓴다.** create 시점에는 "어떻게 풀었나"가 존재하지 않았다 —
  코드가 아직 없었기 때문이다. 여기서 `explain`을 **한 번 더** 호출한다. 사료는
  `git log --oneline main..HEAD`(레이어 커밋)와 레이어마다 남긴 PR 코멘트다.
- **체크리스트는 지운다.** 완료된 `- [ ] L1 …` 목록은 `git log`가 이미 나르는 파생 상태다.
  `머지 전 플랜 디렉터리 삭제(권장)`만 남길 이유가 있으면 남기고, 나머지는 남기지 않는다.
```

- [ ] **Step 6: Point the Codex file at it**

In `woobin-harness/plan-exec-modes-codex.md`, the R15 bullet spans lines 30–35 and ends with `push는 어느 쪽에도 넣지 않는다 — 리뷰를 돌린 부모가 한다.`. Append this as a new sibling bullet immediately after it:

```markdown
- **PR 제목·본문 서사도 Codex에 그대로 적용된다.** 절차와 형식은
  [plan-exec-modes.md](plan-exec-modes.md)의 "중단 대비" 소절이 소유한다. 문장 규칙은 `explain`이
  소유하는데, Codex에서 그 스킬을 호출하는 수단이 없으면 `skills/explain/SKILL.md`를 **읽고**
  그대로 적용한다 — 규칙을 이 파일에 옮겨 적지 않는다.
```

- [ ] **Step 7: Verify**

Run: `grep -c '어떻게 풀었나' woobin-harness/plan-exec-modes.md`
Expected: `2`

Run: `grep -c '왜 이걸 하나' woobin-harness/plan-exec-modes.md`
Expected: `2`

Run: `grep -n 'interview' woobin-harness/plan-exec-modes.md`
Expected: still prints the `- **예외 하나 — 자동 확정된 결정.**` bullet and its `형식은 \`interview\` §④.` line — proof Step 3 did not delete it.

Run: `grep -n 'plan-exec-modes.md' woobin-harness/plan-exec-modes-codex.md`
Expected: at least two hits, including the new bullet.

Run: `claude plugin validate ./woobin-harness`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add woobin-harness/plan-exec-modes.md woobin-harness/plan-exec-modes-codex.md
git commit -m "feat(L1): PR 제목·본문을 서사로 — R15 create/ready 절차 재작성"
```
