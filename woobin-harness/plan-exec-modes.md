# 플랜 구현 모드 3종

플랜 문서(`docs/woobin_plan/plans/<name>/`)를 실행할 때 고르는 3가지 형태.
`plan-saved-session-boundary.sh`가 플랜 저장 시 이 파일을 근거로 1개를 추천하고,
구현 세션은 킥오프 프롬프트에 적힌 모드 번호로 이 파일의 해당 절만 읽는다.

## 모든 모드 공통

- 오케스트레이터는 **`00-overview.md`만** 읽는다. `task-N.md`는 구현 직전에 하나씩, 또는 서브에이전트에 경로로 넘긴다.
- **effort·model은 런치 플래그로 정한다** — `claude --effort <level> --model <model>`.
  문서상 `--effort`는 "set it for a single session"이라 그 세션에만 적용되고 `settings.json`을 건드리지 않는다.
  세션 중간에는 바꾸지 않는다: effort 값이 렌더된 프롬프트에 들어가서, 바꾸면 이전 캐시 프리픽스가 통째로 무효화된다.
  (`/effort`는 쓰지 않는다 — interactive 세션에서 `effortLevel`에 **영구 저장**되어 되돌리기를 사람이 기억해야 하고,
   `effortLevel`이 startup에 적용되지 않는 미해결 버그도 있다: anthropics/claude-code#45453.)
- **구현자 프롬프트에 "검증해라 / double-check / 최종 검증 단계"를 넣지 않는다.**
  Opus 5 문서 명시: 그런 지시와 "legacy harness scaffolding that adds separate verification steps"는
  over-verification을 유발하며, 제거하면 품질 손실 없이 토큰이 준다. 모델은 이미 자기 검증을 한다.
- 태스크 단위 서브에이전트 팬아웃은 하지 않는다 — 실측에서 순차 대비 토큰 2.6~5.9배이고 **한 번도 더 빠르지 않았다**.
- 리뷰는 `plan-reviewer` 에이전트(`~/.claude/agents/plan-reviewer.md`, opus + effort low)로 띄운다.
  **세션을 새로 열 필요 없다** — 서브에이전트는 부모의 대화 컨텍스트를 물려받지 않으므로, 구현한 세션 위에서 띄워도
  "코드를 쓴 컨텍스트와 분리된 리뷰어" 조건을 만족한다. `task-N.md` 경로와 diff 범위만 넘기고 diff 본문은 넘기지 않는다.
  (Agent 호출에는 effort 인자가 없다 — effort는 에이전트 정의 frontmatter에서만 지정된다.)

---

## ① 속도 — 토큰 ↑, 퀄리티 유지

```
claude --effort xhigh --model sonnet
```

**성립 조건**: `00-overview.md`의 "태스크 간 순서 의존성"에서 **서로 파일을 공유하지 않는 트랙이 2개 이상** 나올 때만.
트랙이 1개면 이 모드는 ②보다 비싸기만 하다.

- 트랙 단위로만 위임한다(태스크 단위 아님). `Agent(isolation: "worktree", model: "sonnet")`.
- **스폰을 동시에 하지 않는다.** 첫 트랙이 첫 응답을 낼 때까지 기다린 뒤 다음을 띄운다 —
  콜드 프리픽스에 병렬 스폰이 겹치면 캐시 리드 0으로 전체 프리픽스를 재기록한다(실측 52,022토큰 1건).
- 속도의 실제 출처는 병렬이 아니라 **사용자 왕복 제거**다. 태스크마다 확인받지 말고 레이어 단위로 끊는다.
  Opus 5 문서: "performs best when given the complete task specification up front and left to run."
- 리뷰: 트랙이 끝날 때마다 배치 1회.

## ② 절약 — 토큰 최소, 퀄리티 유지 (기본값)

```
claude --effort medium --model sonnet
```

**성립 조건**: 태스크가 의존성 체인이거나 같은 파일을 공유해 병렬이 금지될 때. **대부분의 플랜이 여기다.**

레이어 경계에서 컨텍스트를 어떻게 끊을지 두 갈래가 있다. **사용자에게 물어서 고른다.**

**②a 수동 `/clear` — 가장 쌈, 자리를 지켜야 함**
- 서브에이전트 0개. 메인 루프가 `task-N.md`를 하나씩 읽고 순차 구현한다.
- 레이어가 끝날 때마다 `/clear` → `00-overview.md`만 다시 읽고(4k) 다음 레이어. 재진입 floor ~50k.
- 컨텍스트를 **버리는** 것이라 추가 비용이 0이다. 대신 레이어마다 사용자 입력이 필요하다.

**②b 레이어 위임 — 끝까지 자동, 레이어당 프리픽스 1회**
- 레이어마다 `plan-implementer`를 **순차로** 하나씩 띄운다(병렬 아님 — 레이어끼리 의존한다).
  `Agent(subagent_type: "plan-implementer", model: "sonnet", prompt: "<overview 경로> + <task-N.md 경로들 순서대로>")`
  — **`model`을 반드시 명시한다.** 이 정의엔 model frontmatter가 없어서 생략하면 훅이 sonnet을 주입한다(②에선 맞지만 ③에선 틀리다).
  effort는 정의에 없으므로 **세션 effort를 상속**한다 — 그래서 모드의 effort가 그대로 적용된다.
- 정의에 `memory: local`(레포별 지속 메모리, git 미추적)과 `maxTurns: 60`이 걸려 있다.
  memory는 레이어·플랜을 넘는 환경 지식(어떤 러너를 써야 하는지 등)을 쌓기 위한 것이고, 매 스폰마다
  `MEMORY.md` 앞부분이 프롬프트에 실리는 대가가 있다 — 100행을 넘기면 정리한다.
  `maxTurns`는 폭주 방지용 상한이지 튜닝 손잡이가 아니다(**미강제 버그 열려 있음**: anthropics/claude-code#41143).
- 메인 루프는 `00-overview.md`와 각 에이전트의 25행 요약만 안는다. `/clear` 없이도 ~50k를 유지한다.
- 비용은 레이어 수만큼의 프리픽스(각 38~88k). 레이어 2~3개면 감당 범위고, **자리를 안 지켜도 된다**가 대가다.
- ⚠️ `plan-implementer`는 **확인 게이트에서 멈추고 보고**한다(정의에 박아둠). 그때 메인 루프가 사용자에게 묻고,
  답을 받아 같은 레이어를 이어서 갈 새 에이전트를 띄운다. 게이트가 많은 플랜이면 ②a가 낫다.

**어느 쪽인가**: 레이어 3개 이상이거나 자리를 비울 거면 ②b, 게이트가 잦거나 비용을 최소화할 거면 ②a.
로컬 실측에서 비용의 72%가 자라난 컨텍스트를 다시 읽은 cache read였고(`94aff112` $29.1/$40.55),
**둘 다 그걸 막는다** — 차이는 "버리느냐 복제하느냐"뿐이다.

**②a·②b 공통**
- medium으로 퀄리티가 유지되는 근거: Sonnet 5 @ medium ≈ Sonnet 4.6 @ high.
  그리고 "at low and medium, the model scopes its work to what was asked rather than going above and beyond" —
  완결적인 `task-N.md`를 실행할 때는 이게 금도금 방지로 작동한다.
- 얕은 추론이 보이면 프롬프트로 우회하지 말고 effort를 올린다(문서 명시). 단 세션 중간이 아니라 다음 세션에서.
- 리뷰: 전부 끝난 뒤 **레이어별 배치 1회**, `plan-reviewer` 1개. 근거:
  "Accuracy holds at lower effort settings, which supports a fast pass at review time."

## ③ 최고 퀄리티 — 토큰 ↑↑

```
claude --effort xhigh --model opus
```

**성립 조건**: 되돌리기 비싼 작업 — DB 마이그레이션, 사내 prod 배포에 닿는 변경, 자동 게이트가 못 잡는 UI.

- 구현은 메인 루프에서 Opus 5 @ xhigh. **max는 쓰지 않는다** —
  "on some structured-output or less intelligence-sensitive tasks it can lead to overthinking." 플랜 실행이 그 부류다.
- 이 모드의 본체는 구현이 아니라 **구현 후 별도 컨텍스트의 fresh 리뷰어**다. 렌즈를 나눈다:

  `plan-reviewer`를 렌즈별로 3개 띄운다(프롬프트로 렌즈를 지정한다 — 정의는 3축을 다 다루지만 ③에서는 하나씩 깊게 판다):

  | 리뷰어 | 렌즈 |
  |---|---|
  | 1 | 정확성·버그만 |
  | 2 | `task-N.md`의 완료 판정 ↔ 실제 구현 1:1 대조만 |
  | 3 | repo 표준(CLAUDE.md·기존 패턴)만 — 로컬 `review` 스킬이 이 축을 가짐 |

  **동시에 띄우지 않는다.** 셋 다 opus라 부모(sonnet 세션)와 캐시가 갈리고, 콜드 프리픽스에 동시 스폰이 겹치면
  각자 전체 프리픽스를 재기록한다. 첫 리뷰어가 응답을 낸 뒤 나머지를 띄운다.

- **리뷰 프롬프트에 "심각한 것만 보고해"를 넣지 않는다.** 문서 경고: 그러면 모델이 리터럴하게 따라서 덜 보고한다.
  "ask it to report everything and filter in a separate pass instead."
- 구현자에게는 여전히 검증을 지시하지 않는다(공통 규칙). 검증은 별도 컨텍스트의 몫이다.

---

## 근거

- [Effort — Claude Platform Docs](https://platform.claude.com/docs/en/build-with-claude/effort)
- [Prompting Claude Sonnet 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5)
- [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5)
- [The Subagent Tax — Systima, 2026-07-22](https://systima.ai/blog/subagent-tax) — Opus 5 매칭 실측: 순차 295k/4m15s, 2에이전트 762k/8m, 5에이전트 945k/4m45s
- `~/.claude/HARNESS-LOG.md` #9(리뷰 배치), #10(컨텍스트 성장이 비용의 72%), #12(SDD $2.57 vs 메인+sonnet $2.82/태스크)
