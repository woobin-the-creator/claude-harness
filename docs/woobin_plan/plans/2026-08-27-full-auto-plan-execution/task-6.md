### Task 6: Doc sync, version bump, machine cleanup

Four documents describe this workflow and none of them knows about any of the previous five tasks. `./scripts/check-harness-docs.sh` mechanically enforces most of it; the rest is listed here because it counts things that script does not.

**Files:**
- Modify: `docs/workflow-spec.md` (R1 at line 107, R7 at line 259, §4 at lines 689-706, §5 mode table at line 806, §8 at line 900)
- Modify: `README.md` (lines 11, 12, 43, and the 검증 code block at line 99)
- Modify: `docs/workflow.html` (lines 196, 322, 356-359, 421)
- Modify: `home/HARNESS-LOG.md` (요약 표 at line 44, new §31 before the `## 규율` section)
- Modify: `CLAUDE.md` (the 검증 code block)
- Modify: `woobin-harness/.claude-plugin/plugin.json`, `woobin-harness/.codex-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Interfaces:**
- Consumes: everything from Tasks 1-5.
- Produces: nothing.

---

- [ ] **Step 1: Bump both plugin versions to `1.17.0`**

Not `1.16.0`. Confirm first, because the repo value trails the installed one:

```bash
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/
jq -r '.plugins["woobin-harness@woobin-harness"][].version' ~/.claude/plugins/installed_plugins.json
```

Expected: the cache directory listing includes `1.16.0` while both repo manifests say `1.15.0`. Installed versions are frozen per-directory copies, so writing `1.16.0` lands in an existing frozen directory and the update silently does nothing. Set both `woobin-harness/.claude-plugin/plugin.json` and `woobin-harness/.codex-plugin/plugin.json` to `"version": "1.17.0"`. If the listing shows something above `1.16.0`, go one minor above the highest instead and say so in the commit message.

- [ ] **Step 2: Update the count strings**

Agents went 4 → 6 on both hosts. Change every one of these:

| File | Line | From | To |
|---|---|---|---|
| `woobin-harness/.claude-plugin/plugin.json` | 3 | `에이전트 4개` | `에이전트 6개` |
| `.claude-plugin/marketplace.json` | 11 | `에이전트 4개` | `에이전트 6개` |
| `README.md` | 11 | `스킬 21개·에이전트 4개·훅 13개` | `스킬 21개·에이전트 6개·훅 13개` |
| `README.md` | 12 | `커스텀 에이전트 4개와 전역 AGENTS.md` | `커스텀 에이전트 6개와 전역 AGENTS.md` |
| `README.md` | 38 | `agents/*.md                   4개` | `agents/*.md                   6개` |
| `README.md` | 43 | `Codex 커스텀 에이전트 4개` | `Codex 커스텀 에이전트 6개` |
| `docs/workflow-spec.md` | 689 | `### 에이전트 4개` | `### 에이전트 6개` |
| `docs/workflow.html` | 421 | `<b>Codex 에이전트 4개</b>` | `<b>Codex 에이전트 6개</b>` |

**Do not touch `README.md:135`** (`| 에이전트 4개 | ~/.claude/agents/에 그대로 둠 |`). That row is the 2026-08-08 원본 머신 transition record — it describes what was true then, and rewriting history there makes the table a lie.

- [ ] **Step 3: Rewrite the `docs/workflow-spec.md` §4 agent table**

Delete the `plan-implementer` row and add three. The `model`/`effort` columns are no longer `없음(의도)`:

```markdown
| `plan-implementer-sonnet-xhigh` | sonnet | xhigh | 60 | `local` | 모드 ①. 트랙 단위 worktree 위임 |
| `plan-implementer-sonnet-medium` | sonnet | medium | 60 | `local` | 모드 ②b. **대부분의 플랜이 여기다** |
| `plan-implementer-opus-xhigh` | opus | xhigh | 60 | `local` | 모드 ③. 되돌리기 비싼 변경 |
```

Then fix the sentence under the table. It currently reads `**frontmatter의 부재가 의도인 곳이 3군데다.** 리뷰어가 "빠졌다"고 판단해 채우면 설계가 깨진다.` — two of those three were `plan-implementer`'s `model` and `effort`, and they are now filled on purpose. Replace with:

```markdown
**frontmatter의 부재가 의도인 곳이 1군데 남았다** — `plan-reviewer`의 `memory`. 리뷰어가 "빠졌다"고
판단해 채우면 Read/Write/Edit가 자동 활성화돼 "편집 불가"가 깨진다.

구현자 3종의 `model`·`effort`는 반대로 **반드시 채워져 있어야 한다.** `Agent` 호출에 effort 인자가
없고 full-auto에는 세션 재런치가 없어서, frontmatter가 유일한 운반 수단이다. 파일명이 그 값을 한 번 더
주장하므로 `scripts/test-agents.sh`가 둘의 일치를 기계로 센다(규율 6 — 이름을 두 번째 소유자로 두지 않는다).
```

Finally update the Codex sentence at the end of §4: `Codex 대응본은 codex/agents/*.toml 4개다` → `6개다`, and replace `plan-implementer는 gpt-5.6/medium` with `plan-implementer-terra-medium은 gpt-5.6-terra/medium, plan-implementer-gpt56-medium은 gpt-5.6/medium, plan-implementer-gpt56-xhigh는 gpt-5.6/xhigh`.

- [ ] **Step 4: Narrow R1 and split R7**

R1 (line 107) currently says the mechanism is an `/exit` + relaunch instruction for every plan. Change its **기전** paragraph to:

```markdown
**기전** `plan-saved-session-boundary.sh` (PostToolUse:Write). 플랜 저장을 감지 → 자기완결성 4항목 점검
+ 플랜 문서 리뷰어 지시 + 게이트 수 라우팅. **경계를 실제로 넘는 것은 게이트가 1개 이상인 플랜뿐이다**
(→ ②a: `/exit` 후 `claude --effort medium --model sonnet` 재런치). 게이트 0개면 그 세션이 그대로
full-auto로 구현까지 굴린다 — 이 규칙의 적용 범위가 2026-08-27에 여기까지 좁혀졌다.
```

and add one bullet to its **무효화 조건**:

```markdown
- 게이트 있는 플랜의 비율이 충분히 낮아져 ②a 경로 자체가 안 쓰이게 됨 → 규칙이 죽은 코드가 된다
```

Leave R1's **근거** untouched. The measurement is still what justifies the orchestrator staying lean; it just no longer justifies a relaunch for every plan.

R7 (line 259) currently claims effort·model are fixed by launch flags, full stop. Change its **기전** to:

```markdown
**기전** `plan-exec-modes.md` 공통 규칙. 소유자가 둘이다 — **세션**은 `claude --effort <level> --model <model>`
(②a와 플랜 세션 자신), **위임된 구현자**는 에이전트 정의 frontmatter다. `Agent` 호출에 effort 인자가
없어서 다른 수단이 없고, full-auto에는 상속을 기댈 세션 재런치도 없다. 어느 쪽이든 **중간에 바꾸지 않는다**가
불변의 핵심이다. `/effort`는 쓰지 않는다 — interactive 세션에서 `effortLevel`에 **영구 저장**되어
되돌리기를 사람이 기억해야 하고, startup에 적용되지 않는 미해결 버그가 있다(anthropics/claude-code#45453).
```

and add to its **무효화 조건**: `- `Agent` 호출이 effort 인자를 받게 됨 → 변이체 3종을 하나로 되돌려라`.

- [ ] **Step 5: Add the gate column to the §5 mode table**

The table at line 806 gains a column. Replace the header and body rows with:

```markdown
| 모드 | 런치 | 성립 조건 | 위임 | 게이트 0개일 때 |
|------|------|-----------|------|------|
| ① 속도 | `--effort xhigh --model sonnet` | 파일을 공유하지 않는 트랙 2개 이상. 트랙 1개면 ②보다 비싸기만 하다 | `plan-implementer-sonnet-xhigh`, 트랙 worktree, **순차 스폰** | full-auto |
| ②a 절약 | `--effort medium --model sonnet` | 의존 체인. **게이트가 1개 이상인 플랜은 전부 여기다** | 없음. 레이어마다 `/clear` | (해당 없음 — 상주 모드) |
| ②b 절약·무인 | 세션 플래그 없음 | 의존 체인 + 게이트 0개 | 레이어마다 `plan-implementer-sonnet-medium` 순차 | full-auto |
| ③ 최고품질 | `--effort xhigh --model opus` | 되돌리기 비싼 것 — DB 마이그레이션, prod 배포, 자동 게이트가 못 잡는 UI | `plan-implementer-opus-xhigh` + 리뷰어 3개(렌즈 분리), 순차 | full-auto. 게이트가 있어도 ②a로 강등하지 않고 게이트에서 멈춘다 |
```

Add one paragraph under it:

```markdown
**게이트는 상주 축, 모드는 model·effort 축이다.** 플랜 문서 리뷰어가 낸 `**Gates:** N`이 라우팅 입력이고,
0이면 플랜 세션이 그대로 끝까지 굴린다. 1개 이상이면 ②a인데, ③ 성립 조건이 걸리면 ③이 이긴다 —
되돌리기 비용이 상주 편의보다 강한 신호다. 서브에이전트는 `AskUserQuestion`이 제거돼 게이트에서 물을 수
없으므로, 무인으로 보낸 게이트는 중단이 아니라 **정지**가 된다.
```

- [ ] **Step 6: Add the open measurements to §8**

Extend O1's cell with `변이체 3종으로 갈라진 뒤 memory 파편화도 미측정 — 세 디렉터리가 같은 레포 환경 사실을 각자 다시 배운다.` and add one row:

```markdown
| O19 | **full-auto 오케스트레이터가 무는 플래닝 프리픽스** | 산술 추정만 있다. R1 실측(죽은 잔재 ~155k)에 요청 ~18회를 곱하면 2.7M cache read — opus 오케스트레이터 기준 ~$4/플랜, 태스크당 $2.57~2.82 기준선에서 10태스크 플랜의 ~15%. 실측 안 했다. `token-waste-audit`으로 full-auto 세션과 ②a 세션을 전후 비교할 수 있다 |
```

- [ ] **Step 7: Update `docs/workflow.html`**

`check-harness-docs.sh` fails the run if agents were added and this file did not change, and it is right to — the human summary currently describes a workflow that no longer exists.

- Line 196: the step that says `이 세션을 <b>종료</b>하고 모드에 맞는 플래그로 다시 띄운다.` now applies only to ②a. Prefix it with `게이트가 1개 이상이면 —` and add a sibling sentence: `게이트가 0개면 이 세션이 그대로 구현까지 굴린다. 종료하지 않는다.`
- Line 322: the `확인이 필요하면 서브에이전트는 못 묻는다` card already states the constraint. Append: `그래서 게이트가 하나라도 있으면 무인 실행 대상에서 빠진다 — 무인에서 그건 중단이 아니라 정지다.`
- Lines 356-359: the delegation table rows say `plan-implementer` and `모드 ②a·③ — 메인 루프가 직접`. Change the agent cell to `plan-implementer-sonnet-medium` / `-sonnet-xhigh` / `-opus-xhigh` and the last cell to `모드 ②a — 메인 루프가 직접`.

- [ ] **Step 8: Add the `HARNESS-LOG.md` entry**

Append a row to the 요약 표. It currently ends at `24` even though entries run to 30 — add only `31` and leave the gap; backfilling 25-30 is not this plan's job.

```markdown
| 31 | 08-27 | 플랜→구현 사이에 사람이 매번 한 번 끼어야 했고, 그 개입의 정체는 **effort 레버 하나**였다 | 구현자를 model·effort 고정 변이체 3종으로 + 게이트 0개면 플랜 세션이 full-auto, 게이트 있으면 ②a | (신규 — 다음 5개 플랜의 follow-up fix PR 건수) |
```

Then a `## 31.` section before `## 규율`, in the shape the surrounding entries use (계기 / 왜 / 조치 / 안 한 것 / 재측정). It must record at least these facts, because nothing else in the repo will:

- The lever being removed was `--effort`. `/clear` already drops context in-session and `/model` already switches models; the relaunch existed because `Agent` has no effort argument and `/effort` persists to `settings.json` (#45453).
- `docs/workflow-spec.md` §4 marked `plan-implementer`'s missing `model`/`effort` as **의도** — it was load-bearing on R1's relaunch. Removing the relaunch made the intentional absence wrong, which is the "환경 전제가 바뀌면 규칙보다 전제를 먼저 고친다" case.
- The Codex side had already hardcoded `gpt-5.6/medium` in `codex/agents/plan-implementer.toml`, so `plan-exec-modes-codex.md`'s mode ③ had been silently running at medium since the port. This change closes that drift.
- Three pholex cases sized the plan-review step before it was made unconditional: #230→#233 (a Global Constraint with no file scope produced 119 lines of unplanned policy test, deleted four days later — a plan review would likely have caught it), #231→#234 (Alembic 023 shipped with completion checks that only parsed files; the migration had never succeeded anywhere — the adjacent plan defect was catchable, the type bug was not), #231→#235 (the plan was correct and the implementer invented a CSS class that did not exist — not catchable by plan review, which is why full-auto UI layers must run `screenshot-verifier`).
- The remeasurement is the follow-up-fix-PR count over the next five plans. Baseline: the three most recent pholex plans (#229, #230, #231) each produced one.

Record one thing under 안 한 것: `kickoff-guard.sh`'s [B] branch fires on a **user prompt** carrying implementation intent while the state file says `stage: spec|plan`. Under full-auto there is no such prompt, so that branch silently stops firing for these plans. It injects `additionalContext` only, so the loss is soft, and adding a second trigger path would give the same sentence two owners (규율 6). Left alone deliberately; revisit if a full-auto run is observed drifting in the way [B] exists to catch.

- [ ] **Step 9: Add `test-agents.sh` to both validation lists**

In `CLAUDE.md`'s `## 검증` code block and `README.md`'s `## 검증` code block, add the line after `./scripts/test-skills.sh`:

```bash
./scripts/test-agents.sh                  # 에이전트 이름 ↔ frontmatter model·effort 일치
```

(`README.md`'s block has no trailing comments — match the file you are editing.)

- [ ] **Step 10: Retire the machine-local stale agent**

User-defined agents in `~/.claude/agents/` override same-named plugin agents, so `~/.claude/agents/plan-implementer.md` stays resolvable after the plugin drops it, at its old un-pinned frontmatter. Move it rather than delete it — it is not in this repo, so a delete is not reversible from here:

```bash
mkdir -p ~/.claude/agents/.superseded-260827
mv ~/.claude/agents/plan-implementer.md ~/.claude/agents/.superseded-260827/
ls ~/.claude/agents/
```

Expected: `Explore.md`, `plan-reviewer.md`, `screenshot-verifier.md`, and the `.superseded-260827/` directory. If `plan-implementer.md` was not there, skip this step and say so — some machines never had the local copy.

- [ ] **Step 11: Run every check**

```bash
./scripts/check-harness-docs.sh \
  && ./scripts/test-hooks.sh \
  && ./scripts/test-skills.sh \
  && ./scripts/test-agents.sh \
  && ./scripts/validate-codex.sh \
  && claude plugin validate ./woobin-harness
```

Expected: all PASS. `check-harness-docs.sh` may still print `⚠` lines — those are judgment items, not failures; it exits 0 with them. Any `✗` is a real gap: read which count it names and fix that file.

```bash
DRY_RUN=1 ./bootstrap.sh && DRY_RUN=1 ./bootstrap-codex.sh
```

Expected: both complete. `bootstrap-codex.sh` iterates `codex/agents/*.toml` with a glob, so it picks up six files without edits — this run confirms that.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "docs(harness): full-auto 실행 라우팅 반영 — R1 축소·R7 분할·에이전트 4→6·v1.17.0"
```
