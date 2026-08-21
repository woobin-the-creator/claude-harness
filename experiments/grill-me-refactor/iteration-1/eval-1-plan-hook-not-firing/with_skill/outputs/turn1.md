먼저 레포를 뒤져서 사실부터 채웠다. 결론: 원인 후보가 하나가 아니라 셋이고, 어느 게 실제로 맞았는지는 레포만으로는 못 가른다 — 그 세션에서 뭘 했는지가 필요하다.

## 만드는 것
`plan-saved-session-boundary.sh`(플랜 저장 후 세션 경계 알림 훅)가 왜 침묵했는지 원인을 좁히고, 그 원인에 맞는 최소 수정 + 회귀 테스트 + 버전 반영까지 끝내는 작업 계획.

## 동작 계약
1. 원인 확인 — [?1]~[?3]으로 좁힌다.
2. 수정 — 확정된 원인에 맞는 코드/문서 변경 + `scripts/test-hooks.sh` 회귀 픽스처 추가 + `plugin.json` 버전 동시 상향(CLAUDE.md 규칙) + `docs/workflow-spec.md` R1 절 갱신.

## 조사로 확인한 사실
- `woobin-harness/hooks/claude-hooks.json:60-70` — 이 훅은 PostToolUse에 `"matcher": "Write"`로만 걸려 있다. Bash로 파일을 써도 이 훅은 디스패처 단계에서부터 호출되지 않는다(스크립트 문제가 아니라 등록 문제).
- `woobin-harness/hooks/plan-saved-session-boundary.sh:46` — 발화 조건은 `/docs/(superpowers|woobin_plan)/plans/*.md` 정규식. 같은 파일 `:49` — 그보다 한 단계 더 들어간 경로(`plans/<이름>/<파일>.md`, 분할 레이아웃)는 무조건 `exit 0`이라 침묵한다.
- 이 워크트리(`prepare/new-work`, `plugin.json` `1.9.0`)와 실제 설치된 캐시(`~/.claude/plugins/cache/woobin-harness/woobin-harness/1.10.0`, 2026-08-21 04:15 갱신)가 다르다. 캐시 쪽은 이미 `00-overview.md` 분할 레이아웃에도 발화하도록 고쳐져 있는데(diff 확인함) 이 워크트리엔 없다.
- `~/.claude/plugins/known_marketplaces.json`의 marketplace source는 `/Volumes/LinuxVM/mac_wb_data/codespace/claude-harness`다 — 이 워크트리 경로가 아니다.
- `jq`는 설치돼 있다(`/usr/bin/jq`) — 스크립트 39행의 조기 종료 조건은 원인에서 뺐다.

## 손대는 자리
- `woobin-harness/hooks/plan-saved-session-boundary.sh:46-60`
- `woobin-harness/hooks/claude-hooks.json:60-70`
- `scripts/test-hooks.sh:63-77` (분할 레이아웃 픽스처가 아직 없음)
- `woobin-harness/.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`
- (원인이 맞으면) `~/.claude/plugins/known_marketplaces.json`

## 하지 않는 것
- 설치본(1.10.0)의 분할 레이아웃 diff를 이 워크트리로 그대로 백포트하는 건 이번 "왜 안 떴나" 진단과 분리한다 — 별도 병합 작업.
- `plan-session-boundary-guard.sh` 등 다른 훅 점검은 이번 신고 범위 밖.

## 미결

**[?1] 그때 저장한 플랜 파일 경로가 어떤 모양이었나**
A) `.../plans/<name>/00-overview.md` (분할 레이아웃)  B) `.../plans/<name>.md` (플랫 파일)  C) 위 정규식에 아예 안 걸리는 경로.
다운스트림: A면 세 번째 사실(1.9.0/1.10.0 diff)이 원인이자 해결책이다. B면 그 diff는 무관하고 [?2]·[?3]을 봐야 한다. C면 정규식을 넓히는 결정이 새로 필요하다.
추천: A — writing-plans가 분할 저장을 시작한 날짜가 2026-08-21, 오늘이다.

**[?2] Write 툴로 저장했나, Bash로 저장했나(heredoc/리다이렉트)**
A) Write 툴  B) Bash 직접(`cat > ... <<EOF` 등)  C) 기억 안 남.
다운스트림: B면 스크립트를 아무리 고쳐도 재발한다 — matcher가 "Write"라 디스패처가 호출 자체를 안 하기 때문이다. 이땐 손댈 대상이 스크립트가 아니라 "플랜 저장은 Write 툴만" 규율이 된다.
추천: B — 이 대화에도 "Bash를 Read/Edit/Write보다 우선하라"는 Auto Mode 지시가 실제로 들어와 있었다. 이 매처와 정면 충돌하는 지시라 재현성이 제일 높다.

**[?3] 마켓플레이스 소스가 이 워크트리 경로가 아닌 걸 알고 있었나 / 어느 클론이 정본인가**
A) 알고 있었다, 무관한 이슈  B) 몰랐다, 원인일 수 있다  C) 지금 처음 봤다, 판단 보류.
다운스트림: B면 수정 전에 marketplace 재등록이 선행돼야 한다(안 그러면 여기서 고쳐도 설치본엔 안 실린다). A/C면 이번 진단과 독립으로 두고 넘어간다.
추천: C — 방금 발견한 사실이라 이번 작업의 필수 선행 조건으로 단정하진 않되, 별도 확인은 필요하다.

[?2]가 B로 확정되면 "Bash 저장에도 훅이 걸리게 할지"(지침만 / 코드 방어선 추가 / 둘 다)는 다음 라운드에서 따로 묻는다 — [?1]의 답에 따라 선택지의 의미가 달라지기 때문이다.

[선택 툴로 띄울 항목]
- [?1] 저장된 플랜 경로 모양: 분할 레이아웃(00-overview.md) / 플랫 파일(.md) / 둘 다 아님
- [?2] 저장 수단: Write 툴 / Bash 직접 / 기억 안 남
- [?3] 마켓플레이스 소스 인지 여부: 알고 있었음(무관) / 몰랐음(원인 후보) / 방금 발견(보류)
