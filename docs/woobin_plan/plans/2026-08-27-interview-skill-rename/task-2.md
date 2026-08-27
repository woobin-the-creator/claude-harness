### Task 2: Add the PR-body exception to `plan-exec-modes.md`

**Files:**
- Modify: `woobin-harness/plan-exec-modes.md:47` (insert one bullet after it)

**Interfaces:**
- Consumes: the section anchor `§④` and the skill name `interview` produced by Task 1.
- Produces: nothing later tasks depend on, except that Task 4's `HARNESS-LOG.md` entry narrates this change.

**Why this exception exists.** `plan-exec-modes.md:47` currently reads `**PR 본문은 포인터만.** 플랜 내용을 옮겨 적으면 소유자가 둘이 되고 갈라진다(§6-6).` The pointer it mandates points at `docs/woobin_plan/plans/<plan-name>/` — and the same file's PR-creation checklist, seventeen lines above at line 40, contains `- [ ] 머지 전 플랜 디렉터리 삭제(권장)`. So for decisions the model made without asking, the pointer's target is deleted before merge and the owner count drops to zero. That is the hole this bullet closes, and it is why the exception is narrow: rows the user actually chose still have an owner (the conversation), so they stay out.

Do **not** make the same edit to `woobin-harness/plan-exec-modes-codex.md`. It has no PR or branch section at all — verified, zero matches for `PR` and `gh pr create` across its 78 lines. There is no counterpart passage to keep in sync.

---

- [ ] **Step 1: Confirm the anchor line is where the plan says it is**

```bash
cd /Users/mac_wb/.paseo/worktrees/11zirkjp/rabid-stingray
command grep -n "PR 본문은 포인터만" woobin-harness/plan-exec-modes.md
```

Expected: exactly one line, numbered `47`. If the number differs, use whatever line it reports — the anchor is the text, not the number.

- [ ] **Step 2: Insert the exception bullet**

Find this bullet in `woobin-harness/plan-exec-modes.md`:

```
- **PR 본문은 포인터만.** 플랜 내용을 옮겨 적으면 소유자가 둘이 되고 갈라진다(§6-6).
```

Leave it in place and insert this bullet **immediately after** it, as the next list item (no blank line between them — it is the same bullet list):

```
- **예외 하나 — 자동 확정된 결정.** `interview`가 사용자에게 묻지 않고 스스로 확정한 결정과 가정은
  PR 본문에 **직접** 적는다. 포인터 규칙의 취지는 살아 있는 문서의 이중 소유를 막는 것인데, 플랜
  디렉터리는 위 체크리스트대로 머지 전에 지워지므로 그 항목은 머지 후 소유자가 0이 된다. 사용자가
  고른 줄은 옮기지 마라 — 그건 대화에 기록이 있다. 형식은 `interview` §④.
```

Match the surrounding bullets' wrapping style: continuation lines are indented two spaces, as in the `**라벨을 붙이지 마라.**` bullet directly above.

- [ ] **Step 3: Verify the bullet landed inside the right list**

```bash
sed -n '44,54p' woobin-harness/plan-exec-modes.md
```

Expected: the new bullet appears between the `**PR 본문은 포인터만.**` bullet and the `**열린 draft 플랜 PR은 워크트리당 1개.**` bullet, with no blank line splitting the list.

- [ ] **Step 4: Verify the Codex file was left alone**

```bash
git diff --name-only | command grep -c "plan-exec-modes-codex.md"
```

Expected: `0`.

- [ ] **Step 5: Run the completion check**

```bash
command grep -c '자동 확정된 결정' woobin-harness/plan-exec-modes.md
```

Expected: `1`.

- [ ] **Step 6: Commit**

```bash
git add woobin-harness/plan-exec-modes.md
git commit -m "docs(plan-exec-modes): PR 본문 포인터 규칙에 자동 확정분 예외 추가"
```
