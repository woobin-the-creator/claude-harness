### Task 4: Update `workflow-spec.md` §3/§4 and append the `HARNESS-LOG.md` entry

**Files:**
- Modify: `docs/workflow-spec.md:73`, `:606`, `:712`, `:719`, `:723`, and append a paragraph after line 736
- Modify: `home/HARNESS-LOG.md` — append entry `## 31.` before the `## 규율` section that begins at line 807

**Interfaces:**
- Consumes: everything Tasks 1–3 changed. This task describes the finished state.
- Produces: nothing Task 5 reads. Task 5 only bumps versions and runs validation.

**Do not create a new `### R21` rule in §3.** This looks like it should become one, and it should not. The repo already ruled on the identical case at `docs/workflow-spec.md:735-736`, verbatim:

```
**§3에 새 규칙을 만들지 않았다** — 훅·에이전트에 걸리는 하네스 규칙이 아니라 스킬 내부 규율이고,
채울 `무효화 조건`이 "실측 27건"뿐이라 §0이 요구하는 등급에 못 미친다. 서사는 `home/HARNESS-LOG.md` #26.
```

The re-ask rule is the same shape — internal skill discipline, not a hook or agent contract — and its measurement is *thinner*: 6 sessions of the current body versus the 27 that were judged insufficient. Promoting it to §3 while a weaker case was denied would make §3's admission bar meaningless. It goes into the §4 narrative instead, exactly where the 2026-08-21 rewrite went.

**Which mentions of the old name change here.** Live membership statements — the pipeline diagram, the inventory roster, cross-references to the skill's own sections — get renamed. Three categories keep `grill-me` and must not be touched:
- Lines 618, 725, 726, 757, 758, 759, 763 — narrative about measurements taken under the old name.
- Line 632 — this one names a **different repo's skill**: `mattpocock-skills` ships its own `grill-me` whose body is the single line `Run a /grilling session.` Renaming it would make the sentence false.
- Everything in `home/HARNESS-LOG.md` entries #1–#30.

---

- [ ] **Step 1: Rename the five live lines in `docs/workflow-spec.md`**

Line 73, find:

```
   │     grill-me 스킬로 스펙 초안 → 빈칸 인터뷰 → 결정 원장(필요하면 스펙 저장)
```

Replace with:

```
   │     interview 스킬로 스펙 초안 → 빈칸 인터뷰 → 결정 원장(필요하면 스펙 저장)
```

This line sits inside an ASCII diagram. `interview` is one character longer than `grill-me`; do not re-pad the surrounding box characters, the diagram does not align on that column.

Line 606, find:

```
사용자가 한 줄씩 짚어 반증하는 게 존재 이유다(`grill-me` §32).
```

Replace with:

```
사용자가 한 줄씩 짚어 반증하는 게 존재 이유다(`interview` §32).
```

The `§32` is a line number inside the skill body and it does not move: Task 1's insertions all begin at line 109 or later.

Line 712, find:

```
`policy.allow_implicit_invocation: false`) — 사람만 부를 수 있어서 `grill-me`와 트리거가 경쟁하지
```

Replace with:

```
`policy.allow_implicit_invocation: false`) — 사람만 부를 수 있어서 `interview`와 트리거가 경쟁하지
```

Line 719, find:

```
파이프라인에 직접 물린 것: `kick-off` · `grill-me` · `writing-plans` · `systematic-debugging` ·
```

Replace with:

```
파이프라인에 직접 물린 것: `kick-off` · `interview` · `writing-plans` · `systematic-debugging` ·
```

Line 723, find:

```
`grill-me`는 파이프라인의 **첫 단계**인데 2026-08-21까지 이 목록에 빠져 있었다(`docs/workflow.html`에는 있었다).
```

Replace with:

```
`interview`(2026-08-27까지 `grill-me`)는 파이프라인의 **첫 단계**인데 2026-08-21까지 이 목록에 빠져 있었다(`docs/workflow.html`에는 있었다).
```

This one keeps the old name in parentheses because everything below it in §4 still says `grill-me`, and a reader needs one place that connects the two names.

- [ ] **Step 2: Append the §4 narrative paragraph**

Find this paragraph in `docs/workflow-spec.md` (currently lines 735-736, the last two lines of the 2026-08-21 rewrite passage):

```
**§3에 새 규칙을 만들지 않았다** — 훅·에이전트에 걸리는 하네스 규칙이 아니라 스킬 내부 규율이고,
채울 `무효화 조건`이 "실측 27건"뿐이라 §0이 요구하는 등급에 못 미친다. 서사는 `home/HARNESS-LOG.md` #26.
```

Leave it in place and insert this block **immediately after** it, separated by one blank line:

```
2026-08-27, 같은 스킬을 `interview`로 개명하고 규칙을 하나 더했다. 이름이 본문과 반대였다 — 본문
3행이 이미 "내가 사용자를 심문하지 않는다"인데 이름만 08-21 재작성 전 물건이 남아 있었고, 공식
`mattpocock-skills`의 `grilling`과 트리거 공간도 겹쳤다. 근거는 다시 실측이다 — `/grill-me` 호출을
2026-08-03~08-27 전수로 봤다(31건). 이 중 **현재 본문이 실제로 로드된 건 6건**뿐이고(명시 호출 3 +
자동 발동 3), 나머지는 구본이거나 캐시가 뒤처진 상태였다. 라운드 수는 1·5·1·1·1·1로 중앙값 1이라
`deep-interview`류의 **세션 라운드 상한은 6건 중 0건에 걸린다** — 그래서 넣지 않았다. 유일한 5라운드
세션의 원인은 다른 데 있었다: 같은 빈칸을 세 번 묻는 동안 **선택지 label이 세 번 다 동일**했고,
사용자의 1·2라운드 답은 둘 다 "그 선택지의 대가를 설명해줘"였다. 규정이 없던 자리라 조문화했다 —
되물음을 받으면 답한 내용을 선택지에 접어 넣어 **메뉴를 다시 구성하기 전에는 다시 묻지 않는다**.
`plan-exec-modes.md`의 "PR 본문은 포인터만"에도 좁은 예외를 뚫었다 — 같은 파일이 머지 전 플랜
디렉터리 삭제를 권장하므로, 사용자가 고른 적 없이 모델이 확정한 결정과 가정은 머지 후 소유자가
0이 된다. 그것만 PR 본문에 직접 남긴다. **여기서도 §3에 규칙을 만들지 않았다** — 위와 같은 이유이고
표본은 오히려 더 얇다(6건). 서사는 `home/HARNESS-LOG.md` #31.
```

- [ ] **Step 3: Append the `HARNESS-LOG.md` entry**

In `home/HARNESS-LOG.md`, find the section header that currently begins line 807:

```
## 규율 (이 이력에서 반복 확인된 것)
```

Insert this entire entry **immediately before** it, separated by a blank line on each side:

```
## 31. grill-me → interview, 그리고 안 움직이는 메뉴 (2026-08-27)

**발단**: 사용자가 셋을 요청했다 — ① 쉬운 작업이면 인터뷰를 스킵하는 라우트 ② 트레이드오프 없는
선택지는 묻지 말고 자동 선택하되 무엇을 골랐는지 PR에 남기기 ③ `oh-my-claudecode`의 `deep-interview`
벤치마킹(인터뷰가 기약없이 길어지고 특정 영역 스펙이 덜 닫히는 문제). 더해서 스킬 개명.
"적용하는 게 맞는 선택인지 먼저" 판단해 달라는 요구가 붙어 있었다.

**조사에서 셋이 이미 결론이 나 있었다.** ①은 어제 머지한 `kick-off`에 `## 난이도는 판정하지 않는다`
절이 통째로 있었다. ②의 자동 선택 분기는 `grill-me` §③에 세 필터 + 뒤집기 조건으로 이미 있었다 —
없던 건 기록이 PR까지 가는 경로뿐이다. ③의 `deep-interview`는 원문 802행을 읽어보니 핵심 메커니즘이
증상을 **악화**시켰다: 한 번에 한 질문(이 스킬은 정반대를 실측으로 채택했다), 라운드 4·6·8에 challenge
모드 주입(설계상 라운드 증가), ambiguity 자기 채점 후 자기 게이트 통과(#29에서 `spec_contract.py`를
같은 이유로 기각한 전례가 있다).

**측정**: `/grill-me` 호출을 2026-08-03~08-27 전수로 셌다 — 31건. 현재 본문이 실제로 로드된 건
**6건**(명시 3 + 자동 발동 3). 라운드 수 1·5·1·1·1·1, 중앙값 1. 구본 27건도 중앙값 1이었다.
부수로 하나 나왔다 — 08-20·08-21 호출 3건이 **구본을 로드했다**. #26이 기록한 캐시 지연이 로그에
그대로 찍혀 있었다.

**두 요청이 측정에 뒤집혔다.** 라운드 상한은 5로 걸어도 6건 중 0건에 걸린다. 유일한 5라운드 세션
(08-26 CSV export)을 열어보니 접근 질문 3연속인데 **선택지 label이 세 번 다 글자 그대로 같았다** —
`C. 하이브리드 (추천) / A. 전부 클라이언트 / B. 전부 백엔드`. 바뀐 건 앞 문장뿐. 그런데 사용자 답은
1라운드 "필터를 거친 데이터를 뽑고싶다면 클라이언트 방향으로 가야해?", 2라운드 "전부 백엔드로 갈 경우
트레이드오프가 뭔지 예시를 들어 설명해줘"였다 — **우유부단이 아니라 §③이 첫 메뉴에 넣으라고 규정한
정보를 캐물은 것**이다. 상한이 걸렸다면 사용자가 B의 대가를 보기 전에 닫혔다. 토폴로지 락도 근거가
없었다: 6건에서 형제 항목 굶주림 0건이고, 그 세션조차 접근이 닫히자 `[?1][?2][?3]`이 한 라운드에 나왔다.

**수단**: `deep-interview`에서 이식한 것은 **0개**다. 대신 실측이 가리킨 자리에 규칙 하나를 세웠다 —
되물음을 받으면 답한 내용을 선택지에 접어 넣어 메뉴를 다시 구성하기 전에는 다시 묻지 않는다(label을
쪼개거나, 탈락한 후보를 지우거나, 빈칸을 나눈다. 셋 다 못 하면 더 물을 게 없는 것이므로 추천안으로
확정한다). 라운드 상한은 명시적으로 **두지 않는다**고 본문에 적었다 — 안 적으면 다음 세션이 다시 넣는다.
`plan-exec-modes.md`에는 "PR 본문은 포인터만"의 좁은 예외를 뚫었다. 같은 파일이 머지 전 플랜 디렉터리
삭제를 권장하므로 자동 확정분의 소유자가 머지 후 0이 되기 때문이다.

**개명**: `grill-me` → `interview`. 이름이 본문과 반대였다(본문 3행: "내가 사용자를 심문하지 않는다").
`grill me`·`그릴` 트리거는 description에서 뺐다 — `mattpocock-skills:grilling`이 그 phrase의 정당한
주인이고, 그건 기존 플랜을 두들기는 다른 스킬이다. 역사 서술(이 로그 #1~#30, `workflow-spec` §4의
측정 서사)의 `grill-me`는 **안 고쳤다** — 그 시점 실측의 대상이라 이름을 바꾸면 근거가 대상을 잃는다.

**재측정 대상**: 되물음 후 메뉴 재구성 규칙의 효과. 현재 표본이 6건 / 6일이라 #26의 27건과 근거
두께가 다르다. 다음 `capability-audit` 때 라운드 분포와 "동일 label 재사용" 발생 여부를 다시 센다.
```

- [ ] **Step 4: Verify only historical mentions remain in the two docs**

```bash
cd /Users/mac_wb/.paseo/worktrees/11zirkjp/rabid-stingray
command grep -n "grill-me" docs/workflow-spec.md
```

Expected: lines 618, 632, 723 (inside the new parenthetical), 725, 726, 757, 758, 759, 763 — and nothing else. Line numbers shift by the paragraph inserted in Step 2; match on content, not on the numbers.

```bash
command grep -c "grill-me" home/HARNESS-LOG.md
```

Expected: a non-zero count. Entries #1–#30 keep the old name by design; the only requirement is that entry #31 exists and explains the rename.

- [ ] **Step 5: Verify no new R-rule was created**

```bash
command grep -n "^### R2[0-9]" docs/workflow-spec.md
```

Expected: only `### R20 — 워크플로우 진입점은 하나이고, 사람만 연다`. If an `R21` appears, delete it and move its content into the Step 2 paragraph.

- [ ] **Step 6: Run the completion check**

```bash
command grep -n "서사는 \`home/HARNESS-LOG.md\` #31" docs/workflow-spec.md
command grep -n "^## 31\. grill-me → interview" home/HARNESS-LOG.md
```

Expected: one line from each.

- [ ] **Step 7: Commit**

```bash
git add docs/workflow-spec.md home/HARNESS-LOG.md
git commit -m "docs: interview 개명·되물음 규칙을 workflow-spec §4와 HARNESS-LOG #31에 기록"
```
