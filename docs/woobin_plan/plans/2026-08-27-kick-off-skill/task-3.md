### Task 3: Rule R20 + HARNESS-LOG #30 + full verification

**Files:**
- Modify: `docs/workflow-spec.md` (insert R20 after R19, before `## 4. 구성요소 인벤토리`)
- Modify: `home/HARNESS-LOG.md` (insert entry #30 after entry #29, before `## 규율 (이 이력에서 반복 확인된 것)`)

**Interfaces:**
- Consumes: everything Tasks 1 and 2 created — the skill at `woobin-harness/skills/kick-off/SKILL.md`, the hook at `woobin-harness/hooks/kickoff-guard.sh`, the state file contract `.claude/kickoff.local.md` (`active`, `stage`), and the env knobs `KICKOFF_STATE_FILE` / `KICKOFF_KEYWORD_PATTERN` / `KICKOFF_DRIFT_PATTERN`.
- Produces: nothing later depends on.

---

- [ ] **Step 1: Add rule R20 to `docs/workflow-spec.md` §3**

Find the end of `### R19 — 플랜 산출물은 영어로 쓴다` (it ends with a `무효화 조건` paragraph followed by a `---` separator and then `## 4. 구성요소 인벤토리`). Insert this new section between that `---` and `## 4`:

```markdown
### R20 — 워크플로우 진입점은 하나이고, 사람만 연다

**문제** 파이프라인 A~D의 첫 스킬 이름을 사용자가 전부 외워야 했다. 스킬이 늘거나 이름이 바뀌면
외울 목록도 같이 바뀐다. 그리고 진입 스킬을 모델 자동 발동에 맡기면 트리거가 겹치는 순간 안 뜬다 —
`brainstorming`이 `grill-me`와 겹쳐 3일 246세션 **발동 0회**로 삭제된 게 실측이다(HARNESS-LOG #27).

**규칙** 진입점은 `kick-off` 하나다. `disable-model-invocation: true`(Codex는 `agents/openai.yaml`의
`policy.allow_implicit_invocation: false`)로 **사람만** 부른다. 스킬 본문은 하위 스킬을 이름으로만
부르고 절차를 옮겨 적지 않는다. **난이도는 판정하지 않는다** — 호출됐다는 사실 자체가 사용자의 판정이다.

**기전** 둘이다. ① 스킬 `kick-off`이 레포 상태(`plans/`·`specs/`)로 진입 지점을 정하고
`.claude/kickoff.local.md`에 `stage`를 적는다. ② 훅 `kickoff-guard.sh`(UserPromptSubmit)가 키워드를
정규식으로 잡아 스킬의 **파일 경로**를 준다(스킬 이름을 부르지 않는다 — 막힌 스킬은 모델의 Skill
목록에 없을 수 있고, 없는 스킬을 부르는 훅은 조용히 죽는다). 같은 훅이 `stage`가 `spec`/`plan`인데
구현 의도 프롬프트가 오면 세션 1회 알린다. 차단하지 않는다.

**근거** 삭제된 `brainstorming`의 발동 0회(#27)가 자동 발동 프론트도어의 실패 실측이다. 사람만 부르는
얇은 진입점은 공식 마켓플레이스 `mattpocock-skills`의 user-invoked/model-invoked 2층 규약과 같은
형태이고(그 플러그인의 `grill-me` 본문은 `Run a /grilling session.` 한 줄이다), 상태 파일 + 훅은
공식 `ralph-loop`의 `.claude/ralph-loop.local.md` + Stop 훅과 같은 형태다.

**대가** ① 진입점이 하나라 그 문이 틀리면 전부 틀린다 — 그래서 라우트를 한 줄로 선언해 사람이 즉시
잡게 한다. ② 상태 파일이 하나 늘고 워크트리마다 따로 산다. ③ 이탈 알림의 판정이 프롬프트 정규식이라
오탐이 있다 — 세션 1회 + 비차단으로 상한을 둔다. ④ **분류 검사가 없다.** 오분류가 관측되면 그때
`design-workflow` 형태의 route contract test·eval을 붙인다(§6-3). 지금 짓지 않는 이유는 관측 0건이고,
`design-workflow`의 eval 5케이스조차 자기 `none` 라우트를 채점하지 않아 선례가 그 방향을 지지하지 않는다.

**무효화 조건** — 다음 중 하나라도 참이면 지워라
- 하네스가 스킬 체이닝을 1st-party로 제공한다(한 스킬이 다음 스킬을 결정론적으로 호출) → 라우터 산문이 불필요해진다
- `disable-model-invocation`이 없어지거나 의미가 바뀐다 → 규칙의 절반(트리거 경쟁 제거)이 근거를 잃는다.
  그 경우 §7-A의 네임스페이스 접두사 안(GitHub spec-kit의 `/speckit.*` 형태)을 먼저 재검토해라
- 이탈 알림이 경고 피로로 무시되기 시작한다 → **분기 B만** 떼라. 분기 A(키워드 진입)는 독립적으로 유효하다
- 파이프라인 분기가 하나로 줄어든다 → 라우터가 필요 없다
```

- [ ] **Step 2: Add HARNESS-LOG entry #30**

Insert this entry into `home/HARNESS-LOG.md`, after the end of `## 29. codex-harness 0821~0826 이식 (2026-08-26)` and before `## 규율 (이 이력에서 반복 확인된 것)`:

```markdown
## 30. 진입점을 하나로 — 그리고 그 문은 사람만 연다 (2026-08-27)

**계기** — 이 하네스를 쓰려면 `grill-me`·`design-workflow`·`systematic-debugging` 중 무엇을 먼저
부를지 사용자가 알아야 했다. 스킬이 늘거나 이름이 바뀔 때마다 외울 목록이 바뀐다.

**왜 자동 발동이 아닌가** — #27에서 `brainstorming`을 지운 이유가 그대로 적용된다. 그 스킬은 파이프라인
A의 첫 자리에 있었는데 3일 246세션에서 **발동 0회**였다. `grill-me`와 트리거 공간이 겹쳤기 때문이다.
진입점을 또 모델 판단에 맡기면 같은 방식으로 죽는다. 그래서 `disable-model-invocation: true`로
**사람만** 부르게 막고, 키워드("킥오프")는 모델의 추론이 아니라 훅의 **정규식**이 잡게 했다.

**외부 조사** — 설계 전에 공식 마켓플레이스와 알려진 오케스트레이션 레이어를 훑었다.
`mattpocock-skills`가 스킬 35개를 user-invoked 20 / model-invoked 15로 갈라놓고 그 규약을
`.agents/invocation.md`에 따로 문서화해뒀다 — user-invoked는 얇고(그 플러그인의 `grill-me` 본문은
`Run a /grilling session.` 한 줄), 깊은 방법론은 model-invoked가 갖는다. 공식 `ralph-loop`는 커맨드가
`.claude/ralph-loop.local.md`에 상태를 쓰고 Stop 훅이 그걸 읽는 형태로 세션을 잔류시킨다. 두 형태를
가져왔다. GitHub spec-kit의 `/speckit.*` 네임스페이스 안은 기각했다(외울 게 여전히 N개다).
`superpowers`의 상시 세션 주입은 §7-A에서 이미 기각된 형태라 후보에서 뺐다 — 게다가 그쪽도 실제
단계 전환은 사용자 문구가 튼다. **최대치의 강제를 걸어도 체이닝은 산문으로 안 된다는 실증이다.**

**조치** — 스킬 1개(`kick-off`, 20 → 21), 훅 1개(`kickoff-guard.sh`, 12 → 13, Codex 연결 4 → 5),
상태 파일 `.claude/kickoff.local.md`(gitignore). 규칙은 §3 R20.

**안 한 것** — 난이도 라우팅과 라우팅 eval. `/kick-off`가 눌렸다는 것 자체가 "워크플로우 태울 일"이라는
사용자의 판정이고, 크기 조절은 `grill-me`("두 줄짜리 변경엔 두 줄짜리 스펙")와 `writing-plans`의
Scope Check가 **이미** 한다. 여기서 또 하면 규율 6(같은 문장을 두 곳이 소유하지 않는다) 위반이다.
오분류는 아직 0건이라 검사도 안 지었다 — §7-A의 "훅 신설 0개로 시작한다"와 같은 계산이다.

**교훈** — 훅이 스킬을 **이름으로** 부르면 안 되는 이유가 하나 더 생겼다. #22·#28은 "지운 스킬 이름이
훅에 남는다"였는데, 이번 건 반대다. 스킬이 **존재하는데도** `disable-model-invocation` 때문에 모델의
Skill 목록에 없을 수 있다. 그래서 `kickoff-guard.sh`는 이름 대신 `SKILL.md`의 **경로**를 준다.
```

- [ ] **Step 3: Confirm the superpowers dependency table needs no row**

The table at `home/HARNESS-LOG.md` under `## ⚠️ 훅 ↔ superpowers 의존 관계 (제거 시 주의)` lists only the hooks whose trigger depended on `superpowers`. `kickoff-guard.sh` has no such dependency, and the table is not a full inventory (7 rows for 12 hooks). **Do not add a row.** The full hook inventory lives in `docs/workflow-spec.md` §4, which Task 2 already updated.

- [ ] **Step 4: Run every gate**

```bash
./scripts/check-harness-docs.sh
./scripts/test-hooks.sh
./scripts/test-skills.sh
./scripts/validate-codex.sh
claude plugin validate ./woobin-harness
```

Expected:
- `check-harness-docs.sh` — no `✗`, and the `home/HARNESS-LOG.md` warning from Task 2 is now gone.
- `test-hooks.sh` — all `✓`. A `stale-branch-guard` failure is a known pre-existing defect (recorded in PR #26); if it is the only failure, say so explicitly rather than treating the run as clean.
- `test-skills.sh` — all `✓`, including `✓ 21 packaged skills`.
- `validate-codex.sh` — passes; it installs the plugin into a temp `CODEX_HOME` and asserts 21 skills are exposed.
- `claude plugin validate ./woobin-harness` — valid. This is the only command that catches a broken YAML frontmatter, and `kick-off/SKILL.md` introduces a frontmatter key (`disable-model-invocation`) this repo has never used before, so do not skip it.

If `claude plugin validate` rejects `disable-model-invocation`, the Claude-side half of decision 1 is not available in this harness version. In that case: keep the skill, remove only that one frontmatter line, keep the Codex `policy` block, and report the finding — do **not** add trigger phrases to the `description` as a substitute, because that revives exactly the competition R20 exists to prevent.

- [ ] **Step 5: Commit**

```bash
git add docs/workflow-spec.md home/HARNESS-LOG.md
git commit -m "docs(spec): R20 — 진입점 하나, 사람만 연다 + HARNESS-LOG #30"
```

- [ ] **Step 6: Manual smoke check (no automation covers this)**

Restart Claude Code so the new plugin version loads, then:

1. Type `/kick-off` — the skill should appear in the slash-command list and open.
2. In a fresh prompt type `킥오프 하자` — the hook should inject a line pointing at `skills/kick-off/SKILL.md`.
3. Type `sdd-kickoff-guard.sh 좀 보자` — the hook must stay silent.

Report what actually happened for each. If step 1 fails, check that the installed version is `1.15.0`:

```bash
claude plugin marketplace update woobin-harness
claude plugin update woobin-harness@woobin-harness
jq -r '.plugins["woobin-harness@woobin-harness"][].version' ~/.claude/plugins/installed_plugins.json
```
