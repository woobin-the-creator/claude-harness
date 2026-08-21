확정했습니다.

**확정 사항**
- Q1 → **② 사용자 선택.** 이미 1.10.0을 쓰는 세션에서도 다시 안 떴다고 보고 진행합니다. 그래서 이번 계획엔 "병합 후 잔여 버그가 있는지 재현 테스트"까지 넣습니다(단순 브랜치 동기화로 끝난다고 가정하지 않습니다).
- Q2 → **② 기본값 확정** (추천안대로). `git cherry-pick 2392e8b`로 훅 로직만 받고, 두 plugin.json은 이 브랜치의 현재 최고값(1.11.0) 기준으로 1.12.0으로 나란히 올립니다.
- Q3 → **① 기본값 확정** (추천안대로). `docs/workflow-spec.md`와 `scripts/test-hooks.sh`까지 이번 작업 범위에 넣습니다.

**기각한 대안**
- Q1① (구버전 세션에서의 낡은 실패로 간주, 병합만 하고 끝) — 기각. 사용자가 "이미 1.10.0에서도 다시 안 떴다"고 확인했으므로, 병합만으로 끝난다고 전제하면 실제 잔여 버그를 놓칠 위험이 큽니다.
- Q2① (`git merge main`로 그대로 받고 codex 버전이 1.11.0→1.10.0으로 내려간 채 두다가 나중에 재상향) — 기각. 이미 쓰인 버전(1.10.0)으로 되돌아가는 중간 상태를 히스토리에 남기는 게 이 레포 `CLAUDE.md`가 명시적으로 경고하는 "굳은 버전에 떨어지는" 사고 패턴과 같은 모양이라, 처음부터 다음 빈 번호(1.12.0)로 가는 ②를 택했습니다.
- Q3② (문서·테스트 동기화를 후속 작업으로 미룸) — 기각. 이 프로젝트에 "스킬에서 문구를 지웠는데 훅에 하드코딩된 사본이 남아 없어진 스킬을 5회 더 권했다"는 실측 사고 이력이 있어, 지금 문서를 안 고치면 같은 유형의 드리프트가 재발할 게 거의 확실합니다.

---

writing-plans 스킬로 넘어가서 계획을 저장하겠습니다.

**저장 위치:** `docs/woobin_plan/plans/2026-08-21-plan-hook-not-firing.md`

```markdown
# 플랜 저장 세션 경계 훅 복구 Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `prepare/new-work` 브랜치에서 죽어 있는 `plan-saved-session-boundary.sh`를 main의 기존 수정으로 복구하고, 버전·문서·테스트를 동기화하고, 병합 후에도 재발하는 잔여 버그가 없는지 실제로 확인한다.

**Architecture:** main 커밋 `2392e8b`가 이미 올바른 훅 로직을 갖고 있으므로 새로 설계하지 않고 cherry-pick으로 가져온다. 그 위에 이 브랜치 고유의 버전 드리프트(codex 1.11.0)를 반영해 두 plugin.json을 재동기화하고, 문서·테스트를 갱신한 뒤, 실제 Write 이벤트로 재현 테스트를 돌려 Q1에서 사용자가 우려한 "1.10.0에서도 안 뜬" 잔여 케이스를 마지막에 검증한다.

**Tech Stack:** sh(POSIX) 훅 스크립트, jq, git, bash 테스트 하네스(`scripts/test-hooks.sh`)

## Global Constraints

- 훅 스크립트는 POSIX `sh` 문법만 사용한다(`set -u`, `command -v jq` 가드 유지) — 기존 파일 컨벤션.
- `.claude-plugin/plugin.json`과 `.codex-plugin/plugin.json`의 `version`은 항상 같은 값으로 같이 올린다(`CLAUDE.md` 명시 규칙).
- 새 버전 번호를 정하기 전에 `~/.claude/plugins/cache/woobin-harness/woobin-harness/`에 이미 있는 번호를 먼저 확인한다 — 이번 조사 시점 기준 최고 캐시값은 1.10.0, 이 브랜치 codex 쪽 로컬값은 1.11.0이므로 다음 값은 **1.12.0**.
- `claude plugin validate ./woobin-harness`를 스킵하지 않는다.

---

### Task 1: main의 훅 fix를 이 브랜치에 반영

**Files:**
- Modify: `woobin-harness/hooks/plan-saved-session-boundary.sh` (cherry-pick으로 갱신)

**Interfaces:**
- Consumes: 없음(독립 스크립트)
- Produces: `docs/(superpowers|woobin_plan)/plans/.../00-overview.md` 저장 시에만 발화하고 `task-N.md`는 침묵하는 새 판정 로직 — Task 3의 재현 테스트가 이 동작에 의존한다.

- [ ] **Step 1: fix 커밋만 골라 받기**

```bash
git cherry-pick -n 2392e8b
```
`-n`으로 워킹트리에만 적용하고 아직 커밋하지 않는다 — plugin.json 두 개는 이 커밋의 값(1.10.0)이 아니라 Task 2에서 이 브랜치 기준으로 다시 정할 것이기 때문이다.

- [ ] **Step 2: plugin.json 변경분만 되돌리기**

```bash
git checkout HEAD -- woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
```
훅 스크립트 변경만 스테이지에 남긴다.

- [ ] **Step 3: diff 확인**

```bash
git diff --cached -- woobin-harness/hooks/plan-saved-session-boundary.sh
```
Expected: `presplit` 판정 로직과 2026-08-21 날짜 주석이 추가된 diff만 보임. plugin.json 두 파일은 diff에 안 보여야 함.

- [ ] **Step 4: 커밋**

```bash
git commit -m "fix(hooks): plan-saved-session-boundary가 처음부터 분할 저장된 플랜에도 발화하도록 복구 (cherry-pick 2392e8b)"
```

### Task 2: 두 plugin.json 버전 재동기화

**Files:**
- Modify: `woobin-harness/.claude-plugin/plugin.json`
- Modify: `woobin-harness/.codex-plugin/plugin.json`

**Interfaces:**
- Consumes: Task 1에서 확정된 훅 변경 내용(버전 로그/체인지로그가 있다면 여기 반영)
- Produces: 두 파일 모두 `"version": "1.12.0"` — Task 4의 검증 스텝이 이 값을 확인한다.

- [ ] **Step 1: 현재 값 재확인**

```bash
grep version woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/
```
Expected: claude=1.9.0, codex=1.11.0, 캐시 최고값 1.10.0 — 셋 다 1.12.0보다 작음을 확인.

- [ ] **Step 2: 두 파일을 1.12.0으로 올리기**

`woobin-harness/.claude-plugin/plugin.json`과 `woobin-harness/.codex-plugin/plugin.json`의 `"version"` 필드를 `"1.12.0"`으로 수정.

- [ ] **Step 3: 커밋**

```bash
git add woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
git commit -m "chore(harness): plugin.json 버전을 1.12.0으로 동기화 (codex 1.11.0 드리프트 반영)"
```

### Task 3: 문서·테스트 동기화

**Files:**
- Modify: `docs/workflow-spec.md` (§3 훅 서술, §4 인벤토리 표 — `plan-saved-session-boundary.sh` 항목)
- Modify: `scripts/test-hooks.sh` (필요 시 픽스처 추가)

**Interfaces:**
- Consumes: Task 1의 새 훅 동작(00-overview.md에만 발화, task-N.md는 침묵)
- Produces: 없음(문서/테스트만)

- [ ] **Step 1: workflow-spec.md의 옛 서술 확인**

```bash
grep -n "이미 분할한 산출물" docs/workflow-spec.md
```
Expected: "이미 분할한 산출물(plans/<이름>/00-overview.md·task-N.md)에는 다시 발화하지 않는다"는 옛 문장이 나옴 — 이건 이제 틀린 설명이다(00-overview.md에는 여전히 발화한다).

- [ ] **Step 2: 문장 갱신**

해당 문장을 "분할 레이아웃(plans/<이름>/…)에서는 `00-overview.md` 하나에만 발화하고 `task-N.md`는 침묵한다"로 고친다.

- [ ] **Step 3: test-hooks.sh 픽스처 확인/추가**

```bash
grep -n "plan-saved-session-boundary" scripts/test-hooks.sh
```
`00-overview.md` 경로를 입력으로 주는 케이스와 `task-1.md` 경로를 입력으로 주는 케이스(침묵 확인)가 둘 다 있는지 확인한다. 없으면 기존 "plan-saved-session-boundary trigger/once" 블록 옆에 두 케이스를 추가한다.

- [ ] **Step 4: 테스트 실행**

```bash
./scripts/test-hooks.sh
```
Expected: 전부 `pass`.

- [ ] **Step 5: 검증 + 커밋**

```bash
claude plugin validate ./woobin-harness
git add docs/workflow-spec.md scripts/test-hooks.sh
git commit -m "docs(harness): plan-saved-session-boundary의 presplit 발화 규칙을 workflow-spec.md·테스트에 반영"
```

### Task 4: 잔여 버그 재현 테스트 (Q1에서 제기된 우려 검증)

**Files:**
- 없음(수동 재현 — 실제 Claude Code 세션에서 확인)

**Interfaces:**
- Consumes: Task 1~3에서 반영된 훅
- Produces: "1.10.0/1.12.0에서도 여전히 안 뜨는지"에 대한 결론 — 참이면 후속 디버깅 태스크가 필요하다는 판정.

- [ ] **Step 1: 정본 마켓플레이스 디렉터리 갱신 확인**

```bash
cat ~/.claude/plugins/known_marketplaces.json | grep -A3 woobin-harness
```
정본이 `/Volumes/LinuxVM/mac_wb_data/codespace/claude-harness`로 잡혀 있음을 재확인한다 — 이 워크트리(`prepare/new-work`)에서의 수정은 그 디렉터리에도 병합/반영되어야 실제 실행 중인 플러그인에 적용된다. 그 디렉터리가 별도 워크트리라면 거기서도 같은 fix를 받는다.

- [ ] **Step 2: 마켓플레이스·플러그인 갱신**

```bash
claude plugin marketplace update woobin-harness
claude plugin update woobin-harness@woobin-harness
```
그리고 Claude Code를 재시작한다("Restart to apply" 안내를 따른다).

- [ ] **Step 3: 남은 dedup 마커 제거**

```bash
rm -rf "${TMPDIR:-/tmp}/claude-plan-boundary"
```
세션당 1회만 알리는 마커가 이전 실패 시도의 잔재로 남아 재발화를 막고 있을 가능성을 제거한다.

- [ ] **Step 4: 실제 재현**

새 세션에서 `docs/woobin_plan/plans/<임의-slug>/00-overview.md`를 Write로 저장해보고, `[세션 경계 알림]` `additionalContext`가 실제로 뜨는지 확인한다.

Expected: 뜬다. 만약 Task 1~3을 모두 반영하고 재시작·마커 제거까지 했는데도 안 뜨면, 다음을 추가로 점검하는 후속 태스크를 새로 판다 — `jq` 설치 여부, 실행 중인 세션의 `CLAUDE_PLUGIN_ROOT` 실제 값, `woobin-harness/hooks/claude-hooks.json`의 `PostToolUse` matcher(`Write`)가 실제 Write 도구 이름과 정확히 일치하는지.

- [ ] **Step 5: 결론 기록**

재현 테스트 결과를 이 플랜 파일 하단에 한 줄로 남긴다(뜸/안 뜸 + 시각).

---

## Rejected Alternatives

- **`git merge main`로 그대로 받고 버전을 나중에 재상향** — 기각. 이미 쓰인 값(1.10.0)으로 잠깐이라도 되돌아가는 중간 상태가 히스토리에 남는 게 이 레포가 명시적으로 경고하는 "굳은 버전 충돌" 패턴과 같아서, 처음부터 cherry-pick + 새 번호(1.12.0)로 갔다.
- **문서·테스트 동기화를 후속 작업으로 분리** — 기각. 이 실패 유형(훅은 고쳤는데 문서가 옛 서술로 남는 것)이 이미 한 번 실측된 사고(없어진 스킬을 5회 더 권함)라 지금 같이 고치는 비용이 더 싸다.
- **"이미 1.10.0에서도 안 떴다"는 보고를 브랜치 동기화만으로 설명 가능하다고 단정** — 기각. 사용자가 Q1에서 명시적으로 부인했으므로, Task 4의 재현 테스트를 계획에서 빼지 않았다.

---

**모드 추천:** 이 플랜은 태스크 4개가 파일을 공유하며 순서 의존적입니다(Task 1의 훅 변경 → Task 2의 버전 → Task 3의 문서/테스트 검증 → Task 4의 실행 재현). 트랙이 나뉘지 않으므로 **② 절약(medium + sonnet)** 을 추천합니다. 레이어 경계 처리는 태스크 수가 4개로 적고 사람이 재시작·재현 확인을 직접 봐야 하므로 **②a 수동 `/clear`** 를 추천합니다.

이 세션을 종료(`/exit`)하고 이렇게 다시 띄우세요:
```
claude --effort medium --model sonnet
```
그리고 첫 프롬프트:
```
docs/woobin_plan/plans/2026-08-21-plan-hook-not-firing.md 플랜으로 구현 진행해줘 — 모드 ②a
```
```

플랜을 위 경로에 저장했습니다. 이번 세션에서 곧바로 구현을 시작하지 않습니다 — 위 안내대로 `/exit` 후 새 세션에서 이어가 주세요.
