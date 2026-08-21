확인했어 — Q1은 옵션 2(DANGER·HANDOFF 통합), 나머지 기본값은 그대로 진행할게. 결정 3~4개짜리 작업이라 별도 스펙 문서는 안 만들고, 플랜에 반려한 대안까지 같이 적어서 저장했어.

**저장 위치:** `docs/woobin_plan/plans/2026-08-21-ctx-threshold-config.md`

## 확정된 결정

1. **임계값 변수를 2개로 통합** — `CTX_WARN_THRESHOLD`(기본 200000)는 그대로, `CTX_DANGER_THRESHOLD`는 폐기하고 상태줄도 `CTX_HANDOFF_THRESHOLD`(기본 300000)를 읽는다. 상태줄 "위험" 색과 실제 핸드오프 강제 시점이 항상 같은 값을 가리킨다.
2. **R13에 UserPromptSubmit 짝 훅을 추가** — `idle-return-guard.sh`와 동일한 패턴으로 새 훅을 만든다. `ctx-handoff-stop.sh`가 핸드오프 문서를 쓴 세션에서 다음 프롬프트가 들어오면 1회 block, "그래도 이어가려면 같은 프롬프트를 10분(600초) 내 다시 제출하라"로 확인받는다. 정상적으로 새 세션(`/clear` 후)이 시작되면 관여하지 않는다.
3. **상태줄 포맷에 임계값 병기** — `⚠ ctx 210k/200k — 작업 경계에서 끊을 것`, `⛔ ctx 310k/300k — handoff 후 새 세션 권장` 형태로 현재값/임계값을 슬래시로 붙인다.
4. **env var를 유일한 조정 경로로 문서화** — `~/.claude/settings.json`의 `"env"` 블록에 세 변수 예시를 넣고, `docs/workflow-spec.md` §4 "조정 손잡이" 표에 `CTX_WARN_THRESHOLD`·`CTX_HANDOFF_THRESHOLD`를 추가한다. `bootstrap.sh`는 건드리지 않는다(설치 스크립트가 값을 강제하면 오히려 "내가 바꿀 수 있게"라는 원 요청과 충돌).

## 반려한 대안

- **3개 변수 유지(WARN/DANGER/HANDOFF 분리)** — Q1의 옵션 1. 표시와 실제 동작을 따로 튜닝할 수 있다는 장점보다, 하나만 바꿨을 때 "상태줄이 거짓말하는" 드리프트 위험이 더 크다고 판단해 반려.
- **완전 차단(진짜 세션 잠금)** — R13 무효화 조건 문구의 "block(토큰 0 강제 정지)"을 문자 그대로 읽으면 이걸 가리키는 것처럼 보이지만, Claude Code의 block 훅은 "그 턴에 모델을 안 부른다"만 할 수 있고 사용자의 다음 입력 자체를 원천 차단하는 기능은 제품에 없다. R6가 이미 같은 한계 안에서 "재제출로 우회 가능한 speed bump"로 타협했고, 그 컨벤션을 그대로 재사용하는 게 새 메커니즘을 발명하는 것보다 안전해서 반려.
- **override 유예 시간을 새 상수로 분리** — `IDLE_GUARD` 계열과 다른 값을 쓸 이유가 없어서, 새 env var를 하나 더 늘리지 않고 기존 600초를 재사용하는 쪽으로 반려.

## 손댈 파일

- `statusline/ctx-warn-statusline.sh` — `CTX_DANGER_THRESHOLD` 제거, `CTX_HANDOFF_THRESHOLD` 참조로 교체, 출력 포맷에 임계값 병기.
- `woobin-harness/hooks/ctx-return-guard.sh` (신규) — `idle-return-guard.sh` 패턴을 컨텍스트 핸드오프 마커에 맞게 이식.
- `hooks/claude-hooks.json` — 신규 훅을 `UserPromptSubmit`에 연결(Codex는 기존 R13과 같은 이유로 미연결 유지).
- `scripts/test-hooks.sh` — 신규 훅용 결정론적 fixture 추가.
- `docs/workflow-spec.md` — R13 기전 설명에 짝 훅 추가, §4 훅 인벤토리 11→12, "조정 손잡이" 표에 두 변수 추가, R13 무효화 조건 중 "block으로 바꿔라" 항목을 이번 변경으로 해소됐다고 갱신.
- `docs/workflow.html`, `README.md` — 훅 개수/설명 동기화(CLAUDE.md의 "같이 고쳐야 하는 것" 요구사항).
- `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` — 버전 올리기(설치 캐시가 버전별로 굳으므로 필수). 올리기 전에 `~/.claude/plugins/cache/woobin-harness/woobin-harness/`에 이미 있는 버전을 먼저 확인.

플랜 저장까지는 이 세션에서 계속 이어가지만, 구현은 여기서 바로 시작하지 않을게 — 이 워크플로우의 유일한 강제 경계는 "플랜 저장 후, 구현 시작 전"이야. 플랜 내용 훑어보고 이견 있으면 말해줘. 없으면 다음에 새 세션(또는 `/clear` 후)에서 구현 들어가면 돼.
