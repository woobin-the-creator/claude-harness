### Task 1: Swap the skill directory

**Files:**
- Create: `woobin-harness/skills/repro-loop/SKILL.md`
- Delete: `woobin-harness/skills/systematic-debugging/` (6 files: `SKILL.md`, `root-cause-tracing.md`, `defense-in-depth.md`, `condition-based-waiting.md`, `condition-based-waiting-example.ts`, `find-polluter.sh`)
- Test: `scripts/test-skills.sh` (existing, do not modify)

**Interfaces:**
- Produces: the skill name `repro-loop`. Tasks 2 and 3 write that exact string into other files. Frontmatter `name:` must be exactly `repro-loop`.
- Consumes: nothing.

**Why the count must not change:** `scripts/test-skills.sh:19` asserts `[ "$skill_count" -eq 21 ]` and `scripts/validate-codex.sh:144` asserts the same. Deleting one directory and creating one directory keeps 21. Do not touch those assertions.

- [ ] **Step 1: Create the new skill directory and file**

Create `woobin-harness/skills/repro-loop/SKILL.md` with exactly this content:

```markdown
---
name: repro-loop
description: 이 하네스의 디버깅 문. 고칠 대상을 red로 만드는 재현 루프를 먼저 세우고, 그 루프를 실행·디버깅해 런타임 진단 기록으로 바꾼 다음에 패치한다. `kick-off`이 디버깅 경로로 라우팅할 때, 또는 사용자가 repro-loop을 직접 부를 때 사용한다.
---

# repro-loop

패치보다 루프가 먼저다. 아래 셋만 지킨다 — 나머지는 판단에 맡긴다.

## ① 루프를 먼저 세운다

고칠 대상을 **red로 만들 수 있는 명령 하나**를 만든다. 테스트, curl, CLI 호출, 헤드리스
브라우저 스크립트, 캡처한 트레이스 재생, 최소 하니스 — 무엇이든 좋다. 조건은 넷이다.

- **red 가능** — 사용자가 말한 그 증상을 단언한다. "에러 없이 돈다"는 red가 아니다
- **결정론적** — 매번 같은 판정. 비결정 버그는 깨끗한 재현이 아니라 **재현률을 올리는 것**이
  목표다(100× 반복·병렬·타이밍 압박). 50%는 디버깅 가능하고 1%는 아니다
- **빠름** — 분이 아니라 초
- **에이전트가 돌릴 수 있음** — 사람 클릭이 필요하면 그 절차를 스크립트로 감싼다

루프를 못 만들면 **거기서 멈추고 말한다.** 시도한 것을 나열하고, 재현 환경 접근·캡처된
아티팩트(HAR·로그 덤프·화면 녹화)·임시 계측 허가 중 무엇이 필요한지 요청한다.
루프 없이 가설로 넘어가지 않는다.

## ② 재현은 다면적으로, 그리고 실행해서 기록으로 바꾼다

**단일 재현 하나를 통과시키는 것을 목표로 삼으면 부분 패치가 나온다.** 이슈에 서술된
행위 요구사항이 여럿이면 각각에 대한 재현을 만든다.

그리고 재현을 **돌려서 관찰한 것을 진단 기록으로 남긴다** — 어느 경계에서 값이 무엇으로
바뀌었는지, 어떤 레이어까지 도달했는지. 재현을 "통과해야 할 목표"가 아니라 **런타임 사실의
출처**로 쓴다. 패치는 그 기록을 근거로 쓴다.

계측을 넣었으면 `[DEBUG-<4자리>]` 같은 고유 접두사를 붙인다. 끝에 grep 한 번으로 지운다.

## ③ 실패는 사람 호출이 아니라 다음 시도의 지시로 닫는다

가설은 처음부터 **3~5개를 순위 매겨** 세운다. 하나만 세우면 첫 그럴듯한 생각에 고정된다.
각 가설은 반증 가능해야 한다 — "X가 원인이면 Y를 바꿨을 때 증상이 사라진다".

수정 시도가 실패하면:

1. 무엇이 red로 남았는지, 어느 가설이 죽었는지 기록한다
2. **다음 시도가 실행하고 검증할 수 있는 지시**로 닫는다. "아키텍처를 의심해봐야 한다"는
   지시가 아니다. "A를 B로 바꾸고 <명령>이 green이 되는지 본다"가 지시다
3. 그렇게 좁힌 지시가 안 나오면 — 그때가 사람을 부를 때다. 무엇을 못 좁혔는지와 함께 부른다

## 끝내기 전에

- 원래 재현이 더는 red가 아니다(루프를 다시 돌려서 확인)
- 회귀 테스트를 남겼거나, **남길 자리가 없다는 사실 자체를 발견으로 기록**했다.
  진짜 버그 패턴을 재현하지 못하는 seam에 테스트를 박으면 거짓 확신만 남는다
- `[DEBUG-...]` 계측과 임시 재현 파일을 지웠다
- 맞은 가설을 커밋·PR 본문에 한 줄로 남겼다

운영 에러였다면 `runbook-logger`로 넘긴다.
```

- [ ] **Step 2: Delete the old skill directory**

```bash
git rm -r woobin-harness/skills/systematic-debugging/
```

- [ ] **Step 3: Verify the count is still 21 and the frontmatter parses**

```bash
./scripts/test-skills.sh
claude plugin validate ./woobin-harness
```

Expected: `test-skills.sh` passes all items (it asserts `-eq 21`). `claude plugin validate` reports no error.

If `claude plugin validate` fails, check the `description:` line for a colon followed by a space inside the value — that makes YAML parse the scalar as a mapping and silently drops every frontmatter field. This is the `Explore.md` failure recorded in `CLAUDE.md`.

- [ ] **Step 4: Commit**

```bash
git add woobin-harness/skills/repro-loop/SKILL.md
git commit -m "refactor(skills): systematic-debugging → repro-loop, 274줄 upstream 사본을 연구가 지지하는 3조항으로

발동 3회 / 세션 JSONL 1,803개. 본문 대부분이 obra/superpowers 사본이고
보조 파일 3개는 upstream과 바이트 동일이었다 — 최초 패키징 커밋 이후 수정 0회.

- 버림: Red Flags · Common Rationalizations 표 · \"your human partner\" 절
- 교체: \"Form Single Hypothesis\" → 순위 매긴 3~5 가설 (앵커링)
- 교체: 무조건 \"수정 전 실패 테스트\" → 다면적 재현 + 런타임 진단 기록
- 신설: 실패는 다음 시도가 검증 가능한 지시로 닫는다

스킬 개수 21 유지."
```
