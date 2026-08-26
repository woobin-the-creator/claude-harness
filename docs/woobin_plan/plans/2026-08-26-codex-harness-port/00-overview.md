# codex-harness 0821~0826 이식 Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Task bodies live in the sibling `task-N.md` files; read each one immediately before implementing it, not all up front.

**Goal:** codex-harness가 2026-08-21~08-25에 만든 개선 중 claude-harness에 값이 있는 6건을 Claude 런타임에 맞게 이식하고, 그 과정에서 드러난 문서 드리프트를 정리한다.

**Architecture:** 코드를 그대로 복사하는 건 1건(`contact-sheet.sh`)뿐이다. 나머지는 codex 런타임 전제(`codex plugin list` 텍스트 파싱, `apply_patch` 지시문, `codex_sessions.py`)에 묶여 있어 **컨셉만 가져와 Claude 자산으로 재작성**한다. 훅은 셸(bash 3.2 호환), 검증은 기존 `scripts/test-hooks.sh`·`test-skills.sh` fixture에 붙인다.

**Tech Stack:** bash 3.2, `jq`, POSIX `sh`, `ffmpeg`/`ffprobe`, Python 3.9+ (기존 오디트 스크립트), Markdown

## Global Constraints

- **`~/.claude/`에 사본을 만들지 않는다.** 정본은 `woobin-harness/` 안이다. 훅이 이중 발화한다.
- **훅은 bash 3.2 호환**으로 쓴다 (macOS 기본 bash). 연관 배열·`${var,,}`·`mapfile` 금지.
- **훅은 fail-open이다.** 입력 JSON·`jq`·대상 파일 중 하나라도 없으면 `exit 0`으로 조용히 빠진다. 세션 시작을 막지 않는다.
- **과거 이력 문서는 소급 수정하지 않는다** — `home/HARNESS-LOG.md`의 기존 항목, `docs/codex-compatibility-audit-2026-08-12.md`, `history/*.html`, `docs/woobin_plan/plans/` 아래 기존 플랜. 그때의 사실을 적은 문서다. (`HARNESS-LOG.md`에 **새 항목을 추가**하는 것은 Task 7에서 한다.)
- **스킬 개수가 19 → 20이 된다.** 개수를 단언하는 곳이 5개 파일에 하드코딩돼 있다(Task 5 참조). 하나라도 빠뜨리면 검증 게이트가 죽는다.
- **버전은 `1.14.0`으로 올린다.** 레포는 현재 `1.13.0`, 설치 캐시의 최대는 `1.12.0`이다 — `1.14.0`은 캐시에 없으므로 안전하다. 두 `plugin.json`(`.claude-plugin`·`.codex-plugin`)을 **같이** 올린다.
- 새 스킬 `explain`의 **본문은 영어**로 쓴다. `writing-plans/SKILL.md`가 이미 영어이고, Task 6이 플랜 산출물을 영어로 옮기는 것과 방향이 같다. description의 트리거 문구는 한국어 트리거를 포함한다.

## Tasks

| # | Title | Files | Completion check |
|---|---|---|---|
| 1 | 스테일 설치본 SessionStart 훅 + 버전 범프 | `woobin-harness/hooks/plugin-update-guard.sh`, `woobin-harness/hooks/claude-hooks.json`, `scripts/test-hooks.sh`, `scripts/test-skills.sh`, `docs/workflow-spec.md`, `docs/workflow.html`, `README.md`, 두 `plugin.json` | `./scripts/test-hooks.sh && ./scripts/check-harness-docs.sh` |
| 2 | 데모 프레임 contact sheet | `woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh`, `woobin-harness/skills/pr-demo-video/SKILL.md`, `scripts/test-skills.sh` | `./scripts/test-skills.sh` |
| 3 | 서브에이전트 토큰 귀속 검증 | `scripts/test-skills.sh`, (조건부) `woobin-harness/skills/token-waste-audit/scripts/waste_scan.py`, `woobin-harness/skills/capability-audit/scripts/collect.py` | `./scripts/test-skills.sh` |
| 4 | grill-me 원장 `근거` 열 + 스펙 파일 형식 | `woobin-harness/skills/grill-me/SKILL.md` | `claude plugin validate ./woobin-harness` |
| 5 | explain 개명 + 텍스트 explain 신설 | `woobin-harness/skills/explain-in-html/`, `woobin-harness/skills/explain/SKILL.md`, 개수 단언 5곳 | `./scripts/test-skills.sh && ./scripts/check-harness-docs.sh` |
| 6 | 플랜 산출물 영문화 규칙 | `woobin-harness/skills/writing-plans/SKILL.md`, `woobin-harness/skills/writing-plans/plan-document-reviewer-prompt.md` | `claude plugin validate ./woobin-harness` |
| 7 | 문서 동기화 · 버전 범프 · 전체 검증 | `docs/workflow-spec.md`, `home/HARNESS-LOG.md`, `README.md`, 두 `plugin.json` | `./scripts/check-harness-docs.sh && ./scripts/test-hooks.sh && ./scripts/test-skills.sh` |

## Ordering

- **Task 1~6은 서로 의존하지 않는다.** 각각 독립으로 테스트되고 커밋된다.
- **`docs/workflow-spec.md`를 Task 1·4·5·6이 모두 건드린다.** §3(규칙)과 §4(인벤토리 표) 두 절에 각자 항목을 추가한다. 이 파일 때문에 병렬 실행은 충돌한다 — **순차로 실행해야 한다.**
- **Task 5가 스킬 개수를 19 → 20으로 바꾼다.** Task 7의 `check-harness-docs.sh` 통과가 여기 달려 있다.
- **버전 범프는 Task 1에서 한 번만 한다** (`1.14.0`). `scripts/check-harness-docs.sh`는 `woobin-harness/`가 바뀌었는데 두 `plugin.json`의 `version`이 안 바뀌면 하드 실패(`✗`)하므로, 첫 태스크에서 올려 둬야 이후 태스크가 각자 이 게이트를 통과할 수 있다. Task 2~7은 다시 올리지 않는다 — 이 플랜 전체가 하나의 변경 묶음이다.
- **Task 1은 훅을 추가하므로 문서 4종이 같이 걸린다.** `check-harness-docs.sh`가 훅 **추가** 시 `docs/workflow.html` 변경을, 훅·에이전트 변경 시 `docs/workflow-spec.md` 변경을 하드 검사한다. 그래서 Task 1이 자기 문서 동기화까지 끝낸다.
- **Task 7은 1~6 전부에 의존한다.** 마지막에 한 번만 돈다.
- Task 3은 결과가 두 갈래다(버그 있음 → 수정 / 없음 → 테스트만 남김). 어느 쪽이든 Task 7의 입력은 "테스트가 통과한다" 하나로 같다.

## Rejected Alternatives

- **codex PR #11을 이식** — 기각. 그 PR은 claude-harness #22·#9·#19를 codex로 **역이식**한 것이다(PR 본문이 upstream 핀 `9bd3634`을 명시한다). `grill-me`·`writing-plans`·`design-workflow`의 원본이 이 레포에 있고, `design-workflow`는 이쪽이 `evals/`·routes fixture까지 갖춰 더 풍부하다.
- **`spec_contract.py` 검증기 + 계약 문서 + append-only 훅 도입** — 기각. 이 셋은 스펙을 **파일로 저장할 때만** 작동하는데, `grill-me` §160·§167이 같은 세션 완결을 기본값으로, 파일 저장을 폴백으로 규정한다. 값은 가끔 나오고 유지 비용은 상시다. 더해서 (a) 스펙 형식을 서술하는 소유자가 1개에서 3개로 늘고 그중 판정 주체(스크립트)의 드리프트는 눈에 안 보이며, (b) 게이트가 생기면 미결을 가정 절로 밀어 통과시키는 우회로가 열린다 — 검증기는 형식만 보지 정직함은 못 본다. 대신 Task 4의 산문 규칙만 남긴다.
- **append-only 가드를 `PreToolUse(Edit|Write)`로 재작성** — 기각. 확정 스펙의 무단 변경은 git 이력과 PR diff가 이미 잡는다. 훅은 세 번째 겹인데, **훅은 실패해도 출력이 없어 정상과 구분되지 않는다**(`stale-branch-guard: marker missing`이 지금 그 상태다). 스크립트는 명시 호출이라 시끄럽게 죽는다.
- **codex `plugin_update_guard.py`를 그대로 복사** — 기각. `codex plugin list`의 사람용 텍스트 출력을 정규식으로 파싱한다. Claude Code에는 같은 명령이 없고, 대신 `~/.claude/plugins/known_marketplaces.json`(소스 경로)과 `installed_plugins.json`(설치 버전 + `gitCommitSha`)이 **구조화된 JSON**으로 있어서 `jq` 두 번이면 된다. 파싱이 더 안전하고 드리프트 신호도 하나 더 얻는다(버전 + 커밋).
- **`explain`을 유지하고 새 스킬에 다른 이름** — 기각. 사용자가 `/explain`을 텍스트 설명 스킬에 주기로 했다. 기존 인포그래픽 스킬이 `explain-in-html`로 간다.
- **`writing-plans` 영문화를 별도 PR로 분리** — 기각. 사용자 판단으로 이번 계획에 포함한다. 변경 표면이 스킬 2파일 + 스펙 1절로 작다.
- **스킬 개수 하드코딩을 세는 방식으로 전환** — 이번엔 안 한다. `HARNESS-LOG.md` #27이 "개수 하드코딩 자체가 재발원"이라고 미조치로 남긴 과제이고 여전히 맞지만, 이 플랜의 범위를 넘는 별도 리팩터다. Task 5는 숫자만 갱신하고, Task 7이 후속 과제로 다시 기록한다.
