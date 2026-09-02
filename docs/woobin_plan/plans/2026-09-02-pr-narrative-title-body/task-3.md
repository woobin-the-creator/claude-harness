### Task 3: Add the narrative pointer to the kickoff hook

The enforcement half. R15's procedure was dead until `sdd-kickoff-guard.sh` started pointing at it; the narrative rule gets the same treatment, in the same hook, under the same condition. **Do not create a new hook file** — two hooks on one condition means two owners (`docs/workflow-spec.md` §6-6), and a new hook would force count updates in six documents.

**Files:**
- Modify: `woobin-harness/hooks/sdd-kickoff-guard.sh:126-131`
- Modify: `scripts/test-hooks.sh:144-161`

**Interfaces:**
- Consumes: from Task 1, the literal string `explain` and the two-invocation-point rule.
- Produces: nothing later tasks consume. Task 4 documents this edit but does not read it.

---

- [ ] **Step 1: Read the R15 block**

Run: `sed -n '108,137p' woobin-harness/hooks/sdd-kickoff-guard.sh`

Expected: an `if` gating on `git rev-parse --git-dir` **and** a non-empty `git remote`, a `case "$cur_branch"` with a `plan/*` arm and a `*` arm, then a shared footer assembled into `ctx` starting `[R15 — 중단 대비] ${r15}` with three `- **…**` bullets, closed by `fi` at line 132.

- [ ] **Step 2: Add two bullets to the shared footer**

The footer's last existing bullet is:

```
- 머지(\`gh pr merge --squash\`)는 사용자가 합니다. 자동으로 머지하지 마세요.\"
```

Note that the closing `"` of the shell double-quoted string sits at the end of that line. Insert two new bullets **before** it, so the string closes after the last new bullet. The result must read:

```sh
  ctx="${ctx}[R15 — 중단 대비] ${r15}

- **커밋은 레이어 구현자가, push는 리뷰를 돌린 오케스트레이터가** 합니다. 구현자에게 push를 시키지 마세요 —
  이 분리가 \"리뷰 전에는 원격에 안 올라간다\"를 절차가 아니라 구조로 만듭니다.
- **PR 제목·본문은 서사입니다** — 변경 파일 나열이 아니라 \"사용자가 겪던 문제 → 어떻게 풀었나\"입니다.
  \`explain\` 스킬을 **실제로 호출해서**(Claude Code: \`Skill\` 툴) 쓰세요. 제목은 squash 머지 커밋
  제목이 되므로 slug가 아니라 산문입니다.
- **마지막 레이어를 push한 직후 \`gh pr edit\`로 제목·본문을 다시 쓰고 \`gh pr ready\`** 로 draft를
  벗깁니다. create 시점에는 \"어떻게 풀었나\"가 존재하지 않았습니다 — 여기서 \`explain\`을 한 번 더
  호출해 채웁니다. 머지까지 미루지 마세요.
- 머지(\`gh pr merge --squash\`)는 사용자가 합니다. 자동으로 머지하지 마세요."
fi
```

**Two things to get exactly right.** First, the old bullet `- **마지막 레이어를 push한 직후 \`gh pr ready\`** 로 draft를 벗깁니다. 머지까지 미루지 마세요.` is **replaced** by the longer `gh pr edit` version above — do not leave both. Second, every backtick and every inner double quote inside this double-quoted shell string stays backslash-escaped, exactly as the surrounding lines already do.

- [ ] **Step 3: Verify the hook still emits valid JSON**

Run:

```bash
tmp=$(mktemp -d) && mkdir -p "$tmp/docs/woobin_plan/plans/p" \
  && printf '# Overview\n' >"$tmp/docs/woobin_plan/plans/p/00-overview.md" \
  && git -C "$tmp" init -q \
  && git -C "$tmp" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
  && git -C "$tmp" remote add origin https://example.invalid/x.git \
  && (cd "$tmp" && printf '%s' '{"session_id":"probe","prompt":"docs/woobin_plan/plans/p 구현 진행해줘"}' \
      | TMPDIR="$tmp" "$OLDPWD/woobin-harness/hooks/sdd-kickoff-guard.sh") | jq -r '.hookSpecificOutput.additionalContext'
```

Expected: the injected text prints, containing both `PR 제목·본문은 서사입니다` and `gh pr edit`. If `jq` errors, the shell string was closed in the wrong place in Step 2.

- [ ] **Step 4: Extend the existing fixture**

In `scripts/test-hooks.sh`, case (a) at line 148 currently asserts:

```sh
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("R15 — 중단 대비") and contains("draft PR") and contains("gh pr ready")' "sdd-kickoff-guard R15: missing first-turn procedure"
```

Replace that single line with:

```sh
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("R15 — 중단 대비") and contains("draft PR") and contains("gh pr ready")' "sdd-kickoff-guard R15: missing first-turn procedure"
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("PR 제목·본문은 서사입니다") and contains("explain") and contains("gh pr edit")' "sdd-kickoff-guard R15: missing PR narrative pointer"
```

Leave cases (b) at line 154 and (c) at line 160 untouched. Case (c) asserts the context does **not** contain `R15`; the new bullets live inside the same remote-gated `if`, so it must still hold.

- [ ] **Step 5: Run the fixtures**

Run: `./scripts/test-hooks.sh`
Expected: PASS, 13/13. If case (c) now fails, a new bullet was placed outside the `if [ -n "$(git remote …)" ]` block — move it inside.

- [ ] **Step 6: Commit**

```bash
git add woobin-harness/hooks/sdd-kickoff-guard.sh scripts/test-hooks.sh
git commit -m "feat(L2): 킥오프 가드에 PR 서사 포인터를 얹는다"
```

**Do not run `./scripts/check-harness-docs.sh` as this task's gate.** It fails by design when `woobin-harness/hooks/` changes without an accompanying doc change, and that doc change is Task 4.
