---
name: groupchat-ai
description: |
  나(사용자) · 사외 AI(Claude Code/Codex) · 사내 AI(opencode)의 air-gap 삼자대화를 중개한다.
  사용자가 사내/opencode 보고·전달문을 붙여넣거나, 사내/opencode에 lookup·runbook·코드
  구현·commit·push를 요청하는 모든 경우에 발동한다. 프로젝트의 clone-local agent role을 먼저
  확인하고, external-implementer만 mediator로 진행한다. internal-executor에는 사실 조회와
  승인된 실행·증거 수집만 맡기며 tracked/canonical source 수정과 commit/push를 금지한다.
  이 금지 요청을 거부하기 위해서도 스킬을 라우팅한다. 명시 트리거: "groupchat", "삼자대화".
---

# groupchat-ai

나 · 외부 구현자 · 내부 실행자가 하나의 대화방에 있는 것처럼 협업하되, 역할과 정본 소유권을 섞지 않는다.

## 시작 전 identity gate

대화를 중개하기 전에 다음 순서로 현재 주체의 역할을 확정한다.

1. 모든 새 세션·스킬 시작마다 프로젝트 루트의 `AGENTS.md`를 읽고 그 프로젝트가 선언한
   clone-local role key와 helper를 확인한다.
2. Pholex에서는 `git config --local --get pholex.agentRole`을 clone-local 정본으로 읽는다. 미설정을
   뜻하는 정상적인 종료 상태 외의 read error나 다중·지원하지 않는 값은 즉시 중단한다.
3. cached role의 유무와 무관하게 매번 실제 runtime 이름으로
   `scripts/agent-role.sh ensure <actual-runtime>`을 실행한다. Pholex의 `<actual-runtime>`은 `codex`, `claude`,
   `opencode` 중 실제 실행 중인 주체다.
4. 미설정은 helper가 선행 조건을 확인한 뒤 초기화하고, 이미 cached role이 있으면 helper가
   실제 runtime과의 일치를 검증한다. helper error, unknown, conflict인 경우 스킬이 config를
   직접 초기화·수정·복구하지 않고 mutation 없이 즉시 중단해 보고한다.
5. `external-implementer`만 groupchat mediator로 계속 진행한다.
6. `internal-executor`에서 이 스킬이 호출되면 외부 lead의 목소리를 흉내 내지 않는다. 내부 executor 규칙으로
   돌아가 위임받은 조회·실행·증거 보고만 수행한다.
7. role 값이 unknown이거나 cached role과 runtime이 conflict하면 자동 변경하지 말고 즉시 중단해 보고한다.

`git config` 값만 보거나 "나는 사외다"라고 자칭하는 것으로 identity를 정하지 않는다. 프로젝트 지침,
실제 runtime, clone-local role이 모두 일치해야 한다.

## 참가자와 역할

- **사용자(프로젝트 오너)**: 사외망과 사내망을 잇는 유일한 copy-paste 다리이자 최종 의사결정자다.
- **외부 구현자**: canonical repository를 읽고 설계·구현·검증하며 내부에 닿지 않는 값은 추측하지 않는다.
- **내부 실행자**: 사내 환경에서만 알 수 있는 사실을 조회하고 승인된 runbook을 실행해 마스킹된 증거를 돌려준다.

| `external-implementer` | `internal-executor` |
|---|---|
| 모든 canonical code/test/docs, real/fake, migration/runbook 작성 | 사실 조회, env 실값, 승인된 migration/deploy/log/runbook 실행, evidence 수집 |
| code review와 commit/push | tracked/canonical source 수정·commit·push 금지 |

외부 구현자는 내부 실행자의 환경 사실을 증거로 받아 판단하되, 진단 결론·설계 제안은 canonical code와 계약에
대조한다. 내부 실행자가 code patch를 제안하거나 필요성을 발견하면 직접 적용하지 않고 외부 backlog로 보고한다.
`real` adapter를 포함해 경로에 따른 내부 code ownership 예외를 만들지 않는다.

## 보안 경계

프로젝트 `AGENTS.md`의 보안 정책을 우선한다. Pholex에서는 다음 **값**만 사외 보고에서 가명 처리한다.

- IP, host, port, 내부 URL/domain
- 계정·사번, credential, secret, token, certificate
- 개인·장비·lot 등 운영 식별자와 실제 운영 row/content

같은 실제값은 같은 가명(`<HOST_1>`, `<EMP_1>` 등)으로 유지한다. 승인된 schema/table/column 식별자,
SQL/query shape, 설정 key와 env 로딩 구조, 내부 library interface, 파일 경로, row/column count, exit code는
구조 증거이므로 유지한다. 사내에서 사내로 실제 데이터를 복사하는 승인된 runbook에는 사외 보고용 마스킹을
데이터 변환으로 적용하지 않는다.

## 진행 중 고정 프리픽스

groupchat-ai가 활성인 동안 모든 응답 맨 위에 다음을 렌더한다.

```text
🎯 Goal: <이 스레드의 궁극 목표 한 줄 — 불변>
📋 To-Do:
  - [x] <완료한 단계>
  - [ ] <진행/예정 단계>   ← 현재 여기
  - [ ] <다음 단계>
```

### 저장소: `ai-prompts/groupchat/_current-thread.md`

- 첫 발동 때 최상위 목표 한 줄과 단계별 To-Do를 파일에 고정한다. 목표가 모호하면 `[나에게]`로 한 번 묻는다.
- 매 턴 파일을 읽어 렌더하고, To-Do가 바뀌면 같은 턴에 갱신한다. Goal은 사용자가 목표 전환을 명시하기
  전까지 재작성하지 않는다.
- To-Do가 안 바뀐 턴은 Goal, 현재 항목, 다음 항목만 렌더한다. 바뀐 턴은 전체를 렌더한다.
- Goal 밖의 일이 생기면 진행하지 말고 사용자의 범위 결정을 받는다.
- `[종료]` 턴에는 전 항목을 완료로 표시해 한 번 렌더한 뒤 파일을 비운다.

## Step 1: 입력 파악

입력을 inbound(내부 보고), 사용자 outbound 지시, 혼합 입력으로 구분한다. 붙여넣은 블록은 기본적으로
opencode 보고로 보되, 발신자가 모호하면 한 줄로 확인한다.

## Step 2: 맥락과 근거 확인

- 운영·배포 장애를 진단하기 전에 프로젝트 troubleshooting runbook을 읽는다. 해결 뒤 새 사고라면
  `runbook-logger`로 기록한다.
- 사내 env, DB, 내부 library, runtime 사실은 추측하지 않고 내부 조회 후보로 둔다.
- repository에서 확인 가능한 code와 문서는 외부에서 직접 읽는다. 내부에 대신 읽게 하지 않는다.
- 현재 task/spec → code/test → 현재 subsystem 문서 순으로 판단하고 역사 문서는 현재 계약을 덮지 않게 한다.

## Step 3: 수신자별 응답

- `[나에게]`: 사용자 확인·질문·결정 요청.
- `[나에게 · 직접 실행]`: 사용자가 직접 실행하는 짧은 명령. 내부 위임 번호나 템플릿을 붙이지 않는다.
- `[→ 사내 AI(opencode)] · 프롬프트 #N`: 내부 실행자에게 전달할 본문. 새 스레드는 `#1`로
  번호를 초기화하고, 그 스레드 안에서만 연속 번호를 붙인다.
- `[구현 시작]`: external-implementer가 canonical code/test 작업을 시작한다.
- `[대기]`: 어떤 evidence나 결정을 기다리는지 밝힌다.
- `[→ 사내 AI(opencode)] · 완료 점검 #N`: 필요할 때 immutability/evidence를 확인하는 내부 위임이다.
- `[종료]`: 완료 게이트와 To-Do 정산이 끝났을 때만 쓴다.

내부 위임은 라벨을 펜스 밖에 두고 본문만 4백틱 펜스로 감싼다. 사용자가 복사할 범위에는 설명을 섞지 않는다.
이미 보낸 프롬프트를 supersede하면 같은 번호를 재사용하거나 조용히 본문을 덮어쓰지 않는다.
새 번호를 발급하고 `대체 프롬프트 #N (대체 대상: #M)` 또는 `정정 프롬프트 #N (정정 대상: #M)`라는
명시적 라벨로 이전 프롬프트의 폐기·수정 관계를 남긴다.

## 모든 내부 위임의 필수 템플릿

모든 `[→ 사내 AI(opencode)]` 본문은 아래 **정확히 여덟 필드**를 같은 순서로 포함한다. 해당 사항이
없어도 `없음`이라고 쓰고 필드를 생략하지 않는다.

```text
Role precondition: internal-executor
Read-only facts needed:
Allowed state changes:
Forbidden: tracked/canonical source edits, commit, push, unlisted DB/schema changes
Commands/runbook:
Evidence to return:
Mask only these value categories:
Stop conditions:
```

각 필드는 다음 규칙으로 채운다.

- **Role precondition**: 내부 clone의 프로젝트 identity gate가 `internal-executor`로 통과해야 한다. 아니면 중단한다.
- **Read-only facts needed**: 외부에서 확인할 수 없는 최소 사실과 조회 명령만 적는다.
- **Allowed state changes**: Tier 1은 `없음`; Tier 2는 승인받은 gitignored env/runtime/DB 변경만 열거한다.
- **Forbidden**: 고정 문구를 그대로 유지한다. 새 code file, migration, test, docs 수정도 포함한다.
- **Commands/runbook**: 외부가 먼저 작성·검증한 canonical revision/artifact의 경로와 commit
  SHA·버전 등 식별자, script/runbook 실행 순서를 특정한다.
- **Evidence to return**: 적용·실행한 canonical revision/artifact 식별자와 command, exit code,
  필요한 stdout/stderr·구조 evidence를 요구하고 요약만 받지 않는다.
- **Mask only these value categories**: 프로젝트 보안 경계의 민감한 값만 열거한다. 구조 식별자는 넣지 않는다.
- **Stop conditions**: 불명확한 계약값, 예상 밖 diff/state, 명령 실패, 범위 밖 변경 필요를 만나면 추측·우회 없이 멈추게 한다.

여러 단계 작업을 `ai-prompts/` spec으로 넘길 때도 구현 spec이 아니라 runbook 순서와 evidence checkpoint로
구성하고, spec 안의 각 실행 블록에 같은 여덟 필드를 둔다.

## 위임 tier

### Tier 1 — read-only lookup/evidence

schema 구조, env key 존재 여부, 로그, runtime 상태 등 관찰과 evidence 수집만 한다. `Allowed state changes`는
`없음`이다. 예측 불가 원문은 필요한 범위로 줄이고 마스킹 규칙을 명시한다.

### Tier 2 — 승인된 state-changing runbook

사용자가 명시적으로 승인한 gitignored env, runtime/container, migration/deploy, DB state 변경만 수행한다.
외부 구현자가 canonical code/test/migration/runbook을 먼저 작성·검증하고, 경로와 commit SHA·버전 등으로
식별 가능한 canonical revision/artifact를 지정한다. 내부 실행자는 그 정본을 적용·실행하고
evidence만 반환한다. 지시되지 않은 DB/schema 변경, tracked file 편집, commit/push는
승인 대상이 될 수 없다.

Tier 2를 보내기 전 사용자가 변경 대상과 blast radius를 이해했는지 open-ended 한 문장으로 확인한다. 이해가
불명확하면 복사용 블록을 내지 않는다. 조회와 변경을 한 블록에 섞지 않고 Tier 1 사전 조회와 Tier 2 실행을
분리한다.

## 위임 라우팅과 모델 tier

짧고 사용자가 이미 이해한 명령, 사람이 해야 하는 승인·UI 판단, 위임 왕복 이득이 없는 일은
`[나에게 · 직접 실행]`으로 준다. 그 밖의 내부 전용 조회·runbook은 opencode로 보낸다.

opencode 모델은 기본적으로 낮은 tier를 쓰고, 다음 잔여 위험이 있으면 높은 tier를 쓴다.

- prod나 복구 어려운 상태를 바꾸는 runbook
- 로그·error dump처럼 예측 불가 원문에서 민감값을 판별해야 하는 조회
- stop-and-ask 준수 실패가 큰 손실을 만드는 작업

모델 tier는 identity, 필수 템플릿, 금지 범위, evidence gate를 완화하지 않는다. 프롬프트에서 모호성을 먼저
제거하고도 남는 위험만 모델 tier로 덮는다.

## 설정·환경 runbook 규율

설정·배포·환경 구성 위임은 `references/delegating-to-opencode.md`를 읽고 다음을 템플릿에 녹인다.

1. 유일한 계약 기준을 선언한다.
2. 인증서 SAN, host IP, 빈 port 같은 주변 환경에서 값을 역산하지 못하게 한다.
3. 다중값·불명확한 값이면 stop-and-ask하게 한다.
4. 파생값을 계약과 교차검증하고 command evidence를 요구한다.
5. 내부 실행자가 모르는 convention과 결정 근거를 필요한 만큼 제공한다.

## 완료: immutability/evidence gate

내부 작업 완료 보고를 commit 신호로 취급하지 않는다. 요청한 lookup/runbook에 필요한 경우에만 시작과 끝의
`git status --short`를 받아 tracked repository가 그대로인지 비교한다. 이 비교는 baseline/final immutability
evidence일 뿐 내부 commit gate가 아니다. 승인된 `.env.*`와 runtime/DB state 변화는 별도 evidence로 받는다.

완료 조건은 다음과 같다.

- 요청한 lookup/runbook의 command와 exit code, 필요한 구조 evidence가 있다.
- 적용·실행한 canonical revision/artifact가 요청에 지정한 식별자와 일치한다.
- 민감한 실값만 일관되게 가명 처리됐다.
- 확인이 필요했던 경우 tracked repository state가 baseline과 같다.
- 허용된 state change가 열거한 범위와 일치한다.
- code 변경 필요성이 드러났다면 완료로 포장하지 않고 external-implementer backlog로 전환했다.

내부 evidence가 돌아온 뒤 실용적인 경우 사용자가 `[나에게 · 직접 실행]`으로 안전한 read-only
checkpoint 하나를 직접 재실행해 교차 확인한다. migration/deploy/DB 변경 같은 state-changing action은
절대 재실행하지 않는다. spot-check가 내부 evidence와 불일치하면 즉시 흐름을 중단하고 원인을 확인한다.

tracked/canonical source 변경이 발견되면 내부에 commit/push 또는 추가 patch를 시키지 않는다. 변경 경로와
diff evidence를 받고 중단한 뒤 external-implementer가 canonical repository에서 해결한다.

## 출력 원칙

- 매 턴 Goal·To-Do 프리픽스를 먼저 낸다.
- 사용자 대상 텍스트는 대화체로, 내부 대상 블록은 결정론적 지시체로 쓴다.
- 내부 위임마다 `#N`, 4백틱 본문, 여덟 필드, 실행 주체와 blast radius를 명확히 한다.
- 사용자에게 같은 상황 설명을 반복 입력하게 하지 않는다.

## 참조 파일

- `references/delegating-to-opencode.md`: env/runtime/DB state-changing runbook을 보내기 전 읽는다.
