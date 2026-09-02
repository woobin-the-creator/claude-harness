# 플랜 구현 모드 3종

플랜 문서(`docs/woobin_plan/plans/<name>/`)를 실행할 때 고르는 3가지 형태.
`plan-saved-session-boundary.sh`가 플랜 저장 시 이 파일을 근거로 1개를 추천하고,
구현 세션은 킥오프 프롬프트에 적힌 모드 번호로 이 파일의 해당 절만 읽는다.

## 모든 모드 공통

**무인 실행 여부는 게이트 수가 정한다.**

플랜 문서 리뷰어가 낸 `**Gates:** N`(사람 확인이 필요한 지점의 수)이 라우팅 입력이다.

| 게이트 | 어디로 | 왜 |
|---|---|---|
| 0개 | ①·②b·③ — **full-auto** | 사람이 끼어들 자리가 없으므로 플랜 세션이 그대로 끝까지 굴린다 |
| 1개 이상 | **②a** | 레이어마다 사람이 필요한 모드다. 이미 상주 전제라 게이트가 공짜로 들어맞는다 |
| 1개 이상 **이면서 ③ 성립 조건** | **③ 유지**, 게이트에서 멈춤 | ③의 방아쇠는 되돌리기 비용이고 ②a는 sonnet·medium이다. 게이트 하나 때문에 마이그레이션 플랜을 강등시키지 않는다 |

게이트는 **상주** 문제고 모드는 **model·effort** 문제다. 두 축이 부딪히면 되돌리기 비용이 이긴다.

**서브에이전트는 물을 수 없다.** `AskUserQuestion`이 모든 서브에이전트에서 제거되므로, 게이트에 닿은
구현자는 멈추고 보고하는 것 말고 할 수 있는 게 없다. full-auto에서 그건 중단이 아니라 **정지**다 —
그래서 게이트 있는 플랜을 무인으로 보내지 않는다.

- 오케스트레이터는 **`00-overview.md`만** 읽는다. `task-N.md`는 구현 직전에 하나씩, 또는 서브에이전트에 경로로 넘긴다.
- **effort·model의 소유자는 둘로 갈린다.**
  - **세션** — `claude --effort <level> --model <model>`. ②a와 플랜 세션 자신이 여기다.
    문서상 `--effort`는 "set it for a single session"이라 그 세션에만 적용되고 `settings.json`을 안 건드린다.
    세션 중간에는 바꾸지 않는다: effort 값이 렌더된 프롬프트에 들어가서, 바꾸면 이전 캐시 프리픽스가 통째로 무효화된다.
    (`/effort`는 쓰지 않는다 — interactive 세션에서 `effortLevel`에 **영구 저장**되어 되돌리기를 사람이 기억해야 하고,
     `effortLevel`이 startup에 적용되지 않는 미해결 버그도 있다: anthropics/claude-code#45453.)
  - **위임된 구현자** — 에이전트 정의의 frontmatter. `Agent` 호출에는 **effort 인자가 없어서**
    다른 수단이 없다. full-auto에서는 세션 재런치가 없으므로 상속에 기댈 수도 없다.
    그래서 `Agent(subagent_type: …)`에 **`model`을 넘기지 마라** — 정의가 이미 소유한다.
    `subagent-model-default.sh`도 frontmatter에 `model:`이 있으면 주입하지 않고 빠진다.
- **구현자 프롬프트에 "검증해라 / double-check / 최종 검증 단계"를 넣지 않는다.**
  Opus 5 문서 명시: 그런 지시와 "legacy harness scaffolding that adds separate verification steps"는
  over-verification을 유발하며, 제거하면 품질 손실 없이 토큰이 준다. 모델은 이미 자기 검증을 한다.
- 태스크 단위 서브에이전트 팬아웃은 하지 않는다 — 실측에서 순차 대비 토큰 2.6~5.9배이고 **한 번도 더 빠르지 않았다**.
- 리뷰는 `plan-reviewer` 에이전트(`~/.claude/agents/plan-reviewer.md`, opus + effort low)로 띄운다.
  **세션을 새로 열 필요 없다** — 서브에이전트는 부모의 대화 컨텍스트를 물려받지 않으므로, 구현한 세션 위에서 띄워도
  "코드를 쓴 컨텍스트와 분리된 리뷰어" 조건을 만족한다. `task-N.md` 경로와 diff 범위만 넘기고 diff 본문은 넘기지 않는다.
  (Agent 호출에는 effort 인자가 없다 — effort는 에이전트 정의 frontmatter에서만 지정된다.)

### 중단 대비 — 레이어 경계 커밋 + 리뷰 후 push (R15)

관측된 실패는 컨텍스트 성장이 아니라 **사용량 하드 컷**이다. 그 순간 모델은 도구를 쓸 수 없으므로
방어는 미리 배치돼 있어야 한다. 근거·대가·무효화 조건은 `docs/workflow-spec.md` §3 R15가 소유한다 —
여기는 **절차만** 적는다. 원격이 없는 레포에서는 이 절 전체가 비적용이다.

**구현 첫 턴에 이것부터 한다**

```bash
git switch -c plan/<plan-name>
git add docs/woobin_plan/plans/<plan-name>/
git commit -m "docs(plan): <plan-name> 구현 시작"
git push -u origin plan/<plan-name>
gh pr create --draft --title "<plan-name>" --body "플랜: \`docs/woobin_plan/plans/<plan-name>/\`
진행 상태: \`git log --oneline\`

- [ ] L1 …
- [ ] L2 …
- [ ] 머지 전 플랜 디렉터리 삭제(권장)"
```

- **라벨을 붙이지 마라.** "구현 중"은 **draft 상태 하나**가 나른다. `plan/` 브랜치 접두어가
  "플랜 PR임"을 이미 나르므로 라벨은 파생 가능한 중복 상태다 — 손으로 동기화할 것을 만들지 않는다.
- **PR 본문은 포인터만.** 플랜 내용을 옮겨 적으면 소유자가 둘이 되고 갈라진다(§6-6).
- **예외 하나 — 자동 확정된 결정.** `interview`가 사용자에게 묻지 않고 스스로 확정한 결정과 가정은
  PR 본문에 **직접** 적는다. 포인터 규칙의 취지는 살아 있는 문서의 이중 소유를 막는 것인데, 플랜
  디렉터리는 위 체크리스트대로 머지 전에 지워지므로 그 항목은 머지 후 소유자가 0이 된다. 사용자가
  고른 줄은 옮기지 마라 — 그건 대화에 기록이 있다. 형식은 `interview` §④.
- **열린 draft 플랜 PR은 워크트리당 1개.** 시작 전에 확인한다 — `gh pr list --state open --draft`
  (`plan/`로 시작하는 head 브랜치가 그것이다). 이미 있으면 그것을 먼저 처리한다 —
  목록만 보고 어느 게 살아있는지 판정할 수 없어지면 진입점의 값이 사라진다.
- 플랜 문서를 **커밋한다.** untracked로 두면 새 워크트리에 따라오지 않는다.

**레이어가 끝날 때 — 순서를 지킨다: 커밋 → 리뷰 → (수정) → push**

1. `git add -A && git commit -m "<type>(L<n>): <레이어 요약>"` — **리뷰 전이다.**
   레이어 끝의 리뷰가 그 세션에서 토큰을 가장 많이 쓰는 단계라 하드 컷 확률이 가장 높다.
2. `plan-reviewer` 1회. `task-N.md` **경로**와 `main..HEAD` **범위**만 넘긴다(diff 본문 금지).
3. 지적을 반영하고 `git commit --amend` 또는 fixup 커밋.
4. `git push` + PR 코멘트 **5행 이내**: 이 레이어에서 발견한 것(플랜에 없던 환경 사실, 고친 완료 판정 등).
   **커밋 message body에 쓰지 마라** — squash가 날린다.

**마지막 레이어를 push한 직후 — ready로 전환한다**

```bash
gh pr ready
```

- draft는 **"구현 중"** 표시지 "머지 전" 표시가 아니다. 마지막 레이어가 원격에 올라간 순간 벗긴다.
- 머지까지 미루면 안 되는 이유: 두 소비처(Layer 0 킥오프의 "이미 진행 중인 플랜이 있나" 검사,
  `stale-branch-guard.sh`의 하향 판단)가 `--state open`만 보면 머지 시점엔 자연히 빠지지만,
  **ready인 채로 승인·CI를 기다리는 창은 안 덮인다.** 그 창에서 다른 세션이 이 PR을 "아직 진행 중"으로
  오판하면 워크트리당 1개 불변식에 막혀 새 플랜을 시작하지 못한다. 그래서 두 검사 모두
  `--state open` 위에 **`--draft`를 얹는다** — 이 한 줄이 창을 닫는다.

**머지**

```bash
gh pr merge --squash
```

- `--squash`는 **규칙**이다. 레이어 커밋은 개별로 테스트를 통과하지 않을 수 있어, merge commit으로
  들어가면 main의 `git bisect`가 못 믿을 것이 된다.
- 머지 전 플랜 디렉터리 삭제(`git rm -r docs/woobin_plan/plans/<plan-name>/`)는 **권장**이다.
  squash면 추가·삭제가 상쇄돼 main 히스토리에 blob이 안 들어가고, 브랜치를 지워도 PR의 커밋
  목록에서 플랜 원문을 계속 볼 수 있다. 잊어도 피해는 main 트리의 디렉터리 하나다.

**모드별 차이**

- **②a** — 커밋은 `/clear` **직전**에 한다. git 출력이 한 턴만 살고 버려져서 이후 요청에 재청구되지 않는다.
- **②b** — **커밋은 레이어 구현자(`plan-implementer-*`)가, push는 리뷰를 돌린 오케스트레이터가** 한다.
  이렇게 갈라두면 "리뷰 전에는 원격에 안 올라간다"가 절차가 아니라 **구조**로 보장된다.
  **프롬프트에 커밋을 시키지 마라 — 세 정의의 `## Committing` 절이 이미 소유한다.** 프롬프트로 한 번 더
  말하면 소유자가 둘이 되고, 정의를 고쳐도 옛 문구를 붙여넣는 프롬프트가 남는다(§6-6).
  push는 어느 쪽에도 넣지 않는다.
- **①** — 트랙마다 워크트리이므로 **트랙당 draft PR 1개**다. 워크트리당 1개 불변식이 여기서 자연히 성립한다.
- **full-auto (①·②b·③, 게이트 0개)** — 플랜 세션이 킥오프 블록을 내지 않고 **그대로 이어서 굴린다.**
  1. R15 첫 턴 절차(브랜치 · 플랜 커밋 · push · draft PR)를 플랜 세션에서 그대로 한다.
  2. 레이어마다 그 모드의 구현자를 **순차로** 하나씩 띄운다. `model`을 넘기지 않는다.
  3. 레이어 끝: 커밋(구현자) → `plan-reviewer` → 수정 → push(오케스트레이터).
  4. **그 레이어가 렌더 결과를 바꿨으면 push 전에 `screenshot-verifier`를 1회 띄운다.**
     아무도 화면을 안 본다는 게 full-auto의 정의라, 자동 게이트의 사각지대가 그대로 main까지 간다
     (pholex #235: `.admin-page`가 CSS에 없어 페이지 전체가 브라우저 기본값으로 렌더됐고
      다크 명암비가 1.20:1이었는데 기계 게이트가 styles.css 안쪽만 훑어서 못 잡았다).
  5. 마지막 레이어 push 직후 `gh pr ready`.
  **①에서는 위 "레이어"를 "트랙"으로 읽는다** — ①은 트랙 단위 위임·트랙당 draft PR 1개이므로,
  단계 2~5는 트랙마다 반복하고 5의 `gh pr ready`도 트랙별 PR마다 낸다.
  오케스트레이터는 플래닝 컨텍스트를 안은 채 이 전부를 낸다 — 그게 이 형태의 대가다(§8 O19).

---

## ① 속도 — 토큰 ↑, 퀄리티 유지

```
claude --effort xhigh --model sonnet
```

**성립 조건**: `00-overview.md`의 "태스크 간 순서 의존성"에서 **서로 파일을 공유하지 않는 트랙이 2개 이상** 나올 때만.
트랙이 1개면 이 모드는 ②보다 비싸기만 하다.

- 트랙 단위로만 위임한다(태스크 단위 아님).
  `Agent(subagent_type: "plan-implementer-sonnet-xhigh", isolation: "worktree")` — `model`을 넘기지 않는다.
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
- 레이어마다 `plan-implementer-sonnet-medium`을 **순차로** 하나씩 띄운다(병렬 아님 — 레이어끼리 의존한다).
  `Agent(subagent_type: "plan-implementer-sonnet-medium", prompt: "<overview 경로> + <task-N.md 경로들 순서대로>")`
  — **`model`도 effort도 넘기지 않는다.** 정의가 `sonnet`·`medium`을 소유한다. 넘기면 이름과 실제가 갈린다.
- 세 변이체 정의 모두에 `memory: local`(레포별 지속 메모리, git 미추적)과 `maxTurns: 60`이 걸려 있다.
  memory는 레이어·플랜을 넘는 환경 지식(어떤 러너를 써야 하는지 등)을 쌓기 위한 것이고, 매 스폰마다
  `MEMORY.md` 앞부분이 프롬프트에 실리는 대가가 있다 — 100행을 넘기면 정리한다.
  `maxTurns`는 폭주 방지용 상한이지 튜닝 손잡이가 아니다(**미강제 버그 열려 있음**: anthropics/claude-code#41143).
- 메인 루프는 `00-overview.md`와 각 에이전트의 25행 요약만 안는다. `/clear` 없이도 ~50k를 유지한다.
- 비용은 레이어 수만큼의 프리픽스(각 38~88k). 레이어 2~3개면 감당 범위고, **자리를 안 지켜도 된다**가 대가다.
- ⚠️ 구현자는 **확인 게이트에서 멈추고 보고**한다(정의에 박아둠). 게이트가 있는 플랜은 애초에 ②a로
  라우팅되므로 ②b에서 이걸 보면 리뷰어의 게이트 인벤토리가 틀렸다는 신호다 — 사용자에게 올리고,
  답을 받아 같은 레이어를 이어서 갈 새 구현자를 띄운다.

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

- 구현은 `plan-implementer-opus-xhigh`에 레이어 단위로 위임한다(게이트가 있으면 그 지점에서 멈춘다).
  **`Agent(subagent_type: "woobin-harness:plan-implementer-opus-xhigh")`처럼 플러그인 네임스페이스를 붙여서 호출한다.**
  `subagent-model-default.sh`는 콜론이 없는 이름만 `.claude/agents/<type>.md`에서 frontmatter를 찾는데, 이 정의는
  그 경로가 아니라 플러그인 안에 있어서 못 찾고 `model: sonnet`을 주입해버린다 — opus 고정이 조용히 깨진다.
  네임스페이스가 붙은 이름은 훅이 그 자리에서 건너뛴다(정의 위치를 신뢰할 수 없다는 이유로).
  **max는 쓰지 않는다** — "on some structured-output or less intelligence-sensitive tasks it can lead to overthinking." 플랜 실행이 그 부류다.
- 이 모드의 본체는 구현이 아니라 **구현 후 별도 컨텍스트의 fresh 리뷰어**다. 렌즈를 나눈다:

  `plan-reviewer`를 렌즈별로 3개 띄운다(프롬프트로 렌즈를 지정한다 — 정의는 3축을 다 다루지만 ③에서는 하나씩 깊게 판다):

  | 리뷰어 | 렌즈 |
  |---|---|
  | 1 | 정확성·버그만 |
  | 2 | `task-N.md`의 완료 판정 ↔ 실제 구현 1:1 대조만 |
  | 3 | repo 표준(CLAUDE.md·기존 패턴)만 |

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
