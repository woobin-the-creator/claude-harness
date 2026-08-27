### Task 1: Rename the skill directory and rewrite three sections of its body

**Files:**
- Rename: `woobin-harness/skills/grill-me/` → `woobin-harness/skills/interview/` (use `git mv`)
- Modify: `woobin-harness/skills/interview/SKILL.md` — frontmatter (lines 1-4), `### 묻는 방법` (ends line 109), `### 사용자가 되물으면` (lines 111-113), `## ④ 결정 원장` (after line 145)

**Interfaces:**
- Produces: the skill directory name `interview`, which becomes the slash command `/interview` and the plugin-namespaced name `woobin-harness:interview`. Tasks 3, 4, and 5 all reference these exact strings.
- Produces: the section anchor `§④` inside this file, which Task 2's prose cites by name.

There is no code in this task. Every block below is Markdown prose in Korean and must be pasted **verbatim** — do not translate, re-word, or reflow it.

---

- [ ] **Step 1: Rename the directory with `git mv`**

```bash
cd /Users/mac_wb/.paseo/worktrees/11zirkjp/rabid-stingray
git mv woobin-harness/skills/grill-me woobin-harness/skills/interview
```

Use `git mv`, not `mv` — it stages the rename so the diff reads as a rename instead of a delete plus an add.

- [ ] **Step 2: Verify the rename and the unchanged skill count**

```bash
test -f woobin-harness/skills/interview/SKILL.md && echo "SKILL.md moved"
test -d woobin-harness/skills/grill-me && echo "FAIL: old dir still exists" || echo "old dir gone"
find woobin-harness/skills -mindepth 1 -maxdepth 1 -type d | wc -l
```

Expected: `SKILL.md moved`, `old dir gone`, and `21`.

- [ ] **Step 3: Replace the frontmatter**

In `woobin-harness/skills/interview/SKILL.md`, replace lines 1-4 exactly.

Find this:

```
---
name: grill-me
description: 요구사항을 실행 가능한 스펙으로 굳힌다 — 레포 사실을 먼저 조사해 스펙 초안을 한 화면으로 내고, 정말 미결인 빈칸만 선택지로 인터뷰한 뒤, 기각한 대안과 그 이유까지 담은 결정 원장을 남긴다. 사용자가 "grill me", "계획을 검증/그릴/따져봐", "스펙 구체화", "요구사항 정리하자", "어떻게 만들지 먼저 정하자"라고 하거나, 여러 항목이 든 요청을 던지며 구현 전에 합의부터 하자고 할 때 사용한다.
---
```

Replace with this:

```
---
name: interview
description: 요구사항을 실행 가능한 스펙으로 굳힌다 — 레포 사실을 먼저 조사해 스펙 초안을 한 화면으로 내고, 정말 미결인 빈칸만 선택지로 인터뷰한 뒤, 기각한 대안과 그 이유까지 담은 결정 원장을 남긴다. 사용자가 "인터뷰", "스펙 구체화", "요구사항 정리하자", "계획을 검증/따져봐", "어떻게 만들지 먼저 정하자"라고 하거나, 여러 항목이 든 요청을 던지며 구현 전에 합의부터 하자고 할 때 사용한다.
---
```

Two things changed and both are deliberate:
- `name:` must equal the directory name or the plugin loader will not find the skill.
- The triggers `"grill me"` and `그릴` are **removed**. Keeping them would re-create the trigger collision with `mattpocock-skills:grilling` that renaming was meant to end. `grilling` is a different skill (stress-test an existing plan) and should win that phrase.

There must be no colon-plus-space inside the `description:` value. A `: ` there makes YAML parse the scalar as a mapping and **every frontmatter field silently vanishes**; the runtime is more permissive and still looks normal, so `claude plugin validate` in Step 9 is the only detector. This actually happened on 2026-08-08 in `Explore.md`.

- [ ] **Step 4: Add the measured justification to `### 묻는 방법`**

Find this line (it is the last line of the `### 묻는 방법` section, currently line 109):

```
**산문을 툴 안으로 밀어 넣지 마라.** 선택지 label은 1~5단어라, 대가와 다운스트림을 거기 넣으면 증발한다. 실측에서 값이 가장 컸던 게 그 두 줄이다. 툴은 클릭을 받는 자리지 설명하는 자리가 아니다.
```

Leave it in place and insert this new paragraph **immediately after** it, separated by one blank line:

```
**대가를 안 적으면 라운드가 늘어난다 — 실측이다.** 08-26 CSV export 세션에서 접근 선택 하나에 3라운드를 썼다. 사용자가 우유부단해서가 아니다. 1라운드 답은 "만약 페이지에서 걸어놓은 필터를 거친 데이터를 뽑고싶다면, 클라이언트 생성 방향으로 가야해?"였고 2라운드 답은 "전부 백엔드로 갈 경우 트레이드오프가 뭔지 예시를 들어 설명해줘"였다 — 둘 다 위 2번과 3번이 **첫 메뉴에 있었어야 할 것**을 캐물은 거다. 대가 한 줄은 예의가 아니라 왕복 절감 수단이다.
```

- [ ] **Step 5: Replace the `### 사용자가 되물으면` section**

Find these two lines exactly (heading plus its single paragraph):

```
### 사용자가 되물으면

"A는 어떤 식으로 해결되는 거야?", "B의 컨셉이 ~ 이런 거야?" — 실측에서 반복된 반응이다. 답하고 같은 빈칸을 다시 물어라. 되묻기는 사용자의 실수가 아니라 **선택지가 덜 구체적이었다는 신호**다. 다음 선택지의 다운스트림 줄을 더 날카롭게 써라.
```

Replace them with this whole block:

```
### 사용자가 되물으면 — 같은 메뉴를 다시 띄우지 마라

"A는 어떤 식으로 해결되는 거야?", "B로 가면 트레이드오프가 뭐야?" — 실측에서 반복된 반응이다. 답하고 같은 빈칸을 다시 물어라. 되묻기는 사용자의 실수가 아니라 **선택지가 덜 구체적이었다는 신호**다.

그런데 실측에서 여기를 틀렸다. 08-26 세션에서 같은 빈칸을 세 번 물었는데 **선택지 label이 세 번 다 글자 그대로 같았다** — `C. 하이브리드 (추천) / A. 전부 클라이언트 / B. 전부 백엔드`. 바뀐 건 질문 앞 문장뿐이었다. 답변은 대화 속으로 흘러가고, 사용자가 실제로 클릭할 자리에는 처음과 똑같은 메뉴가 남았다.

> 되물음의 **내용이 곧 빠진 정보**다. 그걸 선택지 안으로 접어 넣기 전에는 다시 묻지 마라.

두 번째로 물 때 최소한 하나는 달라져야 한다:

- **label이 달라진다** — 되물음이 가리킨 축으로 후보를 다시 쪼갠다(`B. 전부 백엔드` → `B1. 백엔드 · 필터 결과 전량 전송` / `B2. 백엔드 · 현재 창만`)
- **후보가 줄어든다** — 답하면서 탈락한 것을 지운다. 셋을 그대로 유지하는 건 방금 답한 내용이 아무것도 좁히지 못했다는 뜻이고, 그건 답이 빗나갔다는 신호다
- **빈칸이 쪼개진다** — 되물음이 실은 두 결정이 얽혀 있었다는 뜻이면 둘로 나눠 각각 묻는다

셋 중 아무것도 못 하겠으면 **더 물을 게 없는 것이다.** 추천안으로 확정하고 원장 `근거` 열에 `되물음 후 기본값 확정`으로 적어라.

**라운드 수에는 상한을 두지 마라.** 실측 6건의 라운드 중앙값은 1이고(1·5·1·1·1·1), 유일한 5라운드 세션은 사용자가 정당한 정보를 두 번 요구한 결과였다. 상한이 걸렸다면 사용자가 B의 대가를 보기 **전에** 닫혔을 것이다. 길어짐은 라운드 수의 문제가 아니라 **안 움직이는 메뉴**의 문제다.
```

- [ ] **Step 6: Add the PR-body rule to `## ④ 결정 원장`**

Find this paragraph (currently line 145):

```
원장은 대화 안에 산다. 파일로 떨구는 건 세 경우다: 사용자가 요청할 때, 이 설계가 이번 플랜보다 오래 살 때, 다른 세션에 넘길 때 → `docs/woobin_plan/specs/YYYY-MM-DD-<topic>-design.md`. 결정 서너 개짜리면 파일은 중복이다. 플랜의 "기각한 대안" 절이 같은 일을 한다.
```

Leave it in place and insert this block **immediately after** it, separated by one blank line. Note the inner fence uses four backticks so the three-backtick template survives:

````
**이 작업이 PR이 될 거라면, 자동 확정분은 PR 본문에 남긴다.** 대화에 남은 원장은 세션과 함께 사라지고, 플랜 디렉터리는 `plan-exec-modes.md`가 머지 전 삭제를 권장한다 — 머지된 뒤에는 diff 말고 아무것도 안 남는다는 뜻이다. 사용자가 고른 줄은 대화에 기록이 있지만, **내가 묻지 않고 확정한 줄과 가정은 어디에도 없다.** 그것만 적는다:

```
### 자동 확정된 결정
- <결정> — <고른 것>. 기각: <대안> — <이유>

### 가정
- <가정> — <왜 이 기본값인지>
```

원장 전문을 옮기지 마라. `plan-exec-modes.md`의 "PR 본문은 포인터만"이 여전히 기본값이고 이건 그 규칙의 **좁은 예외**다 — 포인터가 가리킬 소유자가 머지 후 0이 되는 항목에만 적용된다.
````

- [ ] **Step 7: Verify no stale self-references remain inside the skill body**

```bash
command grep -n "grill-me\|grill me" woobin-harness/skills/interview/SKILL.md
```

Expected: no output (exit code 1). If anything prints, fix it — the skill body must not refer to its own old name.

- [ ] **Step 8: Verify the three new sections landed**

```bash
command grep -c "같은 메뉴를 다시 띄우지 마라" woobin-harness/skills/interview/SKILL.md
command grep -c "자동 확정된 결정" woobin-harness/skills/interview/SKILL.md
command grep -c "대가를 안 적으면 라운드가 늘어난다" woobin-harness/skills/interview/SKILL.md
command grep -c "라운드 수에는 상한을 두지 마라" woobin-harness/skills/interview/SKILL.md
```

Expected: `1` from each of the four.

Use `command grep`, not bare `grep` — on this machine `grep` is a shell function wrapping `ugrep`, and it emits version banners into loop output.

- [ ] **Step 9: Run the completion check**

```bash
claude plugin validate ./woobin-harness && ./scripts/test-skills.sh
```

Expected: validate passes, and `test-skills.sh` prints `21 packaged skills` and exits 0.

If `test-skills.sh` fails with `expected 21 skills, found N`, the rename created or dropped a directory — check Step 2 again before anything else.

- [ ] **Step 10: Commit**

```bash
git add woobin-harness/skills/
git commit -m "refactor(interview): grill-me → interview 리네임 + 되물음 시 메뉴 재구성 의무"
```
