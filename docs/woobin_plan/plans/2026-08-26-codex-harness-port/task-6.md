### Task 6: 플랜 산출물 영문화 규칙

`writing-plans`가 만드는 산출물(`00-overview.md`, `task-N.md`)의 언어를 영어로 고정한다. 지금은 규정이 없어서 대화 언어를 따라 한국어로 나온다.

**근거는 토큰이 아니라 독자다.** 한국어가 토크나이저에서 글자당 2~3배 비싼 건 맞지만, 판단 기준은 누가 읽느냐다:

- **`task-N.md`** — 읽는 건 새 구현 세션(모델)이다. 사람이 훑는 일은 드물다 → **영어**
- **`00-overview.md`** — 같은 독자다. 매 요청마다 캐시 리드로 재청구되므로 크기 영향이 가장 크다 → **영어**
- **결정 원장** — 읽는 건 사용자다. 손가락으로 짚고 "틀렸다"고 말하는 게 목적(`grill-me` §32)이라 **한국어 유지**. 이 태스크의 범위 밖이다
- **스킬 본문·훅 주석** — 사람이 유지보수한다. **한국어 유지**

**기존 플랜 문서는 소급해서 번역하지 않는다.** 과거 산출물이고, 번역하면 그때 무엇이 적혔는지가 바뀐다.

**Files:**
- Modify: `woobin-harness/skills/writing-plans/SKILL.md`
- Modify: `woobin-harness/skills/writing-plans/plan-document-reviewer-prompt.md`
- Modify: `docs/workflow-spec.md` (§3에 규칙 추가)

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (스킬 본문 변경)

---

- [ ] **Step 1: `writing-plans/SKILL.md`에 언어 규칙을 넣는다**

`## Where the Plan Goes` 절의 `**Keep `00-overview.md` under 400 lines / 15,000 characters.**` 문단 **뒤**에 추가한다:

```markdown
### Language

**Write plan documents in English** — both `00-overview.md` and every `task-N.md`.
Their reader is a fresh implementation session, not a person: the overview is
re-billed as a cache read on every request for the rest of that session, and
Korean costs roughly two to three times as many tokens per character.

This applies to the plan documents only. Keep the decision ledger, the
conversation, skill bodies, and hook comments in the language the user is
working in — those have a human reader, and `grill-me` depends on the user
being able to point at a ledger line and say it is wrong.

Quote verbatim strings exactly as they appear in the source, whatever language
they are in: error messages, file contents, commit messages, user-facing copy,
and the exact commands to run. Do not translate them into English — the
implementer has to match them character for character.
```

- [ ] **Step 2: 킥오프 블록 규칙과 충돌하는지 확인한다**

같은 파일 `### The kickoff block` 절에 `Match the user's language.`가 있다. **이건 그대로 둔다** — 킥오프 블록은 사용자가 읽고 복사해서 붙이는 물건이라 독자가 사람이다.

두 규칙이 서로를 부정하지 않도록 킥오프 절의 그 문장을 한 마디만 늘린다:

```
Match the user's language — the kickoff block is read by a person, unlike the plan documents themselves.
```

- [ ] **Step 3: 리뷰어 프롬프트에 반영한다**

`woobin-harness/skills/writing-plans/plan-document-reviewer-prompt.md`를 열어 검사 항목 목록을 찾고, 한 줄을 추가한다:

```
- Plan documents are written in English. Verbatim strings — error messages, file contents, commands, user-facing copy — are quoted in their original language, not translated.
```

기존 항목의 서식(번호 목록인지 불릿인지)을 그대로 따른다.

- [ ] **Step 4: `docs/workflow-spec.md` §3에 규칙을 추가한다**

Task 1이 쓴 규칙 번호의 +1을 쓴다(`grep -n '^### R' docs/workflow-spec.md | tail -3`으로 확인).

```markdown
### R21 플랜 산출물은 영어로 쓴다

**문제** 플랜 문서의 독자는 사람이 아니라 새 구현 세션이다. `00-overview.md`는 그 세션의 **모든**
요청에 캐시 리드로 재청구된다(1,650행 플랜이 48k 토큰으로 측정돼 세션 floor를 93~122k까지 올렸다 —
`home/HARNESS-LOG.md`). 한국어는 토크나이저에서 글자당 2~3배 비싸므로, 같은 내용이 같은 위치에서
반복 청구되는 문서일수록 언어 선택의 누적 비용이 크다.

**기전** `writing-plans`가 `00-overview.md`와 `task-N.md`를 영어로 쓴다. 원문 그대로 인용해야 하는
문자열(에러 메시지, 파일 내용, 실행 명령, 사용자에게 보이는 문구)은 원어 그대로 둔다 — 구현자가
글자 단위로 맞춰야 하는 것들이다.

**대가** 사용자가 플랜 문서를 직접 읽을 때 모국어가 아니다. 그래서 범위를 플랜 문서로 한정한다 —
결정 원장·킥오프 블록·스킬 본문·훅 주석은 사람이 읽으므로 사용자 언어를 유지한다. 특히 원장은
사용자가 한 줄씩 짚어 반증하는 게 존재 이유다(`grill-me` §32).

**무효화 조건** — (1) 한국어 토큰 비용이 영어와 비슷해지면(토크나이저 개선) 근거의 절반이 사라진다.
(2) 사용자가 플랜 문서를 직접 읽고 검토하는 것이 주된 사용 방식이 되면 독자 전제가 뒤집힌다.
(3) 플랜을 분할 저장하는 방식이 바뀌어 overview가 매 요청에 실리지 않게 되면 누적 비용 근거가 없어진다.
```

- [ ] **Step 5: 검증**

Run:
```bash
claude plugin validate ./woobin-harness
grep -n "위에서 논의\|as we discussed" woobin-harness/skills/writing-plans/SKILL.md
```
Expected: validate 통과, grep 출력 없음.

- [ ] **Step 6: 커밋**

```bash
git add woobin-harness/skills/writing-plans docs/workflow-spec.md
git commit -m "feat(writing-plans): 플랜 산출물을 영어로 고정한다"
```
