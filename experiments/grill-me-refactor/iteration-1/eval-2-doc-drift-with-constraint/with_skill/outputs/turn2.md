확인했다. `[?1]`은 B(하드코딩 유지 + 감시 대상 추가), 나머지 `[?2]`는 추천대로 A(모든 매치 검사)로 확정한다.

## 결정 원장 — 스킬 개수 문서 동기화

| # | 결정 | 고른 것 | 기각한 것 — 이유 |
|---|------|---------|------------------|
| 1 | `test-skills.sh`·`validate-codex.sh`의 하드코딩 `44` 처리 | **B** — 숫자는 유지하고 `check-harness-docs.sh` 감시 대상에 `test-skills.sh:23,98`·`validate-codex.sh:144` 추가 (사용자가 직접 선택) | A(동적 카운트 전환) — "정확히 N개가 설치돼야 한다"는 고정 기댓값(카나리아)을 잃고 싶지 않다는 판단으로 기각 |
| 2 | 산재된 "스킬 N개" 문구 검사 방식 | **A** — `cmp_num`이 파일 내 모든 매치를 검사 (미결이었으나 "나머지는 추천대로"로 기본 확정 — 사용자가 직접 고른 게 아님) | B(README 문구를 표 형식으로 통일) — 문서 톤을 바꾸지 않는 쪽을 우선 |

**가정** — 내가 기본값으로 정한 것. 틀리면 말해라
- 지금 이미 드리프트난 값(`README.md:11,12,110`·`docs/workflow.html:404`·`scripts/test-skills.sh:23,98`·`scripts/validate-codex.sh:144`, 전부 `44`)은 이번 작업에서 `28`로 같이 고친다 — 안 그러면 확장된 검사가 기존 파일에 즉시 ✗를 낸다
- 새 훅·새 트리거 등록 없음 — 기존 `harness-doc-sync-guard.sh`(Claude PostToolUse)·`hooks.json`(Codex) 배선을 그대로 재사용한다
- `CLAUDE.md`의 "검증" 체크리스트에 `check-harness-docs.sh`가 안 올라가 있는 것, `docs/workflow-spec.md`의 "스킬 28개" 큐레이션 절을 전량 로스터로 바꾸는 것 — 둘 다 이번 스코프 밖으로 남긴다

**미결**
- 없음

미결이 비었으니 이 원장으로 확정한다. 다룬 게 이제 실제로 만들 작업이니 같은 세션에서 이어서 플랜을 잡는다 — `/clear` 하지 않는다. 코드 조사(정확한 삽입 지점 확인, 기존 fixture 깨짐 여부)는 탐색 서브에이전트에 위임하고, 이 원장을 그대로 플랜의 "기각한 대안" 절 원본으로 넘긴다. 플랜은 다음 산출물로 잡는다.

- `scripts/check-harness-docs.sh` — for 루프에 `docs/workflow.html` 추가, `cmp_num`을 전체 매치 검사로 확장, `test-skills.sh`·`validate-codex.sh`를 감시 대상에 추가
- `scripts/test-skills.sh`, `scripts/validate-codex.sh` — 하드코딩 `44`는 그대로 두고 값만 `28`로 정정 (구조는 안 건드림, 결정 1번에 따름)
- `README.md`(11·12·110행), `docs/workflow.html`(404행) — `44` → `28` 정정
- 위 변경 후 `sh scripts/check-harness-docs.sh`와 `sh scripts/test-skills.sh`를 다시 돌려 전부 통과하는지 확인

바로 플랜 작성으로 넘어갈지, 지금 여기서 멈출지 알려주면 그대로 진행하겠다.
