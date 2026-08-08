---
name: runbook-logger
description: Record a just-resolved error into the project's troubleshooting runbook (default docs/troubleshooting.md) in the 증상→근본원인→진단→수정→재발방지 format. Use right after troubleshooting an ops/deploy/runtime error (500, redirect loop, DB, env, build/deps, connection) so it doesn't recur, or when the user says "런북에 정리/추가", "troubleshooting.md에 기록", "이 에러 기록해", "add to runbook". Pulls the ACTUAL facts from this conversation (real error/traceback, confirmed root cause, the fix that worked, diagnostic commands), dedups against existing entries, and commits via a docs PR when the runbook is a committed/synced repo file.
---

# runbook-logger

방금 해결한 장애를 **사람이 다시 안 찾아도 되게** 트러블슈팅 런북에 한 항목으로 박는다.
"증상 → 근본원인 → 진단(명령) → 수정 → 재발방지" 형식. 다음에 같은 증상이 오면 grep 대신 lookup.

## 언제 쓰나
- 운영/배포/런타임 에러를 **추적해서 원인·수정이 확정된 직후**(추측 중이면 아직 아님 — 확정 후).
- 사용자가 "런북에 정리/추가/기록", "troubleshooting.md에 넣어" 등으로 명시할 때.

## Workflow

1. **런북 위치 확인** — 기본 `docs/troubleshooting.md`. 없으면 사용자에게 "표준 헤더로 새로 만들까요?" 묻고 생성(증상→원인→진단→수정→재발방지 + §0 빠른분류 표 + "배포·검증 전 필독" 안내).
2. **사실 수집(필수, 추측 금지)** — 이 대화에서 **실제로 확인된** 것만:
   - 증상(사용자가 본 화면/에러 문자열), 실제 traceback/exception 타입(파일:함수:라인),
   - **확정된** 근본원인(왜 터졌나), 실제로 통한 수정, 재현·진단에 쓴 명령, 재발방지 조치.
   - 미확정·추측이면 기록하지 말고 확정될 때까지 보류.
3. **중복 처리(dedup)** — 같은 증상 항목이 이미 있으면 **새로 만들지 말고 그 항목을 갱신/보강**한다(원인·처치 추가).
4. **항목 추가** — 다음 `#N` 번호로 섹션 추가 + **§0 빠른 분류 표에 한 줄**(증상 → 항목 링크). 앵커(`<a id="N">`)·번호 일관성 유지.
5. **반영** — 런북이 커밋되는 레포 파일이면(예: pholex `docs/troubleshooting.md`는 사외→사내 동기화):
   - `git checkout -b docs/runbook-<slug> origin/main` → 항목 추가 → 커밋 → PR → (사용자 승인 시) main 머지.
   - 단순 로컬/개인 노트면 파일만 저장.
6. **확인** — 추가/갱신한 항목 번호·제목을 사용자에게 한 줄 보고.

## 항목 형식 (그대로 따른다)

```markdown
## <a id="N"></a>#N — <증상 한 줄 제목>
- **증상**: <사용자가 본 것 / 에러 문자열>
- **원인**: <확정된 근본 원인>
- **진단**: <재현·확인에 쓴 실제 명령(터미널/파일 기반)>
- **수정**: <실제로 통한 조치>
- **재발방지**: <설정 보존/코드 패턴/체크리스트 등>
```
그리고 §0 빠른 분류 표에 `| <화면 증상> | [#N 제목](#N) |` 한 줄.

## 원칙
- **증거 기반**: 일반론 말고 이 사건의 실제 traceback·명령·수정만. 안 통한 시도는 빼거나 "안 됨"으로 표시.
- **터미널/파일 증거**: 스크린샷 같은 비재현 증거 대신 curl/psql/logs/grep 명령으로.
- **groupchat-ai와 짝**: groupchat-ai는 진단 *전에* 런북을 읽게 하고, 이 스킬은 해결 *후에* 런북을 채운다. 둘이 루프를 닫는다.
- 새 도메인(SSO/배포/DB 등)이면 관련 스킬의 체크리스트를 항목에 링크해도 좋다(예: `internal-sso-oidc` §6).
