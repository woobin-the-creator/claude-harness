# claude-harness

우빈의 개인 Claude Code 하네스. 스킬·훅·에이전트를 `woobin-harness` 플러그인 하나로 나른다.

Codex 지원은 2026-09-02에 **분리했다.** 매니페스트·훅 wiring·에이전트 형식·검증 스크립트가 런타임마다 두 벌이 되면서 한쪽만 고쳐 조용히 갈라지는 사고가 반복됐다. Codex 하네스는 별도 플러그인 레포가 소유한다 — 이 레포에 Codex 호환 코드를 다시 넣지 마라.

**정본은 `woobin-harness/` 안이다.** `~/.claude/`에 사본을 만들지 마라 — 훅이 이중 발화하고,
어느 쪽이 발화하는지 알 수 없게 된다. 이 레포를 쓰는 머신에서는 `~/.claude/hooks/`가 비어 있는 게 정상이다.

> ⚠️ `home/CLAUDE.md`는 **이 파일이 아니다.** 그 정책 본문은 전역 `~/.claude/CLAUDE.md`로 설치된다.
> 이 파일은 이 레포에서 작업할 때의 지침이다.

## 어디를 읽나

| 하려는 것 | 읽을 것 |
|---|---|
| 레포 구조 · 새 머신 설치 · 원본 머신 전환 절차 | `README.md` |
| 워크플로우가 어떻게 굴러가는지 (사람용 요약) | `docs/workflow.html` |
| 규칙의 근거 · 대가 · **무효화 조건** (모델 재검토용 전문) | `docs/workflow-spec.md` |
| 플랜 구현 모드 3종 | `woobin-harness/plan-exec-modes.md` |
| 개별 훅이 왜 있는지 (사고 이력 포함) | 해당 `woobin-harness/hooks/*.sh` 헤더 주석 |
| 개선 이력의 전체 서사 — 문제·근거·수단·재측정 | `home/HARNESS-LOG.md` |
| 역량 채점 이력·추세 | `docs/scores/SCORES.md` |
| 채점 루브릭·절차 | `woobin-harness/skills/capability-audit/` |

## 고칠 때 같이 고쳐야 하는 것

문서가 4종(README · workflow.html · workflow-spec.md · 훅 헤더)이라 한 곳만 고치면 조용히 갈라진다.
실제 사고 이력이 있다 — 스킬에서 문구를 지웠는데 훅에 하드코딩된 사본이 남아, 없어진 스킬을 5회 더 권했다.

- **훅 · 에이전트를 수정** → `docs/workflow-spec.md` §3의 해당 규칙 + §4 인벤토리 표
- **규칙을 신설** → §3에 `무효화 조건`을 **반드시** 채운다. 못 채우면 아직 규칙이 아니다
- **환경 전제(§1 E1~E10)가 바뀐 걸 발견** → 규칙보다 §1을 먼저 고친다. 규칙 절반이 거기 매달려 있다
- **훅 트리거 경로·용어를 변경** → `HARNESS-LOG.md` 끝의 의존 관계 표. 경로가 바뀌면 훅이 **조용히 죽는다**
- **스킬·에이전트·훅 개수가 변함** → `plugin.json`·`marketplace.json`·README의 개수 문구
- **채점 루브릭의 밴드·가중치를 변경** → `rubric-v2.md`를 **새로 만들고** v1은 남긴다.
  덮어쓰면 과거 점수의 근거가 사라져 이력 전체가 해석 불가가 된다
- **무엇이든 수정한 뒤** → `woobin-harness/.claude-plugin/plugin.json`의 `version`을 올린다. **이 머신도 예외가 아니다** —
  설치본은 `~/.claude/plugins/cache/<mp>/<plugin>/<version>/`에 **버전별로 굳은 복사본**이라,
  버전을 안 올리면 레포를 고쳐도 설치본은 옛날 그대로다(2026-08-08에 스킬을 추가하고 이걸 놓쳤다).
  ⚠️ **올릴 번호가 캐시에 이미 있는지 먼저 봐라** — 레포의 `version`이 설치본보다 **뒤처져 있을 수 있다**
  (다른 브랜치에서 설치했으면 그렇게 된다). 그 상태에서 레포 값에 +1 하면 **이미 굳은 디렉터리**에
  떨어져서 갱신이 조용히 안 된다. 2026-08-19 실제로 레포 1.5.0 · 설치본 1.6.0이라 1.6.0이 막혀 있었다:

  ```bash
  ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/          # 굳은 버전 목록
  jq -r '.plugins["woobin-harness@woobin-harness"][].version' \
     ~/.claude/plugins/installed_plugins.json                        # 지금 켜져 있는 버전
  ```

- **`output-styles/`를 추가·수정** → 파일은 플러그인이 나르지만 **켜는 스위치는 못 나른다.**
  `~/.claude/settings.json`의 `outputStyle`과 `bootstrap.sh` ③의 jq 병합을 **둘 다** 봐라.
  하나만 고치면 새 머신에서 스타일이 목록에는 보이는데 적용은 안 된다

```bash
# 레포 수정 → 반영까지. 이 순서가 아니면 조용히 옛 버전이 돈다.
claude plugin marketplace update woobin-harness
claude plugin update woobin-harness@woobin-harness   # ⚠️ 짧은 이름은 "not found"로 실패한다
# 그리고 Claude Code 재시작 (update가 "Restart to apply"라고 알려준다)
```

## 검증

```bash
claude plugin validate ./woobin-harness   # YAML frontmatter 파싱 실패는 이 명령만 잡는다
./scripts/test-hooks.sh                   # 훅 13개 결정론적 분기 fixture
./scripts/test-skills.sh                  # 스킬 자산 구문·참조·로컬 실행 fixture
./scripts/test-agents.sh                  # 에이전트 이름 ↔ frontmatter model·effort 일치
DRY_RUN=1 ./bootstrap.sh                  # 새 머신 설치가 무엇을 건드리는지
```

`claude plugin validate`를 건너뛰지 마라. 에이전트 frontmatter의 `description:` 안에 콜론+공백이 들어가면
YAML이 스칼라를 매핑으로 파싱해 **모든 frontmatter 필드가 조용히 날아간다** — 런타임은 더 관대해서
정상으로 보이므로 이 명령이 유일한 탐지 수단이다(2026-08-08 `Explore.md`에서 실제 발생).

## 요약본을 하나 더 만들지 마라

`workflow.html`(사람) · `workflow-spec.md`(모델 재검토) 둘로 충분하다. 세 번째 요약을 만들면
같은 워크플로우를 서술하는 소유자가 셋이 되고, 위의 "같이 고쳐야 하는 것"이 지켜지지 않는 순간
어느 게 사실인지 판정할 수 없어진다. 이 파일은 **라우팅과 소유권만** 담는다 — 내용을 서술하지 않는다.
## Context Isolation (Subagent Rule)

Keep the main context window lean. When this environment provides subagent tooling (Claude Code `Task`, or equivalent), use it to isolate context-heavy work. If no subagent tooling exists, ignore this section.

1. **Delegate large read-only output.** Route codebase/document exploration whose raw output is expected to exceed a few thousand tokens (multi-file reads, broad searches, document/log dumps) and browser screenshot loops (Playwright etc.) to a subagent. Quick lookups of one or two files stay in the main context.
2. **Dispatch self-contained prompts.** Subagents have no access to this conversation. Every dispatch must carry the goal, exact paths or search terms, constraints, and the expected return format.
3. **Return summaries with references.** Subagents report a concise summary with `path:line` references (plus one final screenshot for visual checks) so specifics can be re-read on demand without re-exploration.
4. **Verify in the main context.** Final user-facing verification — last diff review and final screenshot — is performed directly by the main agent. Subagent reports are input, not proof.
