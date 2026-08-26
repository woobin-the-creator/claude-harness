# claude-harness

Claude Code와 Codex에서 **직접 만든 하네스만** 공유하는 레포. 새 머신에 스킬·훅·에이전트·전역 지침을 한 번에 옮기기 위한 것이다.

`~/.claude`는 총 1.6G인데 그중 손으로 만든 건 약 1MB다. 나머지는 전부 재설치·재생성되는 것(플러그인 1.0G, 세션 트랜스크립트 557M)이거나 절대 커밋하면 안 되는 것(`.credentials.json`)이다.

## 형태 — 왜 dotfiles 심링크가 아니라 플러그인인가

공통 스킬은 같은 `woobin-harness/skills/`를 Claude Code와 Codex 플러그인이 함께 나른다. 런타임 계약이 다른 훅과 에이전트만 얇은 호환 레이어로 분리한다.

- Claude Code: `/plugin install`이 스킬 44개·에이전트 4개·훅 12개를 붙인다.
- Codex: 플러그인이 스킬 44개와 검증된 훅 4개를 붙이고, `bootstrap-codex.sh`가 커스텀 에이전트 4개와 전역 `AGENTS.md`를 설치한다.

심링크 방식(`~/.claude`를 통째로 또는 항목별로 링크)이 흔한 관행이지만, 설정 파일을 심링크하면 알려진 문제가 셋 있다 — 전부 anthropics/claude-code에 버그로 등록됐고 **봇이 닫았을 뿐 수정 근거는 없다**:

| 이슈 | 증상 |
|---|---|
| [#3575](https://github.com/anthropics/claude-code/issues/3575) | 심링크된 `settings.json`에서 퍼미션 allow가 무시되고 `ls`·`cat`이 수 초 지연 |
| [#40857](https://github.com/anthropics/claude-code/issues/40857) | Write가 심링크를 실파일로 교체 → 원본과 조용히 갈라짐 |
| [#25367](https://github.com/anthropics/claude-code/issues/25367) | 심링크된 `skills/`에서 `Error: Unknown skill: X` |

플러그인 경로는 심링크를 **한 개도** 쓰지 않으므로 이 셋이 통째로 무관해진다.

## 구조

```
claude-harness/
├── .claude-plugin/marketplace.json   ← 이 레포를 마켓플레이스로 등록
├── .agents/plugins/marketplace.json  ← Codex 레포 마켓플레이스
├── woobin-harness/                   ← 플러그인 본체
│   ├── .claude-plugin/plugin.json
│   ├── .codex-plugin/plugin.json
│   ├── hooks/claude-hooks.json       Claude Code 훅 12개
│   ├── hooks/hooks.json              Codex가 자동 발견하는 안전한 훅 4개
│   ├── hooks/*.sh                    12개 (공유 훅 스크립트)
│   ├── lib/*.sh                      훅이 부르는 헬퍼 — wire 안 되므로 훅 개수에 안 센다
│   ├── scripts/                      런타임 입력 어댑터
│   ├── agents/*.md                   4개
│   ├── skills/<name>/SKILL.md        19개
│   ├── output-styles/                 스타일 2개 + ATTRIBUTION.md·LICENSE (fluent-korean 계열)
│   ├── plan-exec-modes.md            Claude Code 구현 모드 3종 — 훅이 ${CLAUDE_PLUGIN_ROOT}로 찾는다
│   └── plan-exec-modes-codex.md      Codex 모델·effort·에이전트 대응본
├── codex/agents/*.toml               Codex 커스텀 에이전트 4개
├── CLAUDE.md                         이 레포 작업 지침 — 라우팅·소유권만 (내용 서술 없음)
├── AGENTS.md                         Codex가 읽는 라우터 — CLAUDE.md를 정본으로 가리킨다
├── docs/workflow.html                사람이 보는 워크플로우 요약
├── docs/workflow-spec.md             ↑의 전문 — 미래 모델에게 재검토시킬 때 통째로 준다
├── home/                             전역 ~/.claude/ 사본 — CLAUDE.md · HARNESS-LOG.md · RTK.md
│                                     (home/CLAUDE.md ≠ 위의 CLAUDE.md. 스코프가 다르다)
├── statusline/ctx-warn-statusline.sh
├── agents-skill-lock.json            ~/.agents/.skill-lock.json 사본
├── bootstrap.sh                      Claude Code 플러그인이 못 나르는 것만 처리
└── bootstrap-codex.sh                Codex 플러그인이 못 나르는 것만 처리
```

**플러그인이 못 나르는 것** — Claude Code의 전역 `CLAUDE.md`·statusline·설정·`outputStyle`은 `bootstrap.sh`가, Codex의 전역 `AGENTS.md`·사용자 커스텀 에이전트는 `bootstrap-codex.sh`가 처리한다.

출력 스타일은 이 구분이 갈라지는 자리라서 한 번 더 적어둔다. **스타일 파일 자체는 플러그인이 나르지만, 그중 무엇을 켤지 정하는 `outputStyle` 키는 플러그인이 못 건드린다.** 그래서 파일은 `woobin-harness/output-styles/`에 있고 활성화는 `bootstrap.sh` ③이 한다. 둘 중 하나만 옮기면 새 머신에서 스타일이 목록에는 보이는데 적용은 안 되는 상태가 된다.

### Codex 훅이 4개인 이유

Codex는 Claude 호환 환경변수와 훅 입출력 대부분을 지원하지만 비동기 command hook은 아직 실행하지 않는다. 또 `apply_patch`는 Claude의 `Write/Edit`와 입력 모양이 다르고, transcript 포맷은 안정 계약이 아니다. 그래서 Codex에는 다음만 연결했다.

| 훅 | Codex 처리 |
|---|---|
| `sdd-kickoff-guard.sh` | 동일한 `UserPromptSubmit` 계약으로 그대로 사용 |
| `harness-doc-sync-guard.sh` | `codex-apply-patch-adapter.sh`가 `file_path`를 정규화한 뒤 사용 |
| `stale-branch-guard.sh` | 플러그인 데이터 디렉터리에 마커 저장 |
| `stop-warning-ack-guard.sh` | Codex의 `last_assistant_message`로 응답 검사 |

idle handoff 3종, plan-session 경계 2종, SDD 편집 가드, subagent model 주입은 Codex에서 fail-open이 아니라 **미연결**이다. 비동기 미지원, 불안정 transcript token 계측, 서로 다른 모델 이름·subagent payload를 억지로 흉내 내지 않는다.

제품 UI 작업은 `design-workflow`가 신규 방향·기존 시스템 증분 변경·리뷰·반복 실패를 먼저 분류하고, 필요한 디자인 모듈만 읽는다. `DESIGN.md`는 선택적이다.

## 새 머신에 올리기

```bash
git clone <this-repo> ~/codespace/claude-harness
cd ~/codespace/claude-harness
DRY_RUN=1 ./bootstrap.sh    # 먼저 뭘 하는지 본다
./bootstrap.sh
```

그리고 Claude Code를 재시작한 뒤 `/plugin`에서 `woobin-harness`가 enabled인지 확인한다.

### Codex

```bash
cd ~/codespace/claude-harness
DRY_RUN=1 ./bootstrap-codex.sh
./bootstrap-codex.sh
```

스크립트가 로컬 마켓플레이스를 등록하고 `woobin-harness@woobin-harness`를 설치한다. ChatGPT 데스크톱 앱을 재시작한 뒤 Plugins Directory에서 활성 상태를 확인한다. 새 Codex 대화에서는 `/hooks`를 열어 플러그인 훅을 검토·신뢰해야 command hook이 실제로 실행된다.

Codex 플러그인만 레포 안에서 시험하려면 이 레포의 `.agents/plugins/marketplace.json`을 쓰면 된다. 다른 레포에서도 쓰려면 `bootstrap-codex.sh`가 실행하는 `codex plugin marketplace add <repo-path>`와 `codex plugin add woobin-harness@woobin-harness`가 필요하다.

## 검증

```bash
claude plugin validate ./woobin-harness
./scripts/test-hooks.sh
./scripts/test-skills.sh
./scripts/validate-codex.sh
DRY_RUN=1 ./bootstrap.sh
DRY_RUN=1 ./bootstrap-codex.sh
./scripts/check-harness-docs.sh
```

`validate-codex.sh`는 위의 두 fixture를 다시 실행하고, 임시 `CODEX_HOME`에 플러그인을 설치한 뒤 실제 `codex debug prompt-input`에서 스킬 44개와 전역·프로젝트 `AGENTS.md`가 노출되는지까지 검사한다. 상세 결과와 의도적 미지원 목록은 [`docs/codex-compatibility-audit-2026-08-12.md`](docs/codex-compatibility-audit-2026-08-12.md)에 있다.

Codex 훅은 설치 후 `/hooks` 신뢰 검토까지 해야 end-to-end 검증된다. 로컬 구조·입출력 검증은 플러그인·스킬 validator와 결정론적 fixture가 담당한다.

## 일부러 안 담은 것

| 항목 | 이유 |
|---|---|
| `skills/` 심링크 61개 | `~/.agents/skills`(k-skill 마켓플레이스)를 가리킨다. 그대로 커밋하면 새 머신에서 **깨진 심링크 61개**가 되고 스킬을 조용히 못 읽는다. `agents-skill-lock.json` + k-skill 재실행으로 복원한다 |
| `plugins/` (1.0G) | `settings.json`의 `enabledPlugins`·`extraKnownMarketplaces`가 재설치를 유도한다 |
| `projects/` (557M) | 세션 트랜스크립트 |
| `.credentials.json` · `.claude.json` | **절대 커밋 금지** |
| `hooks/`의 wire 안 된 잔재 | `rtk-rewrite.sh`, `.bak-260804` 2개, 설계 메모 `.md` 2개.<br>`close-session-cleanup.sh`는 2026-08-12에 **잔재가 아니었음이 드러나** 플러그인으로 옮겼다 — `idle-return-guard.sh`가 절대경로로 부르고 있었고, 레포에 없어서 원본 머신 밖에서는 훅이 조용히 아무 일도 안 했다 |
| `skills/_backup-mattpocock-260804` | 백업 사본 |
| 외부 훅 3종 | `claude-buddy`(별도 레포) · `orca`(설치물) · `gptaku-update-check.cjs`(플러그인 부산물). `bootstrap.sh`가 체크리스트로 안내한다 |

## 원본 머신 — 2026-08-08 전환 완료

이 레포를 만든 머신은 이미 `~/.claude`에 같은 것들을 갖고 있었다. 중복을 아래처럼 정리했다.
**새 머신에서는 이 절을 따라 하지 마라** — 대상 런타임의 bootstrap만 돌리면 된다.

| 대상 | 처리 | 왜 |
|---|---|---|
| 훅 9개 | `settings.json` 엔트리 제거 + 스크립트를 `~/.claude/hooks/.pre-plugin-260808/`로 이동 | 안 지우면 **이중 발화**한다 |
| `plan-exec-modes.md` | 같은 백업 디렉터리로 이동 | 훅이 `${CLAUDE_PLUGIN_ROOT}` 동봉본을 쓴다. 두 곳이 소유하면 드리프트 난다 |
| 에이전트 4개 | `~/.claude/agents/`에 **그대로 둠** | 사용자 정의가 동명 플러그인 에이전트를 **override**한다 → 중복 비용 없음 |
| 스킬 41개 | `skillOverrides`에 `"woobin-harness:<name>": "off"` 41건 | 플러그인 스킬은 `/woobin-harness:name`으로 **네임스페이스**돼서 `~/.claude/skills`의 것과 **둘 다 살아난다.** 그대로 두면 always-on ~6.9k tok을 매 세션 이중으로 문다. off로 끄면 슬래시 이름(`/grill-me`)이 그대로 유지된다 |

> 전환 **이후에 추가한 스킬**은 이 표의 41건에 포함되지 않는다. `~/.claude/skills/`에 사본이 없으므로
> `skillOverrides`도 필요 없고, 이 머신에서 **`/woobin-harness:<name>`으로 호출**한다.
> 사본을 만들어 짧은 이름을 얻으려 하지 마라 — 소유자가 둘이 된다. 첫 사례: `capability-audit`.

되돌리기:

```bash
cp ~/.claude/settings.json.pre-plugin-260808 ~/.claude/settings.json
mv ~/.claude/hooks/.pre-plugin-260808/*.sh ~/.claude/hooks/
mv ~/.claude/hooks/.pre-plugin-260808/plan-exec-modes.md ~/.claude/
```

## 갱신

**`CLAUDE.md`를 봐라.** 정본 위치, 무엇을 고치면 무엇을 같이 고쳐야 하는지, 검증 명령이 거기 있다.
같은 규약을 여기에 복제하면 두 곳이 소유하게 되므로 옮겨뒀다.
