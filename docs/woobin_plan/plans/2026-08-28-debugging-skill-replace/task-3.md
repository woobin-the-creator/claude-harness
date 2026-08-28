### Task 3: Record the narrative in HARNESS-LOG

**Files:**
- Modify: `home/HARNESS-LOG.md` — insert a new `## 32.` section

**Interfaces:**
- Consumes: the skill name `repro-loop` from Task 1.
- Produces: nothing.

**Placement:** the file's entries run `## 1.` … `## 31. grill-me → interview, 그리고 안 움직이는 메뉴 (2026-08-27)`, followed by a trailing `## 규율 (이 이력에서 반복 확인된 것)` section. Insert `## 32.` **between** entry 31 and the `## 규율` section — not at the end of the file.

**Format:** entries in this file use bold labels `**계기**` / `**근거**` / `**수단**` / `**재측정 대상**`. Match that. Do not invent new labels.

- [ ] **Step 1: Insert the entry**

Insert this section immediately before the line `## 규율 (이 이력에서 반복 확인된 것)`:

```markdown
## 32. 274줄 중 값을 낸 건 세 조항이었다 (2026-08-28)

**계기** — `systematic-debugging`이 모델 발전으로 낡은 스캐폴드인지 물었다. 이 레포는 이미
"미사용은 제거 사유가 아니다"(#27)를 규정으로 갖고 있어서, 발동 횟수가 아니라 **전제가 살아
있는지**를 봐야 했다.

**근거** — 셋을 쟀다.

1. **발동 3회 / 세션 JSONL 1,803개** (2026-07~08). 07-31 superpowers본, 08-07 로컬본,
   08-28 플러그인본.
2. **막으려는 실패 모드가 관측되지 않는다.** 버그 신호가 든 사용자 턴 923건 중 모델의 첫
   행동이 조사(Read/Grep/Bash)인 것이 903건(97.8%), 곧장 Edit은 11건. "추측하지 마" 류
   사용자 리다이렉트는 **0건**. 3회+ 수정 스래싱 후보는 2건이고 둘 다 디버깅이 아니라 플랜
   실행이었다.
3. **결정적인 것** — 재현/실패 테스트 산출물을 실제로 만든 세션 16개 중 **15개가 이 스킬을
   한 번도 발동하지 않은** 세션이다. 즉 "수정 전 재현"은 스킬이 만든 습관이 아니다.
   (첫 분석에서 "5/36"이라는 반대 결론을 냈었는데, 그 36의 분모가 대부분 디버깅이 아니라
   스킬 로드 턴·플랜 실행이었다. 분모를 고치자 결론이 뒤집혔다.)

**출처 판정** — upstream(obra/superpowers)과 diff했다. 보조 파일 3개
(`root-cause-tracing.md`·`defense-in-depth.md`·`condition-based-waiting.md`)는 **바이트 동일**,
`SKILL.md`는 47줄만 다르고 그것도 "Iron Law"·MUST 같은 강제 문구를 뺀 것이 전부다.
최초 패키징 커밋 `d6c6a5b` 이후 **수정 0회** — 두 번 재작성한 `interview`와 대비된다.

**문헌** — 이 카테고리 자체가 죽은 게 아니라 **형태**가 죽었다.

- Anthropic 컨텍스트 엔지니어링: *"Smarter models require less prescriptive engineering."*
  스킬 작성 가이드는 모델별 체크 항목에 *"Claude Opus: Does the Skill avoid over-explaining?"*를
  따로 둔다. 권장 절차도 "스킬 없이 베이스라인부터 재고 그 격차만 채워라"다 — 위 실측이 그것이다.
- **SWE-Doctor** (arXiv 2607.00990, 2026-07): 재현 테스트를 그냥 주면 이득이 제한적이거나
  **음수**다. fail-to-fail은 에이전트를 오도하고, fail-to-pass도 이슈의 한 단면만 덮어 부분
  패치를 만든다. 다면적 재현을 **실행·디버깅해 런타임 진단으로 바꾸면** SWE-bench Pro에서
  +8.0~8.9pp(LLM 백엔드 5종, 10개 조합 전부). 옛 본문의 "수정 전 실패 테스트 필수"는 낡은 게
  아니라 **측정상 역효과 쪽**이었다.
- **PROBE** (arXiv 2605.08717, 2026-05): 실패 후 구조화된 복구는 효과 있으나 조건부다 —
  *"정확한 진단은 필요하지만, 다음 시도가 실행·검증할 수 있는 bounded guidance로 번역되지
  않으면 불충분하다"*(복구율 +12.45pp). 옛 본문의 4.5는 "사람과 상의하라"로 끝나 이 조건을
  못 채웠다.
- 앵커링 완화 처방은 조기 가설 다양화다. 옛 본문의 "Form Single Hypothesis"는 반대 방향이었다.
  (다만 그 연구의 대상 모델이 Llama 3.2·Command R+라 Opus 5 외삽은 약하다 — 방향으로만 쓴다.)

**수단** — `repro-loop` 55줄. 세 조항만 남겼다: ① red 가능·결정론적·빠른 루프를 먼저
② 재현은 다면적으로, 실행해서 런타임 진단 기록으로 ③ 실패는 사람 호출이 아니라 다음 시도가
검증할 수 있는 지시로 닫기. 버린 것은 Red Flags 목록·Common Rationalizations 표·
"your human partner's Signals" 절(원저자 이름을 sed 치환한 흔적)·Iron Law 잔재다.

**Codex를 위해 자작을 골랐다** — `skills/`는 양쪽 런타임이 공유하는데 Codex에는 mattpocock
플러그인이 없다. Claude만 `mattpocock-skills:diagnosing-bugs`로 보내면 Codex는 디버깅 문이
사라지고 `kick-off` 문 목록이 런타임별로 갈린다. 벤더링은 거절했다 — 지금 지우는 것과 똑같은
실패(얼어붙은 upstream 사본)를 다시 만든다.

**이름을 가른 이유** — `mattpocock-skills:diagnosing-bugs`가 일반 버그 트리거 공간
("broken/throwing/failing/slow")을 이미 갖고 있다. 두 description이 같은 공간에서 경쟁하면
`explain`/`explain-in-html` 때와 같은 프롬프트 충돌이 난다(`workflow-spec` §4). 그래서 새
description은 버그 트리거 단어를 쓰지 않고 "이 하네스의 디버깅 문 · `kick-off`이 라우팅"으로만
자기를 규정한다.

**재측정 대상** — 다음 `capability-audit` 때 둘을 센다. (1) `repro-loop` 발동 횟수와, 발동
없이 재현 산출물을 만든 세션의 비율(지금 15/16). 그 비율이 그대로면 ①도 스캐폴드가 아니라
기본값이라는 뜻이므로 ②③만 남긴다. (2) 실패 시도 뒤 "다음 시도가 검증할 수 있는 지시"로 닫힌
비율 — PROBE의 조건을 실제로 충족하는지. 표본이 두 달간 실제 디버깅 5건뿐이라 다음 audit에서도
얇을 수 있다. **얇으면 얇다고 적고 판정을 미룬다.**
```

- [ ] **Step 2: Verify placement**

```bash
grep -n '^## 3[12]\.\|^## 규율' home/HARNESS-LOG.md
```

Expected: `## 31.`, then `## 32.`, then `## 규율` — in that order.

- [ ] **Step 3: Commit**

```bash
git add home/HARNESS-LOG.md
git commit -m "docs(history): #32 — 274줄 중 값을 낸 건 세 조항이었다

발동 3회 / JSONL 1,803개 · 재현 산출물 16세션 중 15세션이 스킬 미발동 ·
upstream과 보조 파일 3개 바이트 동일 · SWE-Doctor가 \"수정 전 실패 테스트 필수\"를
이득 제한적/음수로 측정 · PROBE의 bounded guidance 조건 · 앵커링."
```
