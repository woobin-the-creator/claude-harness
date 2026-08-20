# Codex 호환성 감사 — 2026-08-12

검증 환경: macOS, Codex CLI 0.147.0, Claude Code 2.1.227. 레포의 플러그인 버전은 1.3.2다.

## 결론

플러그인 패키징, 스킬 44개 발견, Codex 에이전트 4개 설치, 공유 훅 스크립트 11개의 결정론적 분기, Codex 안전 훅 4개 wiring은 모두 통과했다. Codex에서 지원하지 않는 구성요소는 조용히 오작동하지 않도록 미연결 또는 명시적 no-op/대체 스킬로 분리했다.

최초 자동 검증은 임시 `CODEX_HOME`에서 실행했다. 후속 마무리에서 실제 `~/.codex`에도 1.3.2를 설치했고, 플러그인 enabled 상태·전역 `AGENTS.md`·에이전트 4개·새 prompt input의 스킬 44개 노출을 다시 확인했다.

## 검증 결과

| 영역 | 결과 | 근거 |
|---|---:|---|
| Codex plugin/marketplace manifest | PASS | 공식 plugin validator + `codex plugin list --json` |
| 스킬 frontmatter | 44/44 PASS | Codex `quick_validate.py` |
| 실제 스킬 발견 | 44/44 PASS | 임시 설치 후 `codex debug prompt-input` 출력과 디렉터리 집합 일치 |
| 전역/프로젝트 지침 | PASS | 같은 prompt input에 `home/CLAUDE.md` 본문과 레포 `AGENTS.md` 본문 모두 존재 |
| Claude 훅 wiring | 11/11 PASS | `claude-hooks.json`이 공유 훅 스크립트 11개를 전부 참조 |
| Codex 훅 wiring | 4/4 PASS | kickoff, doc-sync adapter, stale-branch, Stop ack만 참조; async 설정 없음 |
| 공유 훅 분기 | 11/11 PASS | `scripts/test-hooks.sh`: trigger, once-only, deny/block/ack, 실제 local Git remote 분기 |
| Codex custom agents | 4/4 PASS | TOML 필수 필드·모델·effort·sandbox 파싱, bootstrap 설치 |
| 스킬 실행 자산 | PASS | shell/Python/JS 구문, tar 무결성, Markdown 상대 참조 |
| 네트워크 없는 runtime fixture | PASS | brainstorming 서버 start/serve/stop, token/capability audit, 미디어 추출, 포스트 조립 멱등성 |
| bootstrap/cache | PASS | 임시/실제 `CODEX_HOME`에 1.3.2 설치, 스킬 44개·adapter·hooks 캐시 확인 |
| 실제 사용자 설치 | PASS | `woobin-harness@woobin-harness` 1.3.2가 installed/enabled, custom agent 4개와 전역 `AGENTS.md` 동기화 |

검증 진입점은 `scripts/validate-codex.sh`이다. 개별 fixture는 `scripts/test-hooks.sh`, `scripts/test-skills.sh`로 분리했다.

## Codex 호환 실패/미지원 목록

### 훅 7개 — Codex에 의도적 미연결

| 훅 | 미연결 이유 |
|---|---|
| `idle-handoff-stop.sh` | Codex command hook은 `async` 옵션을 파싱하지만 비동기 실행을 지원하지 않음. 50분 Stop 폴링을 연결하면 턴을 막는다. |
| `ctx-handoff-stop.sh` | Claude transcript의 assistant usage 형태로 토큰을 세므로 Codex의 안정 계약이 아님. |
| `idle-return-guard.sh` | 비동기 idle handoff와 Claude session/close marker 계약의 짝이라 Codex에서는 실행할 대상이 없음. |
| `plan-saved-session-boundary.sh` | Claude `Write` 파일 입력과 Claude 런치 모드 문구를 소유함. Codex에서는 `writing-plans` + `plan-exec-modes-codex.md`가 대체한다. |
| `plan-session-boundary-guard.sh` | Claude transcript usage를 사용한 120k 임계 판정에 의존. |
| `sdd-orchestrator-edit-guard.sh` | Claude `Edit/Write/MultiEdit` payload와 메인 오케스트레이터 카운터 계약에 의존. |
| `subagent-model-default.sh` | Claude `Agent/Task` payload에 `sonnet/opus/haiku`를 주입함. Codex 에이전트 TOML이 모델을 소유한다. |

위 스크립트 자체는 모두 fixture를 통과했다. 실패는 스크립트 파손이 아니라 **Codex에서 해당 자동화가 활성화되지 않는다**는 뜻이다.

### 스킬 3개 — 호스트 전용 또는 대체 경로

| 스킬 | Codex 판정 |
|---|---|
| `buddy` | Claude Buddy MCP/플러그인 전용. Codex에 해당 MCP가 없으면 작동하지 않으며 description이 자동 호출을 제한한다. |
| `git-guardrails-claude-code` | `.claude/settings.json` 전용. Codex에서는 `git-guardrails-codex`를 사용한다. |
| `close-session` | Codex에 idle handoff가 없으므로 명시적 no-op. 세션 id를 추측하거나 Claude cleanup을 실행하지 않는다. |

## 조건부/라이브 통합 미검증

아래는 Codex 패키징 실패가 아니라 외부 프로그램, 인증, 네트워크, 실제 서비스가 필요한 경로다.

- `explain` PNG renderer: JavaScript 구문은 통과했고 Google Chrome은 있지만, 이 레포 CWD에서 `playwright` 모듈을 resolve할 수 없어 live render는 미실행.
- `tutor-setup` PDF 경로: 현재 `pdftotext` 미설치. text/Markdown/codebase 경로와는 독립적이다.
- GitHub/PR/브라우저 스킬: `gh`는 인증되어 있지만 실제 issue/PR 작성·push는 감사 범위에서 외부 상태를 바꾸므로 실행하지 않음.
- `web-artifacts-builder`: Node, pnpm, 번들 tarball은 존재하고 구문/무결성은 통과. 실제 scaffold는 npm 네트워크 설치를 하므로 미실행.
- Codex custom agent: TOML 로드와 실제 사용자 홈 설치는 통과했지만 새 대화에서 live model spawn은 미실행.
- Codex command hooks: 정의·입출력 fixture와 실제 플러그인 설치는 통과했지만, 앱 재시작 후 `/hooks` 신뢰 검토가 필요하므로 데스크톱 턴에서의 end-to-end 발화는 미실행.

## 재검토 트리거

- Codex가 asynchronous command hooks를 지원하면 `idle-handoff-stop.sh`를 우선 재검토한다.
- Codex transcript usage의 안정 schema가 공개되면 context/plan boundary 2개를 재검토한다.
- Codex subagent hook에서 model 미지정 조건을 안전하게 판정·rewrite할 수 있으면 model default 훅을 재검토한다.
- 호환 레이어를 바꾸면 `./scripts/validate-codex.sh`를 다시 실행한다.

공식 계약 근거: [Codex hooks](https://learn.chatgpt.com/docs/hooks), [Codex skills](https://learn.chatgpt.com/docs/build-skills), [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), [Codex plugins](https://developers.openai.com/plugins/build/plugins).
