# Codex 플랜 구현 모드 3종

플랜 문서(`docs/woobin_plan/plans/<name>/`)를 Codex에서 실행할 때 고르는 세 가지 형태다. Claude Code의 모델명·`/effort`·`Agent` 계약은 [plan-exec-modes.md](plan-exec-modes.md)가 소유하고, 이 파일은 Codex 계약만 소유한다.

## 모든 모드 공통

**무인 실행 여부는 게이트 수가 정한다.**

플랜 문서 리뷰어가 낸 `**Gates:** N`(사람 확인이 필요한 지점의 수)이 라우팅 입력이다.

| 게이트 | 어디로 | 왜 |
|---|---|---|
| 0개 | ①·②b·③ — **full-auto** | 사람이 끼어들 자리가 없으므로 플랜 세션이 그대로 끝까지 굴린다 |
| 1개 이상 | **②a** | 레이어마다 사람이 필요한 모드다. 이미 상주 전제라 게이트가 공짜로 들어맞는다 |
| 1개 이상 **이면서 ③ 성립 조건** | **③ 유지**, 게이트에서 멈춤 | ③의 방아쇠는 되돌리기 비용이고 ②a는 sonnet·medium이다. 게이트 하나 때문에 마이그레이션 플랜을 강등시키지 않는다 |

게이트는 **상주** 문제고 모드는 **model·effort** 문제다. 두 축이 부딪히면 되돌리기 비용이 이긴다.

**서브에이전트는 물을 수 없다.** `AskUserQuestion`이 모든 서브에이전트에서 제거되므로, 게이트에 닿은
구현자는 멈추고 보고하는 것 말고 할 수 있는 게 없다. full-auto에서 그건 중단이 아니라 **정지**다 —
그래서 게이트 있는 플랜을 무인으로 보내지 않는다.

- 오케스트레이터는 `00-overview.md`만 읽는다. `task-N.md`는 구현 직전 하나씩 읽거나 구현 에이전트에 경로로 넘긴다.
- 모델·effort의 소유자는 둘로 갈린다. **세션**은 `codex -m <model> -c 'model_reasoning_effort="<effort>"'`
  (②a와 플랜 세션 자신). **위임된 구현자**는 자기 프로필 TOML의 `model`·`model_reasoning_effort`가 소유하며,
  호출 쪽에서 덮어쓰지 않는다.
- 태스크 하나당 에이전트 하나로 팬아웃하지 않는다. 순서 의존성이 없는 **트랙** 또는 순차 **레이어**가 위임 단위다.
- 리뷰는 `plan-reviewer` 프로필을 쓰고 `task-N.md` 경로와 diff 범위만 넘긴다. diff 본문을 부모 프롬프트에 복사하지 않는다.
- 구현자에게 별도 “double-check” 루프를 덧붙이지 않는다. 계획의 완료 판정 명령은 실행하되, 독립 리뷰는 `plan-reviewer`가 맡는다.
- **R15(브랜치 · 레이어 커밋 · draft PR · `gh pr ready`)는 Codex에도 그대로 적용된다.** 절차 원문은
  [plan-exec-modes.md](plan-exec-modes.md)의 "중단 대비" 소절이 소유하고, `sdd-kickoff-guard.sh`가
  Codex에도 연결돼 있어 킥오프에 포인터를 낸다. 다만 Claude와 달리 구현자 정의를 이 플러그인이 나르지
  않는다 — Codex 프로필은 `~/.codex` 소유다. 그래서 **레이어 커밋 지시를 프로필 쪽에 넣어두지 않았다면
  ②b·③에서 위임 프롬프트에 한 줄로 넣는다**(Claude에서는 정의가 소유하므로 넣지 않는다). push는 어느
  쪽에도 넣지 않는다 — 리뷰를 돌린 부모가 한다.

## ① 속도 — 독립 트랙 병렬

권장 세션: `gpt-5.6-terra` + `medium`.

**성립 조건:** `00-overview.md`의 의존성 표에서 파일을 공유하지 않는 트랙이 둘 이상일 때만.

- 트랙마다 `plan-implementer-terra-medium` 한 개와 독립 worktree를 배정하고 동시에 실행한다.
- 스폰 직후 `git worktree list`로 실제 격리를 확인한다.
- 부모는 결과 요약과 통합 판정만 담당한다.
- 트랙별 완료 후 `plan-reviewer` 한 번씩 배치한다.

CLI 예시:

```bash
codex -m gpt-5.6-terra -c 'model_reasoning_effort="medium"'
```

## ② 절약 — 순차 실행 (기본값)

권장 세션: `gpt-5.6` + `medium`.

**성립 조건:** 의존성 체인이거나 같은 파일을 공유하는 태스크. 대부분의 플랜이 여기다.

두 경계 전략 중 사용자가 고른다.

### ②a 새 task/`/clear`

- 메인 Codex가 `task-N.md`를 하나씩 읽고 순차 구현한다.
- 레이어가 끝날 때마다 새 task를 열거나 CLI에서 `/clear`하고 `00-overview.md`만 다시 읽는다.
- 추가 에이전트 프리픽스가 없어 가장 싸지만 사용자 개입이 필요하다.

### ②b `plan-implementer-gpt56-medium` 레이어 위임

- 레이어마다 `plan-implementer-gpt56-medium` 프로필 한 개를 **순차로** 띄운다.
- 프롬프트에는 overview 경로와 그 레이어의 `task-N.md` 경로를 실행 순서대로 전달한다.
- 부모는 각 에이전트의 25행 이하 요약만 받고, 확인 게이트가 생기면 사용자에게 올린다.
- 레이어가 셋 이상이거나 사용자가 자리를 비울 때 적합하다.

CLI 예시:

```bash
codex -m gpt-5.6 -c 'model_reasoning_effort="medium"'
```

## ③ 최고 퀄리티 — 고위험 변경 + 독립 리뷰

권장 세션: `gpt-5.6` + `xhigh`.

**성립 조건:** DB 마이그레이션, prod 배포에 닿는 변경, 자동 게이트가 잡지 못하는 UI처럼 되돌리기 비싼 작업.

- 구현은 순차 `plan-implementer-gpt56-xhigh`가 수행한다(게이트가 있으면 그 지점에서 멈춘다).
- 구현 후 `plan-reviewer`를 별도 컨텍스트에서 세 렌즈로 실행한다: 정확성·버그, 계획 완료 판정 대조, repo 표준.
- 리뷰어 결과는 모두 수집한 다음 부모가 중복을 제거하고 심각도를 판정한다.
- 리뷰 프롬프트에는 “심각한 것만”이라고 제한하지 않는다. 전부 보고하게 한 뒤 부모가 거른다.

CLI 예시:

```bash
codex -m gpt-5.6 -c 'model_reasoning_effort="xhigh"'
```

## 선택 결과 전달

게이트가 1개 이상이면 플랜을 저장한 세션에서 구현을 시작하지 않고, 다음 task에서 사용할 모델·effort,
모드 번호, plan 경로를 한 번에 전달한다. 게이트가 0개이면 그 세션이 그대로 full-auto로 굴린다 —
전달할 것이 없다. Claude 전용 `sonnet`·`opus`·`/effort` 문구를 Codex kickoff에 섞지 않는다.

모델·에이전트 선택은 OpenAI 공식 Codex subagent guidance의 역할 구분을 따른다: demanding 작업은 `gpt-5.6`, 빠른 탐색·병렬 보조 작업은 `gpt-5.6-terra`, 일반 구현은 `medium`, 복잡한 검토는 `high` 이상.
