# 사내 AI(opencode)에 위임하는 프롬프트 작성법

`[→ 사내 AI(opencode)]` 블록이 단순 조회를 넘어 gitignored env, runtime/container, migration/deploy,
DB state를 바꾸는 runbook을 실행할 때 읽는다. 역할·소유권·마스킹·여덟 필드 템플릿의 정본은
[`../SKILL.md`](../SKILL.md)의 「시작 전 identity gate」, 「모든 내부 위임의 필수 템플릿」,
「완료: immutability/evidence gate」다. 이 문서는 설정 위임의 결정 규칙만 보강한다.

## 실행 전제

1. 모든 새 세션·실행 위임 시작마다 프로젝트 `AGENTS.md`의 clone-local role 계약을 확인한다.
2. Pholex에서는 `git config --local --get pholex.agentRole`을 읽고, cached role의 유무와 무관하게
   실제 runtime으로 `scripts/agent-role.sh ensure <actual-runtime>`을 매번 실행한다. 미설정은
   helper가 선행 조건을 확인해 초기화하고 cached role은 실제 runtime과 맞는지 검증한다.
   config read/helper error, unknown, conflict면 config를 직접 초기화·수정·복구하지 않고 mutation 없이
   중단한다. helper 성공 뒤에도 실제 runtime이 `opencode`, cached role이 `internal-executor`인
   위임에서만 계속한다.
3. external-implementer가 canonical code/test/migration/runbook을 먼저 작성한다.
4. internal-executor는 위임된 사실 조회와 승인된 runbook 적용·실행·evidence 수집만 한다.
5. tracked/canonical source 수정과 commit/push는 어떤 tier에서도 허용하지 않는다.

## 왜 결정 규칙이 필요한가

내부 실행자는 대화 전체의 port convention, 등록된 redirect URI, 이전 결정을 모른다. 모호한 출처가 있으면
주변 환경에서 그럴듯한 값 하나를 골라 진행할 수 있다. 모델 성능에 기대지 말고 프롬프트에서 유일한 기준,
허용 변화, stop condition, evidence를 결정론적으로 고정한다.

## 원칙 1 — 유일한 계약 기준 선언

설정값(IP, port, URL, key 이름, 경로)은 승인된 외부 계약에서 가져온다. 등록된 redirect URI나 합의된
port convention처럼 어떤 문자열이 기준인지 `Commands/runbook`에 명시한다. 내부 실행자는 그 기준에 맞추고
새 기준을 설계하지 않는다.

## 원칙 2 — 환경에서 역산 금지

인증서 SAN, host network interface, 비어 있는 port 등은 계약값의 유효성을 검증하는 evidence이지 값을
선택하는 출처가 아니다. 여러 후보 중 하나를 고르거나 빈 값을 발견해 새 값을 만들지 못하게 한다.

## 원칙 3 — stop-and-ask

계약값이 없거나 여러 값이 충돌하거나 실행 중 예상 밖 상태를 만나면 추측·수정·우회하지 않고 중단해
evidence와 함께 보고하게 한다. 실패처럼 보이는 정상적인 fail-closed 동작도 임의 명령으로 우회하지 않는다.

## 원칙 4 — 교차검증과 evidence

파생된 설정이 계약 문자열과 글자 단위로 일치하는지 확인한다. 실행한 command, 단계별 exit code, 필요한
stdout/stderr, 상태 전후 evidence를 요구한다. `git status --short`는 tracked repository immutability 확인이
실제로 필요할 때만 baseline/final로 비교하며, commit 준비나 승인에 사용하지 않는다.
내부 evidence가 돌아오면 실용적인 경우 사용자가 안전한 read-only checkpoint 하나를 직접 재실행한다.
state-changing action은 재실행하지 않고, checkpoint가 내부 evidence와 다르면 즉시 중단한다.

## 원칙 5 — 값 기반 마스킹

프로젝트 보안 정책을 우선한다. Pholex의 사외 보고에서는 IP/host/port/internal URL, account/employee ID,
credential/secret/token/certificate, 개인·장비·lot 등 운영 식별자와 실제 row/content만 일관된 가명으로
바꾼다. 승인된 schema/table/column 식별자, SQL/query shape, 설정 key, library interface, path, count,
exit code는 진단에 필요한 구조 evidence이므로 유지한다.

마스킹은 사외로 나가는 보고에만 적용한다. 승인된 사내→사내 데이터 처리 runbook의 입력 데이터를 가명으로
변환하지 않는다.

## 실행 위임 작성 순서

1. `Role precondition`에 `internal-executor` 확인과 conflict stop을 적는다.
2. `Read-only facts needed`에 실행 전 필요한 최소 조회를 적는다.
3. `Allowed state changes`에 승인된 gitignored env/runtime/DB 변화만 닫힌 목록으로 적는다.
4. 고정 `Forbidden` 문구를 유지한다.
5. `Commands/runbook`에 external canonical revision/artifact의 경로, commit/버전, 실행 순서를 적는다.
6. `Evidence to return`에 실제 적용·실행한 revision/artifact 식별자, 단계별 command, exit code,
   출력, 최종 state를 적는다.
7. `Mask only these value categories`에 실제 민감값 범주만 적는다.
8. `Stop conditions`에 계약 누락·충돌·명령 실패·예상 밖 diff/state를 적는다.

내부 실행자가 code 수정 필요성을 발견하면 현재 실행을 중단하고 evidence만 반환한다. external-implementer가
canonical code/test를 수정한 뒤 새 runbook을 제공해야 재개한다.

## 사례: redirect URI / IP 역산 사고

과거 SSO 배포에서 인증서 SAN의 여러 IP 중 하나와 빈 port를 내부 실행자가 골라 설정해 등록된 redirect URI와
달라졌다. 교정 계약은 단순하다. 등록된 redirect URI 전체 문자열이 유일한 기준이고, `APP_BASE_URL`과 port는
거기에 맞춰야 한다. SAN과 network 상태는 기준값이 실제 환경에서 유효한지 확인하는 evidence로만 쓴다.
