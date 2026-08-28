---
name: groupchat-debug
description: 사내 AI(opencode)가 보낸 traceback·로그·장애 보고서를 air-gap 밖에서 진단하고, external-implementer가 canonical code/test fix를 작성하도록 돕는 원격 디버깅 스킬. internal-executor에는 사내 환경 재현, 로그·env·DB 사실 조회, 승인된 canonical fix/runbook 실행 검증과 evidence 반환만 맡긴다. 사용자가 사내/opencode의 500, SSO, DB connection, redirect, 422, build 장애 보고를 붙여넣고 원인·조치를 물을 때 사용한다. 로컬에서 직접 재현 가능한 버그는 `repro-loop`, 장애가 아닌 일반 삼자대화는 `groupchat-ai`를 사용한다.
---

# groupchat-debug

사내 AI가 보낸 error evidence를 외부 canonical repository와 대조해 원인을 좁히고 수정·검증 루프를 닫는다.

## 역할 계약

먼저 `groupchat-ai`의 「시작 전 identity gate」를 통과한다. 프로젝트 `AGENTS.md`의 clone-local role 계약과
실제 runtime을 함께 확인한다. `external-implementer`만 진단 mediator로 진행한다. `internal-executor`에서
호출되면 외부 lead를 흉내 내지 않고 이미 받은 재현·조회·검증 runbook만 수행한다. unknown/conflict에서는
자동 변경 없이 중단한다.

- **external-implementer**: 가설을 세우고 canonical code/test/docs/migration/runbook을 직접 수정·검증하며
  code review와 commit/push를 맡는다.
- **internal-executor**: 사내 환경에서 재현하고 로그·env·DB·내부 library 사실을 조회하며, 외부가 제공한
  canonical fix/runbook을 적용·실행해 evidence를 반환한다.
- internal-executor는 경로와 무관하게 tracked/canonical source를 수정하거나 commit/push하지 않는다.
  `/real/`, migration, scripts에도 내부 code ownership 예외를 만들지 않는다.

## groupchat-ai에서 재사용할 규약

- `[→ 사내 AI(opencode)] · 프롬프트 #N`, `[나에게]`, `[대기]` 라벨과 일련번호 규칙
- 모든 내부 위임 본문의 정확히 여덟 필드 템플릿과 4백틱 복사 포맷
- Tier 1 read-only lookup/evidence와 Tier 2 승인된 env/runtime/DB state-changing runbook 구분
- 값 기반 마스킹과 immutability/evidence completion gate
- 설정값 위임 시 `groupchat-ai/references/delegating-to-opencode.md`의 역산 금지·교차검증·stop 조건

이 스킬은 위 계약을 복제하지 않고 진단 사고법만 정의한다.

## Workflow

### 0. 보고서 파악

사용자가 붙여넣은 블록을 기본적으로 opencode 보고로 본다. traceback, log, symptom, 실행 환경, 이미 수행한
명령을 분리한다. 발신자나 환경이 모호하면 추측하지 않고 한 줄로 확인한다.

### 1. Identity와 immutability 확인

진단에 필요한 경우에만 내부 실행자의 baseline `git status --short`와 실행 중인 canonical revision을 받는다.
이 정보는 사내 실행본이 외부가 진단하는 revision과 같은지, tracked repository가 불변인지 확인하는 evidence다.
commit 준비나 내부 변경 허용에 쓰지 않는다.

tracked/canonical source 차이가 발견되면 내부에 revert나 patch를 시키지 않는다. 경로·revision·diff evidence만
받고 재현을 멈춘다. external-implementer가 canonical repository에서 필요한 code/test fix를 만든 뒤 다시
검증한다. 모든 경로에 같은 규칙을 적용하고 옛 디렉터리 경계를 되살리지 않는다.

### 2. Triage와 runbook 대조

장애를 SSO/auth, DB/connection, env/config, redirect/routing, validation, build/deps, nginx/network 등으로
분류한다. 프로젝트 `docs/troubleshooting.md`에서 같은 symptom을 먼저 확인한다. hit이면 과거 chat을 찾지 말고
현재 canonical runbook을 적용한다.

### 3. 가설 구성

3~5개의 falsifiable hypothesis를 우선순위로 세우고 검증 주체를 붙인다.

- `[레포검증]`: external canonical code/test로 확인한다.
- `[환경검증]`: internal env/DB/runtime에서만 확인할 수 있어 Tier 1 evidence lookup으로 위임한다.

각 가설에 "X가 원인이면 Y evidence가 관찰된다"는 예측을 적는다. 예측 없는 추정은 버린다.

### 4. 최소 재현과 evidence 수집

- 외부에서 확인 가능한 code path는 직접 읽고 test를 만든다.
- 내부에서만 재현 가능한 symptom은 internal-executor에게 최소 재현 command와 관찰할 한 변수를 준다.
- 한 번에 한 변수만 바꾼다. 여러 수정 후보를 동시에 적용하지 않는다.
- command, exit code, 필요한 log line, query shape/count, runtime state를 evidence로 받는다.
- 승인된 schema/table/column과 SQL/interface 구조는 유지하고 민감한 host/account/secret/실제 row 값만
  프로젝트 보안 정책에 따라 일관된 가명으로 바꾼다.

재현 자체가 runtime/DB state를 바꾸면 Tier 2로 분류하고 사용자의 명시 승인을 받은 canonical runbook만
실행한다. internal-executor가 자체 patch나 ad-hoc schema 변경으로 재현을 우회하지 못하게 한다.

### 5. Canonical fix

가설이 확정되면 external-implementer가 canonical code와 regression test를 직접 수정한다. 사내에서만 확인한
schema나 library interface는 evidence로 계약에 반영하되 민감한 실값은 code/docs에 넣지 않는다.

내부 실행자에게는 새 정본의 revision과 승인된 적용·재현·검증 runbook만 전달한다. code 수정이 더 필요하면
그 사실과 evidence를 돌려받아 외부에서 다음 patch를 만든다.

### 6. 검증과 완료

내부 검증 결과에서 다음을 확인한다.

- canonical revision과 실행한 command/runbook이 식별된다.
- 각 단계의 exit code와 기대한 behavior evidence가 있다.
- 필요한 경우 final `git status --short`가 baseline과 같아 tracked repository immutability가 증명된다.
- 승인된 env/runtime/DB state change가 열거한 범위 안이다.
- 민감한 값만 가명 처리되고 진단 구조는 유지됐다.

evidence가 부족하거나 code 수정 필요성이 남으면 완료로 포장하지 않고 hypothesis loop 또는 external backlog로
돌린다. 내부 commit/push를 완료 조건으로 삼지 않는다.

### 7. 기록

새 장애를 해결했으면 `runbook-logger`로 `docs/troubleshooting.md`에 증상, 근본 원인, 진단 evidence,
canonical fix, 재발 방지를 기록한다.

## 출력 원칙

- 가장 가능성 높은 원인과 다음 검증을 먼저 말한다.
- 가설은 순위와 검증 주체를 함께 보여준다.
- 내부 대상 블록은 `groupchat-ai`의 정확히 여덟 필드 템플릿을 사용한다.
- "고쳤다"는 보고보다 command와 observable evidence로 결론을 닫는다.

## 함정

- 사내에서 code patch를 만들게 하지 않는다. 사내 전용 재현이어도 fix 소유권은 외부다.
- 내부 변경을 되돌리라는 patch 지시로 또 다른 tracked 변경을 만들지 않는다. 차이를 보고받고 외부에서 해결한다.
- 한 번에 여러 변수를 바꾸지 않는다.
- fail-closed 동작을 임의 명령으로 우회하지 않는다.
- 외부에서 재현할 수 없는 가설은 사내 evidence가 오기 전까지 사실로 단정하지 않는다.
