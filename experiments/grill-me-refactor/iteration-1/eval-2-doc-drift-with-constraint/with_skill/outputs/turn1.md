레포를 먼저 봤다. 좋은 소식부터: 요구사항 1·2를 하는 장치는 **이미 있다.** `scripts/check-harness-docs.sh`가 훅·에이전트·스킬 개수를 파일시스템에서 직접 세고(`ls woobin-harness/skills/*/ | wc -l` 등) 문서에 적힌 숫자와 대조하며, `woobin-harness/hooks/harness-doc-sync-guard.sh`라는 **기존 PostToolUse 훅**(Claude: `claude-hooks.json:75`, Codex: `hooks.json:22`)에 이미 배선돼 있다. `woobin-harness/` 아래를 고치면 세션당 1회, 불일치를 additionalContext로 알려준다 — 정확히 요구사항 3("새 훅은 싫다")을 이미 지키면서 1·2를 하는 물건이다. 이 훅 자체의 헤더 주석이 왜 생겼는지도 적어놨다: 2026-08-10에 `docs/workflow.html`이 빠졌던 걸 사용자가 직접 물어봐서 발견한 사고가 있었다.

그런데 지금 그 장치가 **범위를 다 못 덮어서, 바로 지금 이 순간 드리프트가 나 있다.**

- 실제 스킬 수: 28개 (`ls -d woobin-harness/skills/*/`)
- `README.md:39`("SKILL.md 28개"), `.claude-plugin/marketplace.json:11`, `woobin-harness/.claude-plugin/plugin.json:3` — 다 28로 맞고, check-harness-docs.sh가 검사해서 통과한다
- 그런데 같은 `README.md`의 11·12·110행("스킬 44개")과 `docs/workflow.html:404`("공통 스킬 44개")는 **44로 낡아 있다.** check-harness-docs.sh는 README에서 오직 "SKILL.md N개" 한 줄만 정규식으로 보고, `docs/workflow.html`은 애초에 검사 대상 파일 목록(스크립트 49행)에 빠져 있어서 아예 안 본다
- `scripts/test-skills.sh:23`과 `:98`, `scripts/validate-codex.sh:144`도 `44`가 하드코딩돼 있다 — 실제로 지금 `sh scripts/test-skills.sh`를 돌리면 `✗ expected 44 skills, found 28`이 뜬다. 이 두 스크립트는 check-harness-docs.sh 감시 대상이 아니다

즉 "스킬을 하나 추가할 때마다 손으로 고쳐야 하는 네 군데"는 실제로 존재하고, 그중 절반은 이미 자동 감시되고 있고 나머지 절반(README 산문 3곳·workflow.html·테스트 스크립트 2개)은 감시 밖이라 새다.

## 만드는 것
새 훅을 만들지 않고, 이미 배선된 `scripts/check-harness-docs.sh` + `harness-doc-sync-guard.sh`의 검사 범위를 넓혀 지금 새고 있는 자리(`docs/workflow.html`, README 산문 3곳, `test-skills.sh`/`validate-codex.sh`의 하드코딩)까지 실측 개수와 자동 대조되게 한다.

## 동작 계약
1. 개수 세는 걸 자동화 — `check-harness-docs.sh`가 이미 하는 실측 카운트(`n_skills` 등) 로직은 그대로 두고, `test-skills.sh`·`validate-codex.sh`의 하드코딩 `44`를 실측과 연동되게 고친다 (방식은 [?1])
2. 빠뜨리면 알려주는 장치 — `check-harness-docs.sh`의 검사 대상 파일 목록(스크립트 49행)에 `docs/workflow.html`을 추가하고, README처럼 같은 개수가 여러 줄에 흩어진 파일에서 첫 줄만 보고 통과 처리되는 문제를 고친다 (방식은 [?2])
3. 새 훅 안 만듦 — `harness-doc-sync-guard.sh`(Claude PostToolUse)·`hooks.json`(Codex) 배선을 그대로 재사용한다. 새 훅 파일도, 새 이벤트 등록도 없다

## 손대는 자리
- `scripts/check-harness-docs.sh:49` — for 루프 검사 대상 파일에 `docs/workflow.html` 추가
- `scripts/check-harness-docs.sh:33-43` (`num`/`cmp_num`) — [?2]에 따라 첫 매치만이 아니라 파일 내 모든 매치를 검사하도록 확장
- `scripts/test-skills.sh:22-24,98` — [?1]에 따라 하드코딩 `44` 처리
- `scripts/validate-codex.sh:144-145` — 위와 동일
- 선행 정리: `README.md:11,12,110`·`docs/workflow.html:404`·`scripts/test-skills.sh:23,98`·`scripts/validate-codex.sh:144`의 `44`를 지금 실측값 `28`로 맞춘다 — 안 하면 확장된 검사가 기존 파일에 즉시 ✗를 낸다

## 하지 않는 것
- 새 Claude Code / Codex 훅 생성 (요청 3번에서 명시적으로 거부됨)
- CI(GitHub Actions)나 git pre-commit 훅 신설 — 이 레포엔 지금 둘 다 없고, 이번 요청 범위가 아니다
- `docs/workflow-spec.md`의 "스킬 28개" 절을 전체 28개 스킬의 전량 로스터로 바꾸는 것 — 그 절은 "파이프라인에 직접 물린" 12개짜리 큐레이션 목록이라 스킬 추가마다 갱신 대상이 아니다 (다만 이 목록도 최근까지 `grill-me` 자체가 빠져 있던 전례가 있다는 점만 참고로 남긴다)
- `CLAUDE.md`의 "검증" 체크리스트에 `check-harness-docs.sh`가 안 올라가 있는 것 — 발견했지만 이번 스코프 밖

## 미결
[?1] `test-skills.sh`/`validate-codex.sh`의 하드코딩 `44` 처리 방식 — 잠정: A(동적 카운트 전환)
[?2] README처럼 같은 개수가 여러 줄에 흩어진 파일의 검사 방식 — 잠정: A(전체 매치 검사)

---

[?1] `test-skills.sh`·`validate-codex.sh`의 하드코딩 `44`를 어떻게 처리할지.

이 두 스크립트는 "설치본(또는 임시 캐시)이 소스 스킬을 빠짐없이 담았는지"를 검증하는 목적이라, `check-harness-docs.sh`와는 성격이 조금 다르다.

- **A. 동적 카운트로 전환** — `check-harness-docs.sh`와 같은 방식으로 `woobin-harness/skills/*/` 개수를 그 자리에서 세어 설치 결과와 비교한다. 다운스트림: 이 두 파일은 스킬을 추가·삭제해도 다시는 손 안 대도 된다. 대신 "정확히 N개가 설치돼야 한다"는 고정 기댓값(카나리아) 성격은 사라지고, "소스와 설치본이 같은 수인가"만 검증하게 된다.
- **B. 하드코딩 유지 + 감시 대상 추가** — 숫자는 그대로 박아두되 `check-harness-docs.sh`의 검사 대상 파일 목록에 `test-skills.sh:23,98`·`validate-codex.sh:144`를 추가해, 빠뜨리면 훅이 알려주게만 한다. 다운스트림: 요구사항 1("자동화")은 부분적으로만 채워진다 — 스킬을 추가할 때마다 이 세 줄은 여전히 사람이 고쳐야 하고, 훅이 세션 1회 알림이라 그 세션을 넘기면 못 잡을 수도 있다.

추천은 A다. 요청 1번이 "개수 세는 것 자체의 자동화"였고, 이 두 스크립트가 지키려는 것도 "설치가 소스를 온전히 복사했는가"이지 "정확히 44"라는 상수 자체는 아니기 때문이다.

[?2] README처럼 같은 개수 문구가 여러 줄에 흩어진 파일을 어떻게 검사할지.

지금 `check-harness-docs.sh`는 파일마다 정규식에 매치되는 **첫 번째** 숫자만 보고 통과 판정한다. README는 `SKILL.md 28개`(39행, 맞음)와 `스킬 44개`(11·12·110행, 틀림)가 공존하는데, 지금 로직은 앞의 것만 보고 넘어간다.

- **A. 모든 매치를 검사** — `cmp_num`이 정규식에 걸리는 모든 줄을 순회해 실측값과 다르면 각각 ✗를 낸다. 다운스트림: 스크립트 로직이 조금 더 복잡해지지만, README처럼 같은 개수가 여러 문장에 등장하는 파일에서 낡은 문구가 하나라도 섞이면 확실히 걸린다.
- **B. 문서 문구를 표 형식 한 줄로 통일** — README의 산문 3곳을 지금의 `SKILL.md N개` 같은 한 줄 표기로 바꿔, 검사 대상 문구 자체를 하나로 줄인다. 다운스트림: 스크립트는 안 건드리지만 README 문장을 다시 써야 하고(문서 톤이 바뀜), 나중에 누군가 다시 프로즈로 "스킬 N개"를 쓰면 같은 구멍이 재발한다.

추천은 A다. 문서에서 프로즈로 개수를 언급하는 걸 막을 방법은 없으니, 검사 쪽이 흩어진 표현을 다 쫓아가는 게 "빠뜨리면 알려주는 장치"라는 요구에 더 정확히 맞는다.

[선택 툴로 띄울 항목]
- 질문 1 (`[?1]` 하드코딩 44 처리): "A. 동적 카운트로 전환" / "B. 하드코딩 유지 + 감시 대상 추가"
- 질문 2 (`[?2]` 산재 문구 검사 방식): "A. 모든 매치 검사" / "B. README 문구를 표 형식으로 통일"
