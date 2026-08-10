# 레이어 경계 커밋 + 리뷰 후 push + draft PR 회복 진입점 (R15) — 구현 플랜

> **에이전트 작업자용:** 새 세션에서(`/clear` 먼저 — 이 플랜을 쓴 대화는 구현에 필요 없고, 남겨두면 매 요청에 재청구된다) 태스크 순서대로 구현한다. 오케스트레이터는 **이 파일만** 읽는다. `task-N.md`는 구현 직전에 하나씩 읽거나 서브에이전트에 경로로 넘긴다.

**Goal:** 플랜 구현 중 **사용량 하드 컷**으로 세션이 끊겼을 때, 다음 세션이 "어디까지 했는지"를 잃지 않게 하는 절차를 규칙 R15로 신설하고 하네스 문서·훅을 동기화한다.

**Architecture:** 훅을 **하나도 추가하지 않는다.** R15는 절차이고, 전달 경로는 이미 있다 — `plan-exec-modes.md`를 킥오프 훅이 읽게 만들기 때문이다. 코드 변경은 기존 훅 `stale-branch-guard.sh` **수정 1건**뿐이고, 나머지는 문서 4종 동기화다. 규칙 본문(근거·대가·무효화 조건)은 `docs/workflow-spec.md` §3이 단일 소유하고, 실행 절차는 `woobin-harness/plan-exec-modes.md`가 단일 소유한다 — 서로 복제하지 않고 참조한다.

**Tech Stack:** POSIX sh (훅), Markdown (spec·모드 파일·이력), HTML (사람용 요약), `gh` CLI, `jq`.

## 이 플랜은 자기 자신을 도그푸딩한다

R15가 정의하는 절차대로 이 플랜을 구현한다 — 즉 **첫 커밋이 이 플랜 문서**이고, `plan-wip` 라벨이 붙은 draft PR을 먼저 연다. 규칙이 아직 문서에 없는 상태에서 절차를 먼저 밟는 것이므로 순환이 아니다. Layer 0이 그것이다.

## Global Constraints

- 정본은 `woobin-harness/` 안이다. `~/.claude/`에 사본을 만들지 않는다.
- **훅 신설 0개.** 이번 변경은 기존 훅 수정 1건(`stale-branch-guard.sh`)뿐이다.
- 새 규칙에는 **무효화 조건을 반드시 채운다.** 못 채우면 아직 규칙이 아니다(`CLAUDE.md`).
- **같은 문장을 두 곳이 소유하지 않는다**(spec §6-6). R15 본문 = `workflow-spec.md` §3, 절차 = `plan-exec-modes.md`. 상호 참조만 하고 복제하지 않는다.
- 요약본을 새로 만들지 않는다. 기존 4종(`README.md` · `docs/workflow.html` · `docs/workflow-spec.md` · 훅 헤더)만 고친다.
- `woobin-harness/`를 고쳤으면 `woobin-harness/.claude-plugin/plugin.json`의 `version`을 올린다. 현재 **`1.3.0`** → **`1.4.0`**.
- 훅·에이전트·스킬 **개수는 바뀌지 않는다**(훅 11 · 에이전트 4 · 스킬 25). 개수 문구를 건드리지 마라.
- 최종 게이트: `scripts/check-harness-docs.sh`가 **✗ 0건**, `claude plugin validate ./woobin-harness` 통과.

## 태스크 목록

| # | 제목 | 대상 파일 | 완료 판정 |
|---|---|---|---|
| 1 | `workflow-spec.md` §3에 R15 신설 | `docs/workflow-spec.md` (R14 뒤, §4 앞) | `grep -c "^### R15" docs/workflow-spec.md` = 1, 무효화 조건 4항목 존재 |
| 2 | 같은 파일의 §4·§7·§8 갱신 | `docs/workflow-spec.md` | §4 stale-branch 행에 `plan-wip`, §7-A에 기각 7행, §8에 O14~O16 |
| 3 | 실행 절차를 모드 파일에 신설 | `woobin-harness/plan-exec-modes.md` | 공통 절에 "중단 대비" 소절 + 모드별 차이 3줄 |
| 4 | `stale-branch-guard.sh` 등급 하향 | `woobin-harness/hooks/stale-branch-guard.sh` | `sh -n` 통과 + 두 경로 스모크 테스트 |
| 5 | 사람용 요약·이력·버전 동기화 | `docs/workflow.html` · `home/HARNESS-LOG.md` · `plugin.json` | version `1.4.0`, HARNESS-LOG `## 20.` 존재 |
| 6 | 검사기·validate 통과 확인 | (읽기 전용 + 사용자 실행 안내) | `check-harness-docs.sh` exit 0, validate 통과 |

## 태스크 간 순서 의존성

```
Layer 0 : 브랜치 + 플랜 커밋 + draft PR          (task 없음 — 절차. 아래 "Layer 0" 절 참조)
Layer 1 : task-1 → task-2      (둘 다 docs/workflow-spec.md 단일 파일 — 반드시 순차)
Layer 2 : task-3, task-4       (서로 다른 파일이지만 둘 다 L1이 확정한 R15 문구를 참조 — L1 이후)
Layer 3 : task-5 → task-6      (task-5가 만든 변경을 task-6이 검사)
```

**병렬 트랙은 0개다.** L1의 두 태스크가 같은 파일을 공유하고, L2·L3는 앞 레이어의 산출물을 참조한다. → 모드 ② 계열.

## Layer 0 — 구현 첫 턴에 이것부터 한다

```bash
git switch -c plan/2026-08-10-layer-commit-draft-pr
git add docs/woobin_plan/plans/2026-08-10-layer-commit-draft-pr/
git commit -m "docs(plan): 레이어 경계 커밋 + draft PR 회복 진입점 구현 시작"
git push -u origin plan/2026-08-10-layer-commit-draft-pr
gh pr create --draft --label plan-wip \
  --title "R15: 레이어 경계 커밋 + 리뷰 후 push + draft PR 회복 진입점" \
  --body "플랜: \`docs/woobin_plan/plans/2026-08-10-layer-commit-draft-pr/\`
진행 상태: \`git log --oneline\`

- [ ] L1 workflow-spec.md (R15 신설 + §4·§7·§8)
- [ ] L2 plan-exec-modes.md + stale-branch-guard.sh
- [ ] L3 workflow.html + HARNESS-LOG + plugin.json + 검사기 통과
- [ ] 머지 전 플랜 디렉터리 삭제(권장)"
```

`plan-wip` 라벨이 레포에 없으면 먼저 만든다: `gh label create plan-wip --description "구현 중인 플랜 브랜치" --color FBCA04`

**이미 열린 `plan-wip` PR이 있으면 그것을 먼저 처리한다** — 열린 plan-wip PR은 워크트리당 1개다.

## 각 레이어가 끝날 때 (L1·L2·L3 공통)

순서를 지킨다: **커밋 → 리뷰 → (수정) → push**

1. `git add -A && git commit -m "<type>(L<n>): <레이어 요약>"` — 리뷰 **전**이다.
2. `plan-reviewer` 1회. 넘기는 것은 `task-N.md` **경로**와 `main..HEAD` **범위**뿐이다(diff 본문 금지).
3. 지적 사항을 고치고 `git commit --amend` 또는 fixup 커밋.
4. `git push` + PR 코멘트 **5행 이내**로 그 레이어에서 발견한 것(플랜에 없던 사실, 고친 완료 판정 등). 커밋 body에 쓰지 않는다 — squash가 날린다.

### 누가 무엇을 하나 (모드에 따라 다르다 — 태스크 파일은 1번까지만 지시한다)

`plan-implementer`에는 **`Agent` 툴이 없다** — 리뷰어를 띄울 수 없다. 그래서 소유자가 갈린다:

| 모드 | 1 커밋 | 2 리뷰 | 3 수정 | 4 push + 코멘트 |
|---|---|---|---|---|
| ②b (레이어 위임) | 레이어 구현자 | **오케스트레이터** | 오케스트레이터 | **오케스트레이터** |
| ②a (수동 `/clear`) | 메인 루프 | 메인 루프 | 메인 루프 | 메인 루프 (`/clear` 직전) |

②b에서 이 분리는 우연이 아니다 — 커밋과 push의 소유자를 갈라두면 **"리뷰 전에는 원격에 안 올라간다"가 절차가 아니라 구조로 보장된다.** 구현자에게 push를 시키지 마라.

## 기각한 대안과 사유

| 대안 | 기각 사유 |
|---|---|
| **task 단위 커밋** | 하드 컷은 파일을 지우지 않는다 — 워킹 트리는 디스크에 남는다. 잃는 건 코드가 아니라 "어디까지 했는지"라는 **기록**이므로 커밋의 역할은 보존이 아니라 **라벨링**이고 레이어 해상도로 충분하다. 게다가 ②a에서 git 출력이 오케스트레이터 floor에 쌓여 매 요청에 재청구된다(레이어 커밋은 `/clear` 직전이라 한 턴만 산다) |
| **리뷰 통과 후 커밋** | 레이어 끝의 리뷰가 그 세션에서 토큰을 가장 많이 쓰는 단계라 **하드 컷 확률이 가장 높은 지점**이다. 거기서 커밋을 기다리면 레이어 전체가 가장 위험한 순간에 무기록으로 노출된다. 커밋은 로컬이고 무료다 |
| **발견 노트를 커밋 message body에** | squash merge가 body를 사실상 날린다. push가 리뷰 후의 의도된 순간이므로 PR 코멘트가 같은 값을 더 싸게 준다 |
| **플랜을 커밋하지 않고 `--allow-empty`로 PR 열기** | untracked 파일은 새 워크트리에 따라오지 않는다 → 모드 ①의 트랙 워크트리에 플랜 문서가 없다. 지금 `docs/woobin_plan/`이 untracked인 상태가 그 지뢰다 |
| **플랜을 레포 밖(`~/.claude/plans/`)에 두기** | `plan-saved-session-boundary.sh`의 경로 정규식이 `/docs/(superpowers\|woobin_plan)/plans/`다. 옮기면 플랜 분할·모드 선택 기계가 **통째로 조용히 죽는다** |
| **레이어 경계에서 더러운 트리를 검사하는 훅** | 훅 신설 0개로 시작한다. 전달 경로가 이미 있다(모드 파일은 킥오프 훅이 읽게 만든다). §6-2("소프트 지시로 못 막는 건 구조를 바꾼다")는 **실패가 관측된 뒤** 적용하는 규율이고, R13도 statusline 경고 → 실패 재측정 → 훅 순서였다 |
| **오래된 plan-wip PR 자동 폐기(cron/CI)** | 이 레포엔 CI가 없고 새 소유자가 하나 늘어난다. 검사 시점을 "새 플랜 시작 시"로 옮기면 필요한 순간에만 발생한다 |
| **머지 전 플랜 삭제를 규칙으로 강제** | 잊었을 때 피해가 main 트리의 디렉터리 하나이고 되돌릴 수 있다. 디렉터리 이름의 날짜 접두어와 `plans/` 경로가 이미 "현재 설계가 아님"을 표시한다 → **권장**으로 둔다 |
| **`stale-branch-guard`를 plan 브랜치에서 면제** | 정말 방치된 브랜치를 놓친다. 경고·마커·ack 게이트를 유지하고 **문구만** 하향한다 |
| **`gh` 실패 시 graceful degrade 경로 설계** | 모델 호출 자체가 네트워크다 — "오프라인 구현"은 존재하지 않는 시나리오다. 원격이 없는 레포에서는 이 규칙 전체가 비적용이라고 명시하면 끝난다 |

## 알아야 하는 레포 사실 (구현 중 재확인 불필요)

- `docs/woobin_plan/`은 현재 **untracked**다. `.gitignore`에는 `.DS_Store`·`*.bak`·`*.orig`·`*.bak-*`만 있다. 플랜 문서가 커밋된 이력은 **0건**이다(`git log --diff-filter=A -- 'docs/*/plans/*'` 비어 있음).
- 이 레포에 **CI가 없다**(`.github/workflows` 부재). draft push가 워크플로우를 돌리지 않는다.
- `statusline/ctx-warn-statusline.sh`는 **컨텍스트만** 센다. 사용량 잔량을 읽는 코드가 없고 훅 입력에도 없다 → 하드 컷 사전 경고는 만들 수 없다.
- `hooks.json`의 SessionStart에는 **matcher가 없다** → `/clear`에도 발화한다. 그래서 ②a의 레이어 경계마다 `stale-branch-guard`가 뜬다(task-4가 겨누는 것).
- `scripts/check-harness-docs.sh`의 동반 수정 규칙: `woobin-harness/hooks/`가 바뀌면 `docs/workflow-spec.md` 미변경은 **✗**, `docs/workflow.html` 미변경은 훅 **추가**일 때만 ✗이고 **수정**이면 ⚠, `home/HARNESS-LOG.md` 미변경은 ⚠, `plugin.json` version 미변경은 **✗**.
