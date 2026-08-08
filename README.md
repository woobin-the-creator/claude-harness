# claude-harness

`~/.claude`에서 **손으로 만든 것만** 담은 레포. 새 머신에 하네스를 한 번에 옮기기 위한 것이다.

`~/.claude`는 총 1.6G인데 그중 손으로 만든 건 약 1MB다. 나머지는 전부 재설치·재생성되는 것(플러그인 1.0G, 세션 트랜스크립트 557M)이거나 절대 커밋하면 안 되는 것(`.credentials.json`)이다.

## 형태 — 왜 dotfiles 심링크가 아니라 플러그인인가

훅·에이전트·스킬은 **Claude Code 플러그인**이 나른다. `/plugin install` 하나로 전부 붙는다.

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
├── woobin-harness/                   ← 플러그인 본체
│   ├── .claude-plugin/plugin.json
│   ├── hooks/hooks.json              settings.json의 hooks 객체를 옮긴 것
│   ├── hooks/*.sh                    9개 (wire된 것만)
│   ├── agents/*.md                   4개
│   ├── skills/<name>/SKILL.md        43개
│   └── plan-exec-modes.md            훅이 ${CLAUDE_PLUGIN_ROOT}로 찾는다
├── home/                             CLAUDE.md · HARNESS-LOG.md · RTK.md
├── statusline/ctx-warn-statusline.sh
├── agents-skill-lock.json            ~/.agents/.skill-lock.json 사본
└── bootstrap.sh                      플러그인이 못 나르는 것만 처리
```

**플러그인이 못 나르는 것** — 플러그인의 `settings.json`은 `agent`·`subagentStatusLine` 두 키만 지원한다. 그래서 `~/.claude/CLAUDE.md`(글로벌 지침), `statusLine`, `permissions`는 `bootstrap.sh`가 처리한다.

## 새 머신에 올리기

```bash
git clone <this-repo> ~/codespace/claude-harness
cd ~/codespace/claude-harness
DRY_RUN=1 ./bootstrap.sh    # 먼저 뭘 하는지 본다
./bootstrap.sh
```

그리고 Claude Code를 재시작한 뒤 `/plugin`에서 `woobin-harness`가 enabled인지 확인한다.

## 일부러 안 담은 것

| 항목 | 이유 |
|---|---|
| `skills/` 심링크 61개 | `~/.agents/skills`(k-skill 마켓플레이스)를 가리킨다. 그대로 커밋하면 새 머신에서 **깨진 심링크 61개**가 되고 스킬을 조용히 못 읽는다. `agents-skill-lock.json` + k-skill 재실행으로 복원한다 |
| `plugins/` (1.0G) | `settings.json`의 `enabledPlugins`·`extraKnownMarketplaces`가 재설치를 유도한다 |
| `projects/` (557M) | 세션 트랜스크립트 |
| `.credentials.json` · `.claude.json` | **절대 커밋 금지** |
| `hooks/`의 wire 안 된 잔재 | `rtk-rewrite.sh`, `close-session-cleanup.sh`, `.bak-260804` 2개, 설계 메모 `.md` 2개 |
| `skills/_backup-mattpocock-260804` | 백업 사본 |
| 외부 훅 3종 | `claude-buddy`(별도 레포) · `orca`(설치물) · `gptaku-update-check.cjs`(플러그인 부산물). `bootstrap.sh`가 체크리스트로 안내한다 |

## 갱신

훅·에이전트·스킬을 고칠 땐 **플러그인 쪽을 고치는 게 정본**이다. `~/.claude/hooks/`에 사본이 남아 있으면 둘 중 어느 쪽이 발화하는지 헷갈린다 — 플러그인으로 전환한 뒤에는 `~/.claude/hooks/`의 9개와 `settings.json`의 해당 hooks 엔트리를 지운다.

`plugin.json`의 `version`을 올려야 다른 머신이 업데이트를 받는다.
