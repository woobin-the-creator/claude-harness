### Task 5: Hook backstop branch

`plan-saved-session-boundary.sh` is the only thing that fires when a plan is written without the `writing-plans` skill. It currently ends every path with "exit this session and relaunch". Teach the modes-file branch the same routing the skill just learned, and add the fixture that proves it — that branch has never been covered.

**Files:**
- Modify: `woobin-harness/hooks/plan-saved-session-boundary.sh` — the header comment block, and the `mode_step` assignment in the `else` arm of `if [ ! -f "$MODES_FILE" ]` (lines 122-141)
- Modify: `scripts/test-hooks.sh` — add one fixture after the existing `plan-saved-session-boundary presplit overview/task branches` block (line 96)

**Interfaces:**
- Consumes: the routing table and full-auto procedure from Task 2, by pointing at `$MODES_FILE` rather than restating them.
- Produces: nothing later tasks read.

**Do not touch the no-modes-file fallback.** When `$MODES_FILE` is absent the hook cannot know the routing rule, so telling the user to relaunch is still the right answer. `scripts/test-hooks.sh:90` asserts the substring `2026-08-21-sample 플랜으로 구현` from exactly that branch — changing it breaks a passing fixture for no gain.

Hook strings are injected into a Korean session and stay Korean.

---

- [ ] **Step 1: Extend the header comment**

Add a dated paragraph to the block comment at the top of the file, after the `2026-08-21` paragraph, so the reason survives:

```sh
# 2026-08-27 — 게이트가 0개인 플랜은 세션 경계를 넘지 않는다. 플랜 문서 리뷰어가 낸 게이트 수가
# 라우팅 입력이고, 0이면 이 세션이 그대로 구현까지 굴린다(모드 ①·②b·③). 1개 이상이면 종전대로
# ②a 킥오프 블록을 낸다 — 서브에이전트는 AskUserQuestion 이 제거돼 게이트에서 물을 수가 없어서,
# 무인으로 보내면 중단이 아니라 정지가 된다. 라우팅 표 자체는 $MODES_FILE 이 소유하고 여기서
# 복제하지 않는다(§9-1 이중 소유 회피).
```

- [ ] **Step 2: Rewrite `mode_step` in the modes-file-present branch**

The `else` arm currently assigns a `mode_step` that ends with an `/exit`-and-relaunch instruction and `그리고 이번 턴을 종료하세요. 사용자가 세션을 다시 띄울 차례입니다.` Replace that whole assignment with:

```sh
mode_step="${step_n}. **플랜 문서 리뷰어를 먼저 띄우세요.** 프롬프트 템플릿은
   \`\${CLAUDE_PLUGIN_ROOT}/skills/writing-plans/plan-document-reviewer-prompt.md\` 에 있습니다.
   general-purpose 서브에이전트로 띄우고, 지적을 플랜 문서에 반영한 뒤 다음으로 가세요.
   리뷰어가 내는 \`**Gates:** N\`(사람 확인이 필요한 지점의 수)이 아래 라우팅의 입력입니다.

$((step_n+1)). **모드를 추천하고 게이트 수로 라우팅하세요.** 정의는 \`${MODES_FILE}\` 에 있습니다 — 지금 읽으세요.
   모드 추천의 유일한 근거는 방금 쓴 overview의 **태스크 간 순서 의존성**입니다. 그 판단은 지금 이 세션만 할 수 있습니다.
   - 파일을 공유하지 않는 트랙이 2개 이상 → ① 속도
   - 의존성 체인이거나 같은 파일 공유 → ② 절약  ← 대부분 여기
   - 되돌리기 비싼 작업(마이그레이션·prod 배포·자동 게이트가 못 잡는 UI) → ③ 최고 퀄리티

   그리고 게이트 수로 갈립니다. 상세 표와 절차는 모드 파일이 소유합니다:
   - **게이트 0개** → ①·②b·③ 그대로 **이 세션에서 full-auto로 실행**합니다. 킥오프 블록을 내지 마세요.
   - **게이트 1개 이상** → **②a**. 아래 킥오프를 출력하고 턴을 종료하세요.
   - **게이트 1개 이상 + ③ 성립 조건** → ③를 유지한 채 이 세션에서 실행하고, 게이트에서 멈춰 사용자에게 올리세요.

   ②a로 갈 때만 출력할 킥오프:

   \"이 세션을 종료(\`/exit\`)하고 이렇게 다시 띄우세요:
   \`\`\`
   claude --effort medium --model sonnet
   \`\`\`
   그리고 첫 프롬프트:
   \`\`\`
   ${kickoff_target} 플랜으로 구현 진행해줘 — 모드 ②a(${MODES_FILE})
   \`\`\`\"

   \`--effort\`는 **그 세션에만** 적용됩니다(문서: \"set it for a single session\").
   \`/effort\`와 달리 settings.json을 건드리지 않으므로 끝나고 되돌릴 것이 없습니다 — 되돌리기 안내를 붙이지 마세요.

$((step_n+2)). full-auto로 갈 경우 **이 턴을 종료하지 말고** 모드 파일의 full-auto 절차대로 계속하세요:
   \`plan/<slug>\` 브랜치 · 플랜 커밋 · draft PR → 레이어마다 구현자 1개 순차 → 커밋 → \`plan-reviewer\` → push."
```

Also change the opening line of `$ctx` — `**이 세션에서 곧바로 구현을 시작하지 마세요.**` — to:

```sh
**아래 점검과 리뷰를 끝내기 전에는 구현을 시작하지 마세요.**
```

The old sentence is now false for the full-auto path, and it is the first instruction the model reads.

- [ ] **Step 3: Add the fixture for the modes-file-present branch**

Insert after line 96 of `scripts/test-hooks.sh` (the `pass "plan-saved-session-boundary presplit overview/task branches"` line):

```sh
# plan-saved-session-boundary: 모드 파일이 있으면 게이트 라우팅과 리뷰어 지시가 나온다.
modes_file="$TEST_ROOT/plan-exec-modes.md"
printf '# modes\n' >"$modes_file"
routed_overview="$plan_root/docs/woobin_plan/plans/2026-08-27-routed/00-overview.md"
mkdir -p "$(dirname "$routed_overview")"
printf '# Plan\n\n- task\n' >"$routed_overview"
out=$(printf '%s' "{\"session_id\":\"plan-routed-session\",\"tool_input\":{\"file_path\":\"$routed_overview\"}}" \
  | HOME="$TEST_HOME" TMPDIR="$TEST_TMP" PLAN_EXEC_MODES_FILE="$modes_file" \
      "$HOOKS/plan-saved-session-boundary.sh")
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("plan-document-reviewer-prompt.md")' \
  "plan-saved-session-boundary: 리뷰어 지시가 없다"
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("게이트 0개") and contains("게이트 1개 이상")' \
  "plan-saved-session-boundary: 게이트 라우팅 분기가 없다"
assert_json "$out" '.hookSpecificOutput.additionalContext | contains("모드 ②a")' \
  "plan-saved-session-boundary: ②a 킥오프가 없다"
pass "plan-saved-session-boundary 게이트 라우팅 분기"
```

- [ ] **Step 4: Run the checks**

```bash
sh -n woobin-harness/hooks/plan-saved-session-boundary.sh && ./scripts/test-hooks.sh
```

Expected: PASS, including the four pre-existing `plan-saved-session-boundary` assertions. If `2026-08-21-sample 플랜으로 구현` now fails, the no-modes-file fallback was edited — revert that part.

- [ ] **Step 5: Commit**

```bash
git add woobin-harness/hooks/plan-saved-session-boundary.sh scripts/test-hooks.sh
git commit -m "feat(hook): 플랜 저장 훅에 게이트 라우팅 분기 + 리뷰어 지시"
```
