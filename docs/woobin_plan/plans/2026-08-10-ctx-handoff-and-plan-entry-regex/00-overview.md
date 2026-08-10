# 컨텍스트 자동 핸드오프 + 플랜 진입 가드 정규식 수정 — Overview

> 오케스트레이터는 **이 파일만** 읽는다. 태스크 본문(`task-N.md`)은 구현 직전에 하나씩 읽거나 서브에이전트에 경로로 넘긴다.

**Goal:** 컨텍스트가 300k를 넘긴 채로 계속 도는 세션을 턴 종료 시점에 잡아 핸드오프 문서를 만들게 하고, 플랜 진입 가드가 어구 변형("플랜 **문서** 작성하자")에 조용히 죽는 구멍을 막는다.

**Architecture:** 훅 1개 신설(`ctx-handoff-stop.sh`, Stop 이벤트) + 기존 훅 1개의 트리거 정규식 확장. 신설 훅은 `idle-handoff-stop.sh`의 "깨워서 대체 경로를 만들어 준다" 형태를 따르되, asyncRewake·폴링 루프 없이 턴 종료 시점에 즉시 판정하고 재주입 방지는 세션 1회 마커 + `stop_hook_active`로 한다.

**Tech Stack:** POSIX sh (bash 3.2 호환), `jq`, Claude Code 훅 프로토콜(Stop `exit 2` / UserPromptSubmit `additionalContext`).

---

## Global Constraints

모든 태스크의 요구사항에 암묵적으로 포함된다.

- **정본은 `woobin-harness/` 안이다.** `~/.claude/`에 사본을 만들지 않는다.
- 셸은 `sh` + bash 3.2 호환. `[[ ]]`, 배열, `declare -A` 금지.
- 훅은 `jq`가 없으면 조용히 `exit 0`한다(기존 훅 전부 이 패턴).
- 임계값은 전부 환경변수로 조정 가능해야 하고, 기본값을 `docs/workflow-spec.md` §4 "조정 손잡이" 블록에 등재한다.
- 무엇이든 수정한 뒤 `woobin-harness/.claude-plugin/plugin.json`의 `version`을 올린다. 이번 버전: `1.1.0` → `1.2.0`.
- 새 규칙을 `docs/workflow-spec.md` §3에 신설하면 **`무효화 조건`을 반드시 채운다**. 못 채우면 아직 규칙이 아니다.
- `claude plugin validate ./woobin-harness`를 건너뛰지 않는다 — YAML frontmatter 파싱 실패는 이 명령만 잡는다.

---

## 태스크 목록과 순서 의존성

**의존 그래프: `Task 1` ∥ `Task 2` → `Task 3` → `Task 4` → `Task 5`**

- Task 1과 Task 2는 **공유하는 파일이 없다**(독립).
- Task 3(훅)은 Task 2(스킬)를 이름으로 부르므로 스킬이 먼저 있어야 한다.
- Task 4(검사기)는 Task 3까지의 산출물을 인벤토리에서 찾아야 하므로 그 뒤다.
- Task 5는 앞 넷의 산출물 이름을 문서로 옮기고, **마지막 스텝에서 Task 4의 검사기로 스스로를 검증한다**.

| # | 제목 | 대상 파일 | 완료 판정 명령 |
|---|---|---|---|
| 1 | 플랜 진입 가드 정규식 확장 | `woobin-harness/hooks/plan-session-boundary-guard.sh` (33행) | `sh /tmp/t1.sh` → `MATCH:` 3개, `ok       :` 2개, `MISS`·`FALSE-POS` 0개 |
| 2 | `handoff` 스킬 신설 | `woobin-harness/skills/handoff/SKILL.md` (신설) | `claude plugin validate ./woobin-harness` 통과<br>`head -3 woobin-harness/skills/handoff/SKILL.md` → `name: handoff` |
| 3 | 컨텍스트 자동 핸드오프 훅 신설 | `woobin-harness/hooks/ctx-handoff-stop.sh` (신설)<br>`woobin-harness/hooks/hooks.json`<br>`woobin-harness/hooks/idle-handoff-stop.sh` (주석만) | `sh /tmp/t2.sh` → `ok  :` 6줄, `FAIL` 0개<br>`jq -e '.hooks.Stop \| length == 3' woobin-harness/hooks/hooks.json`<br>`claude plugin validate ./woobin-harness` |
| 4 | 문서 동기화 검사기 + 가드 훅 | `scripts/check-harness-docs.sh` (신설)<br>`woobin-harness/hooks/harness-doc-sync-guard.sh` (신설)<br>`woobin-harness/hooks/hooks.json` | `sh scripts/check-harness-docs.sh` → 현재 드리프트(스킬 개수)를 잡고 `exit=1`<br>가드 훅 단독 실행 → 검사 결과 주입, 두 번째 호출은 빈 출력 |
| 5 | 문서·메타데이터 동기화 | `docs/workflow-spec.md`<br>`docs/workflow.html`<br>`README.md` (29·31행)<br>`woobin-harness/.claude-plugin/plugin.json` (3·4행)<br>`.claude-plugin/marketplace.json` (11행)<br>`home/HARNESS-LOG.md` | **`sh scripts/check-harness-docs.sh` → `✗` 0개, `exit=0`** (이 플랜의 최종 게이트)<br>`grep -c "유일한 세션 경계" docs/workflow.html` → `0` |

**문서 4종 규정**(CLAUDE.md): README · `docs/workflow.html`(사람용) · `docs/workflow-spec.md`(모델 재검토용) · 훅 헤더 주석. Task 5가 앞의 셋을, Task 1~4가 훅 헤더를 담당한다. `docs/scores/`(역량 채점 이력)는 이번 변경과 무관하다.

**Task 4가 있는 이유 — 이 규정이 이미 두 번 실패했다.** 규정은 `CLAUDE.md`에 산문으로 **이미 있었는데**, ① 이 플랜을 쓰면서 `docs/workflow.html`이 빠졌고(사용자가 물어봐서 발견) ② 같은 시점에 `workflow-spec.md`의 스킬 개수가 41개(실제 42개)로 이미 갈라져 있었다. 규율 2 — *"소프트 지시로 못 막는 건 구조를 바꾼다"* — 에 따라 체크리스트를 하나 더 쓰지 않고 **개수·인벤토리·동반 수정 판정을 스크립트로 옮긴다.** R12(`stop-warning-ack-guard.sh`)가 만든 "실제로 검사하는 결정론적 게이트" 패턴의 두 번째 적용이고, R12 무효화 조건에 적힌 "이 패턴은 다른 훅에도 적용 가능한데 안 쓰고 있다"가 이걸로 해소된다.

Task 5의 마지막 스텝은 설치본 반영(`claude plugin marketplace update` → `claude plugin update woobin-harness@woobin-harness` → 재시작)이다. **버전을 안 올리면 레포를 고쳐도 설치본은 옛날 그대로다.**

**개수 변화:** 훅 9→**11**개(`ctx-handoff-stop.sh` + `harness-doc-sync-guard.sh`), 스킬 42→43개(`handoff`), 에이전트 4개 유지.

---

## 측정 근거와 예상 절감

전부 2026-08-10, `waste_scan.py --days 7` 전수(412세션 / $852.97) 기준. **A/B 이전 수치이므로 라벨을 그대로 유지할 것** — 검증 없이 절감률을 단정하지 않는다.

| 항목 | 측정된 모수 | 절감 상한 | 라벨 |
|---|---|---:|---|
| **Task 2 (R13)** 300k 핸드오프 | 300k 돌파 후에도 요청이 이어진 세션 **10건** | **$88.47 / 7일** | 상한. "돌파 직후 전원이 45k floor로 재시작"을 가정 |
| Task 2 현실 추정 | 위의 40~60% | **$35~53 / 7일** | 추정. R1의 교훈(문서가 자기완결적이지 않으면 새 세션이 되묻느라 절약분이 날아감)을 반영해 할인 |
| **Task 1** 진입 가드 정규식 | 7일간 플랜 진입 3건 중 **1건 미발화** | **$3.6 / 7일** | 상한. 미발화 구간 $7.22를 45k floor에서 돌렸을 때 차액 |

상한 산출 방식(재현 가능): 세션별로 ctx가 300k를 처음 넘은 요청 이후의 모든 요청에 대해 `(ctx − 45,000) × 0.1 × 모델별 input단가`를 합산. `0.1`은 cache read 배수.

상위 기여 세션: `ba72fbd2` $17.32(이후 107req, max 430k) / `1a0a81a5` $13.61 / `c1d660bd` $12.62(max 472k) / `e5508448` $11.53 / `c6917d2f` $11.03.

**주간 총지출 $852.97 대비 Task 2의 상한은 10.4%다.** 이보다 크게 보고하는 계산은 200k 초과분($59.70)이나 다른 모수를 섞은 것이니 의심할 것.

---

## 기각한 대안

이 절이 없으면 다음 세션이 같은 걸 다시 제안한다.

| 대안 | 기각 이유 |
|---|---|
| **`waste_scan.py`에 달러 환산 추가** | 이미 있다. 30행에 캐시 배수 주석, 175행에 요청별 비용, `requestId` dedup·모델별 단가·agent별 귀속까지 구현돼 있다. 외부 재분석이 요구한 게 전부 구현된 상태였다 |
| **새 분석기(`analyze-sessions.py`) 작성** | 같은 워크플로를 서술하는 소유자가 셋이 된다(CLAUDE.md "요약본을 하나 더 만들지 마라") |
| **`sdd-orchestrator-edit-guard.sh` `[B]` 카운터를 플랜 문서 포함으로 확대** | 7일 전수에서 ctx ≥150k 세션 41건 중 21건은 현행 카운터로도 임계 도달, 플랜 문서를 포함시켜야 달라지는 건 **2건뿐**. 정당한 플랜 세션마다 deny가 뜨는 오탐 비용이 더 크다. `workflow-spec.md` §8에 기록만 |
| **`[B]` 임계값 하향(15→8)** | 근거가 실측이 아니라 감이다. 현행 21/41이 이미 발화 가능 |
| **300k 개입을 UserPromptSubmit 소프트 주입으로** | HARNESS-LOG #3이 실패를 이미 실측했다(ctx 경고 도입 후에도 351k 세션 발생). 같은 급을 하나 더 놓는 셈 |
| **300k 개입을 UserPromptSubmit block(토큰 0)으로** | 강제력·비용은 최선이지만 핸드오프 산출물을 안 만들어 준다 → 사용자가 그냥 재시도할 확률이 크고, R1의 "자기완결적이지 않으면 절약분이 날아간다"가 그대로 적용. **단, 재측정에서 `/clear` 전환율이 낮으면 이쪽으로 올린다**(R13 무효화 조건에 명시) |
| **`plan-exec-modes.md`에 "플랜 작성 세션" 모드 신설** | 규칙 신설은 무효화 조건을 요구하는데 실측 1건으로는 약하다. 진입 가드 훅 메시지가 이미 같은 내용(인터뷰가 아니라 탐색이 비싸다 + Explore 위임)을 담고 있다 |
| **넓은 의미 탐지 정규식** (`(플랜\|계획)[^\n]{0,10}?(작성\|짜\|쓰\|만들…)`) | 7일 전수에서 오탐 2/5(과거 대화 인용, "작업계획대로 진행되면"). 어구 목록 유지 + 삽입 8자 허용이 정확도가 높다 |
| **절감액을 200k 초과 유지비($59.70)로 보고** | 개입은 300k에서 트리거되므로 모수가 다르다. 300k 기준으로 다시 계산해 $88.47을 썼다 |
| **A/B 실험으로 절감률 검증** | 며칠 걸리고 같은 성격의 세션 쌍이 필요하다. 이번 규모에 과하다고 판단 — 대신 모든 수치에 "상한/추정/미검증" 라벨을 달았다 |
| **공개 `handoff` 스킬 설치** ([ykdojo](https://github.com/ykdojo/claude-code-tips/blob/main/skills/handoff/SKILL.md) / [thepushkarp](https://github.com/thepushkarp/handoff) / [REMvisual](https://github.com/REMvisual/claude-handoff)) | 셋 다 저장 경로가 **레포 안에 고정**이고 파라미터화되지 않는다(`HANDOFF.md` 루트 / `docs/handoff/` / `plans/handoffs/`). 우리 훅은 `~/.claude/idle-handoffs/<sid>.md`를 지정한다 — git 미추적이어야 하고 세션 id로 매핑돼야 한다. 섹션 설계는 REMvisual이 가장 근접해(기각안 필수) 그 구성을 참고했다 |
| **`idle-handoff-stop.sh`의 `handoff 스킬` 참조를 삭제** | 처음 방향이었으나 뒤집었다. 훅이 2개가 되면 문서 계약을 두 곳이 소유하게 되고, 그게 #16의 사고 구조 그대로다. 참조를 지우는 대신 **스킬 실체를 만들어** 단일 소유로 간다 |
| **문서 계약을 훅 메시지에 인라인** | 위와 같은 이유. `ctx-handoff-stop.sh`와 `idle-handoff-stop.sh`가 각자 "문서에 넣을 항목"을 갖게 되면 한쪽만 고쳐져 갈라진다 |
| **문서 누락 방지를 `CLAUDE.md`에 체크리스트로 더 쓰기** | 거기 **이미 있다**("고칠 때 같이 고쳐야 하는 것" 4종). 있는 상태로 두 번 실패했다 — 같은 수단을 더 쓰는 건 규율 2 위반이다 |
| **`writing-plans` 스킬에 "문서 4종 확인" 스텝 추가** | 같은 이유로 소프트. 게다가 이 실패는 플랜 작성뿐 아니라 직접 훅을 고칠 때도 난다 — 스킬은 그 경로를 못 덮는다 |
| **git pre-commit 훅으로 강제** | 플랜이 태스크별로 커밋을 나누는 구조라(문서는 Task 5 한 커밋) 중간 커밋마다 실패한다. 오탐이 쌓이면 `--no-verify`가 습관이 된다. PostToolUse 알림 + Task 5의 게이트가 같은 효과를 오탐 없이 낸다 |
| **모든 훅 수정에 `workflow.html` 갱신을 강제** | 내용만 고치는 수정(Task 1의 정규식)은 사람용 요약을 안 바꾼다. 전부 실패로 잡으면 오탐이 쌓여 무시당한다 — **추가는 실패, 수정은 경고**로 나눴다 |

---

## 전제 (틀리면 이 플랜이 흔들린다)

- 임계 300k는 `statusline/ctx-warn-statusline.sh`의 `CTX_DANGER_THRESHOLD` 기본값과 같게 맞춘 것이다. 한쪽만 바꾸면 두 곳이 다른 숫자를 말한다.
- 핸드오프 문서 경로는 기존 `~/.claude/idle-handoffs/`를 재사용한다. 새 디렉터리를 만들지 않는다.
- 절감 수치는 전부 7일 전수 1회 기준의 **상한**이며 A/B 이전이다.
- `handoff` 스킬은 존재하지 않는다(2026-08-10 확인 — 플러그인·`~/.claude/skills/` 양쪽). 새 훅은 스킬을 부르지 않고 문서 계약을 메시지에 직접 박는다.
