---
slug: remove-writing-plans
confirmed_at: 2026-10-01
issue: "#41"
spec_review: spec-reviewer 1회(2026-10-01, plan-doc-reviewer-opus-medium로 대행) — findings 17건 반영
---

# writing-plans 완전 삭제 + 기본 경로를 스펙 파일 ↔ 리뷰 2회로 교체

## Problem

이슈 #41의 A/B 실측 2회(2026-09-28 Godot M1, 2026-10-01 pholex 대시보드)에서 writing-plans 경로는
자유 구현보다 비용 1.8~2.7배, 시간 2~3배였고 품질 우위는 계획서가 아니라 **독립 리뷰**에서 나왔다.
계획 경로는 에이전트 6개(`plan-implementer-*` 3, `plan-reviewer`, `plan-doc-reviewer-*` 2)·훅 3개·문서 4종이
함께 움직여야 하는 유지비를 가진다. 이 레포는 "한쪽만 고쳐 조용히 갈라지는" 사고 이력이 있다(Codex 분리, 훅 하드코딩 사본).

## Goals

1. writing-plans 스킬과 그 실행 기계(플랜 전용 에이전트 6개·훅 3개·`plan-exec-modes.md`)를 레포에서 제거한다.
2. 기본 경로를 `interview → 스펙 파일 → spec-reviewer → /clear → 한 세션 구현(draft PR 회복점) → code-reviewer → e2e 증명 → ready`로 바꾼다.
   스펙 파일 하나가 세 단계를 꿰는 유일한 산출물이다.
3. 리뷰 2회는 둘 다 **전용 에이전트 프로필**이다(frontmatter가 model·effort를 소유).
4. `subagent-model-default.sh`(R3)의 기본 모델을 sonnet → **opus**로 바꾼다.
5. 문서 4종·개수 문구·테스트·버전을 동기화한다.

## Non-goals

- 세션 하나를 넘는 크기 작업·병렬 트랙·마이그레이션용 대체 수단은 만들지 않는다. 필요해지면 git 이력에서 복원한다.
- 3번째 A/B 재측정.
- 훅으로 리뷰를 강제하는 장치(리뷰 호출은 지시문으로만).
- `superpowers` 등 외부 플러그인 설정 변경. `sdd-orchestrator-edit-guard.sh`의 모드 [A](superpowers SDD 원장)·[B] 로직은 그대로 둔다.
- 과거 플랜 디렉터리(`docs/woobin_plan/plans/**`)·`experiments/**`·`history/**` 정리.

## Decisions

| # | 결정 | 고른 것 | 근거 | 기각 — 이유 |
|---|------|---------|------|-------------|
| 1 | writing-plans 처리 | 완전 삭제 | 사용자 선택 | 조건부 축소 — 거의 안 쓰는 경로의 4종 문서 동기화 의무가 남고 #25(미트리거 스킬) 악화 |
| 2 | 리뷰 구조 | 구현 전 스펙 문서 리뷰 1회 + 구현 후 코드 리뷰 1회 | 사용자 선택 | 코드 리뷰 1회만 — 1차 실측에서 "빈틈 찾기" 이득(기본값 13·충돌 6·재검토 19)이 구현 전 단계에서 나왔다 |
| 3 | 리뷰 수단 | 둘 다 전용 에이전트 (`spec-reviewer`, `code-reviewer`). 호출은 항상 네임스페이스 `woobin-harness:spec-reviewer` / `woobin-harness:code-reviewer` | 사용자 선택 | 내장 `/code-review` — 스펙 대조 축이 없다. 2차 실측에서 B를 이긴 결함(드래그 폭 키 공유)은 스펙 대조로 잡혔다. mattpocock `code-review` — 서드파티 의존 |
| 4 | R3 기본 모델 | sonnet → opus | 사용자 선택 | sonnet 유지 — 2026-07-30 비용 근거($25/일)는 기록으로 남기되, 사용자가 리뷰·탐색 품질을 우선했다 |
| 5 | spec-reviewer 티어 | 1종, opus·medium. `plan-doc-reviewer-opus-medium`을 개명·재작성 | 추천안 기본값 | 2종(medium/xhigh) — #39의 티어링 근거는 모드 ③ 라우팅이었고 모드가 사라지면 근거도 사라진다. 되돌리기 쌈 |
| 6 | code-reviewer | `plan-reviewer`를 개명·재작성. effort low → medium | 추천안 기본값 | low 유지 — 레이어마다 돌던 게 기능당 1회로 줄어 올려도 총비용이 늘지 않는다. HARNESS-LOG에 재확인 가정으로 기록 |
| 7 | 리뷰 호출 방식 | 지시문. spec-reviewer는 interview 스킬이 직접 호출, code-reviewer는 스펙 Acceptance criteria 템플릿 기본 항목 | 추천안 기본값 | 훅 재배선(`plan-saved-session-boundary`를 `specs/` 경로로) — 훅 하드코딩 사본이 갈라진 사고 이력 |
| 8 | 플랜 훅 3개 | 복구 없이 삭제 | 추천안 기본값 | 7과 동일 |
| 9 | 스펙 파일 저장 조건 | 구현할 작업이면 **항상** `docs/woobin_plan/specs/YYYY-MM-DD-<slug>-design.md` | 추천안 기본값 | 기존 3조건(요청·오래 삶·세션 인계) — 스펙 파일이 플랜 디렉터리를 대체하는 유일한 인계 산출물이 되므로 조건부일 수 없다 |
| 10 | workflow-spec 규칙 | R1·R2·R7·R8·R15·R19를 삭제가 아니라 **폐기 표시**(날짜·사유). R12·R20의 R15/writing-plans 참조 문구 갱신. R3 제목·근거·env 문구를 opus로 갱신 | 추천안 기본값 (리뷰 반영) | 삭제 — 루브릭 v1 보존 원칙과 같은 이유로 과거 결정의 근거를 남긴다 |
| 11 | kick-off 상태 | `spec → impl` 2단계(`plan` 삭제). **interview 스킬이 스펙 파일을 저장하는 순간** `.claude/kickoff.local.md`가 있으면 `stage: impl`로 쓴다 | 추천안 기본값 (리뷰 반영) | 구현 세션이 전환 — 구현 세션은 스펙 파일만 받으므로 상태 파일을 모른다 |
| 12 | 버전 | 1.22.0 → 1.23.0 | 캐시에 1.22.0만 있음 | — |
| 13 | R15 절차의 후계 | 구현 세션 절차로 축소해 **interview 스킬 "구현 세션으로 넘기기" 절**이 소유: 첫 턴에 브랜치 + 스펙 파일 커밋 + push + **draft PR**(회복 진입점), 논리 단위 커밋, 마지막에 `explain`으로 제목·본문 서사 → `gh pr ready`. 머지는 사용자. 커밋/push 주체 분리는 폐기(한 세션) | 추천안 기본값 (리뷰 반영) | 절차 전부 폐기 — 2시간짜리 단일 세션도 하드 컷 위험은 같다. `stale-branch-guard.sh`의 draft PR 하향 로직이 이 절차에 기대고 있어 유지한다 |
| 14 | 새 규칙 | workflow-spec §3에 **R23 — 기본 경로는 스펙 파일 + 리뷰 2회** 신설. 무효화 조건: (a) 세션 하나를 넘는 작업이 와서 단일 세션 구현이 2회 연속 실패 → 분할 수단을 git에서 복원 검토, (b) 3번째 A/B에서 계획 경로가 비용·품질 모두 우세 → R23 폐기, (c) spec-reviewer findings가 3회 연속 0건 → 스펙 리뷰 단계 제거 검토 | 추천안 기본값 | — |

## Acceptance criteria

구현 세션은 아래를 위에서부터 그대로 검사한다. 행 번호는 적지 않는다 — AC10의 grep이 정본이다.

1. **삭제됨**: `woobin-harness/skills/writing-plans/`(SKILL.md, plan-document-reviewer-prompt.md), `woobin-harness/plan-exec-modes.md`,
   에이전트 `plan-implementer-sonnet-xhigh.md`·`plan-implementer-sonnet-medium.md`·`plan-implementer-opus-xhigh.md`·`plan-doc-reviewer-opus-xhigh.md`,
   훅 `plan-session-boundary-guard.sh`·`plan-saved-session-boundary.sh`·`sdd-kickoff-guard.sh`와 `claude-hooks.json`의 그 배선 3건.
2. **개명·재작성**: `plan-reviewer.md` → `agents/code-reviewer.md`(opus·medium·`tools: Read, Grep, Glob, Bash`·maxTurns 30), 입력은 스펙 파일 경로 + diff 범위,
   정확성·Acceptance criteria 대조·레포 관례 3축. `plan-doc-reviewer-opus-medium.md` → `agents/spec-reviewer.md`(opus·medium·같은 tools), 입력은 스펙 파일 경로,
   출력은 `Status / Findings / Recommendations`(Gates 줄 없음). 체크리스트는 `skills/interview/spec-reviewer-prompt.md`에 **새로 쓴다**(모호함·검증 가능성·레포 사실 충돌·빈틈·범위 확장·CLAUDE.md 준수).
3. **interview/SKILL.md**: "writing-plans로 넘기기" 절과 본문의 writing-plans·플랜 언급(원장 파일 조건 3가지, "플랜의 기각-대안 절" 등)을 결정 9·11·13의 내용으로 교체.
   스펙 파일 Acceptance criteria 템플릿에 "자동 e2e로 증명하고 새 clone에서 재현"과 "`woobin-harness:code-reviewer` 1사이클 findings를 PR 본문에 처리 결과와 함께 기록" 기본 항목.
4. **R3 훅**: `DEFAULT_MODEL=${SUBAGENT_DEFAULT_MODEL:-opus}`, 헤더에 2026-10-01 변경 사유. `scripts/test-hooks.sh`의 `== "sonnet"` 단언을 `"opus"`로.
5. **참조 정리**(AC10 grep으로 검사): `kickoff-guard.sh`(plan 단계·writing-plans 문구), `kick-off/SKILL.md`(stage 3단계 → 2단계), `explain/SKILL.md`, `bootstrap.sh`,
   `stale-branch-guard.sh` 주석의 소유자 참조, `sdd-orchestrator-edit-guard.sh` deny 메시지의 `task-N.md` 문구와 `PLAN_DOCS_DIRS`에 `specs` 포함,
   `CLAUDE.md` 라우팅 표의 plan-exec-modes 행 → interview 절로, "훅 13개 결정론적 분기 fixture" → 10개, `README.md` 전 구간.
6. **개수·설명 문구**: 스킬 19 · 에이전트 4(Explore, screenshot-verifier, spec-reviewer, code-reviewer) · 훅 10 — `plugin.json`(description 문구 "플랜 세션 경계·구현 모드"도 새 경로로), `marketplace.json`, `README.md`, `docs/workflow.html`(모드 정본 문장 재작성), `docs/workflow-spec.md` §4.
7. **문서**: `docs/workflow-spec.md` 결정 10·14 반영 + §4 인벤토리(훅 10·에이전트 4·스킬 19) + §1 E6 등 R3 관련 전제 갱신. `docs/workflow.html`의 모드·플랜 서술을 새 경로로.
   `home/HARNESS-LOG.md`에 #41 실측 요약·이 변경·결정 6의 재확인 가정, 끝의 의존 관계 표에서 삭제된 훅 3행 제거.
8. `plugin.json` version = `1.23.0`.
9. **테스트**: `scripts/test-hooks.sh`에서 삭제 훅 3개의 fixture 제거. `scripts/test-agents.sh`의 MODES 표·plan-exec-modes 인용 검사·REVIEWERS 검사를 "spec-reviewer·code-reviewer가 존재하고 model=opus·effort=medium·tools에 Edit/Write 없음" 검사로 교체.
   전부 통과: `claude plugin validate ./woobin-harness`, `./scripts/test-hooks.sh`, `./scripts/test-skills.sh`, `./scripts/test-agents.sh`, `./scripts/check-harness-docs.sh`.
10. **잔존 참조 0건**:
    ```bash
    git grep -nE 'writing-plans|plan-exec-modes|plan-implementer|plan-reviewer|plan-doc-reviewer|00-overview|task-N\.md|docs/woobin_plan/plans|sdd-kickoff-guard|plan-session-boundary-guard|plan-saved-session-boundary' \
      -- . ':!docs/woobin_plan/plans' ':!docs/woobin_plan/specs' ':!experiments' ':!history' ':!home/HARNESS-LOG.md' ':!docs/scores' ':!docs/workflow-spec.md'
    ```
    `docs/workflow-spec.md`는 별도로: 위 패턴이 **폐기 표시된 규칙 본문과 §5 이력** 안에서만 나온다.
11. **code-reviewer 1사이클**: 구현 후 `woobin-harness:code-reviewer`(이 PR에서는 개명 전 `plan-reviewer`로 대행 가능)에 스펙 경로 + `origin/main..HEAD`를 넘겨 받은 findings와 처리 결과를 PR 본문 "### 리뷰" 절에 기록.

## Rejected alternatives

Decisions 표 참조.

## Provenance

- 이슈 #41 본문(2026-09-30)과 댓글(2026-10-01) — A/B 실측 2회
- Explore 서브에이전트 의존 관계 조사(2026-10-01)
- 스펙 리뷰 1회(2026-10-01) — 결정 10·11·13·14와 AC 1·4·5·9·10·11을 보강
- 사용자 선택: 결정 1~4. 나머지는 추천안 기본값

## Open questions

없음.
