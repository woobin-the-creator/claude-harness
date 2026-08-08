# claude-harness

우빈의 개인 Claude Code 하네스. 훅·에이전트·스킬을 `woobin-harness` 플러그인으로 나른다.

**정본은 `woobin-harness/` 안이다.** `~/.claude/`에 사본을 만들지 마라 — 훅이 이중 발화하고,
어느 쪽이 발화하는지 알 수 없게 된다. 이 레포를 쓰는 머신에서는 `~/.claude/hooks/`가 비어 있는 게 정상이다.

> ⚠️ `home/CLAUDE.md`는 **이 파일이 아니다.** 그건 전역 `~/.claude/CLAUDE.md`(모든 프로젝트에 적용되는
> 개인 지침)의 사본이고, 이 파일은 이 레포에서 작업할 때의 지침이다. 이름이 같으니 고칠 때 확인해라.

## 어디를 읽나

| 하려는 것 | 읽을 것 |
|---|---|
| 레포 구조 · 새 머신 설치 · 원본 머신 전환 절차 | `README.md` |
| 워크플로우가 어떻게 굴러가는지 (사람용 요약) | `docs/workflow.html` |
| 규칙의 근거 · 대가 · **무효화 조건** (모델 재검토용 전문) | `docs/workflow-spec.md` |
| 플랜 구현 모드 3종 | `woobin-harness/plan-exec-modes.md` |
| 개별 훅이 왜 있는지 (사고 이력 포함) | 해당 `woobin-harness/hooks/*.sh` 헤더 주석 |
| 개선 16건의 전체 서사 — 문제·근거·수단·재측정 | `home/HARNESS-LOG.md` |

## 고칠 때 같이 고쳐야 하는 것

문서가 4종(README · workflow.html · workflow-spec.md · 훅 헤더)이라 한 곳만 고치면 조용히 갈라진다.
실제 사고 이력이 있다 — 스킬에서 문구를 지웠는데 훅에 하드코딩된 사본이 남아, 없어진 스킬을 5회 더 권했다.

- **훅 · 에이전트를 수정** → `docs/workflow-spec.md` §3의 해당 규칙 + §4 인벤토리 표
- **규칙을 신설** → §3에 `무효화 조건`을 **반드시** 채운다. 못 채우면 아직 규칙이 아니다
- **환경 전제(§1 E1~E10)가 바뀐 걸 발견** → 규칙보다 §1을 먼저 고친다. 규칙 절반이 거기 매달려 있다
- **훅 트리거 경로·용어를 변경** → `HARNESS-LOG.md` 끝의 의존 관계 표. 경로가 바뀌면 훅이 **조용히 죽는다**
- **스킬·에이전트·훅 개수가 변함** → `plugin.json`·`.claude-plugin/marketplace.json`·README의 개수 문구
- **무엇이든 수정한 뒤** → `plugin.json`의 `version`을 올려야 다른 머신이 업데이트를 받는다

## 검증

```bash
claude plugin validate ./woobin-harness   # YAML frontmatter 파싱 실패는 이 명령만 잡는다
DRY_RUN=1 ./bootstrap.sh                  # 새 머신 설치가 무엇을 건드리는지
```

`claude plugin validate`를 건너뛰지 마라. 에이전트 frontmatter의 `description:` 안에 콜론+공백이 들어가면
YAML이 스칼라를 매핑으로 파싱해 **모든 frontmatter 필드가 조용히 날아간다** — 런타임은 더 관대해서
정상으로 보이므로 이 명령이 유일한 탐지 수단이다(2026-08-08 `Explore.md`에서 실제 발생).

## 요약본을 하나 더 만들지 마라

`workflow.html`(사람) · `workflow-spec.md`(모델 재검토) 둘로 충분하다. 세 번째 요약을 만들면
같은 워크플로우를 서술하는 소유자가 셋이 되고, 위의 "같이 고쳐야 하는 것"이 지켜지지 않는 순간
어느 게 사실인지 판정할 수 없어진다. 이 파일은 **라우팅과 소유권만** 담는다 — 내용을 서술하지 않는다.
