### Task 2: Execution mode contracts (both hosts)

Teach both mode files the gate-routing rule, the full-auto procedure, and the new agent names. These files are the canonical source for the mode contract — the skill and the hook point at them rather than restating them.

**Files:**
- Modify: `woobin-harness/plan-exec-modes.md` (`## 모든 모드 공통` at line 7, the `②b` bullets at lines 126-141, the `## ③` block at line 154)
- Modify: `woobin-harness/plan-exec-modes-codex.md` (`## 모든 모드 공통` at line 7, `### ②b` at line 44, `## ③` at line 58, `## 선택 결과 전달` at line 74)

**Interfaces:**
- Consumes: the six agent type strings from Task 1.
- Produces: the routing rule text. Task 3 quotes its three outcomes in the reviewer prompt; Task 4's `SKILL.md` and Task 5's hook both point at these files instead of restating the rule.

These files are read by a person and stay in Korean.

---

- [ ] **Step 1: Add the gate-routing rule to `plan-exec-modes.md`**

Insert a new section immediately after the `## 모든 모드 공통` heading (line 7), before the existing first bullet:

```markdown
### 무인 실행 여부는 게이트 수가 정한다

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
```

- [ ] **Step 2: Rewrite the effort/model bullet in `plan-exec-modes.md`**

The current second bullet of `## 모든 모드 공통` begins `- **effort·model은 런치 플래그로 정한다**`. It is now only half true: it holds for ②a and for the planning session itself, but a delegated implementer takes its values from its own definition. Replace the whole bullet with:

```markdown
- **effort·model의 소유자는 둘로 갈린다.**
  - **세션** — `claude --effort <level> --model <model>`. ②a와 플랜 세션 자신이 여기다.
    문서상 `--effort`는 "set it for a single session"이라 그 세션에만 적용되고 `settings.json`을 안 건드린다.
    세션 중간에는 바꾸지 않는다: effort 값이 렌더된 프롬프트에 들어가서, 바꾸면 이전 캐시 프리픽스가 통째로 무효화된다.
    (`/effort`는 쓰지 않는다 — interactive 세션에서 `effortLevel`에 **영구 저장**되어 되돌리기를 사람이 기억해야 하고,
     `effortLevel`이 startup에 적용되지 않는 미해결 버그도 있다: anthropics/claude-code#45453.)
  - **위임된 구현자** — 에이전트 정의의 frontmatter. `Agent` 호출에는 **effort 인자가 없어서**
    다른 수단이 없다. full-auto에서는 세션 재런치가 없으므로 상속에 기댈 수도 없다.
    그래서 `Agent(subagent_type: …)`에 **`model`을 넘기지 마라** — 정의가 이미 소유한다.
    `subagent-model-default.sh`도 frontmatter에 `model:`이 있으면 주입하지 않고 빠진다.
```

- [ ] **Step 3: Add the full-auto procedure to `plan-exec-modes.md`**

Inside `### 중단 대비 — 레이어 경계 커밋 + 리뷰 후 push (R15)`, the `**모드별 차이**` list at the end currently has three bullets (`②a`, `②b`, `①`). Append a fourth:

```markdown
- **full-auto (①·②b·③, 게이트 0개)** — 플랜 세션이 킥오프 블록을 내지 않고 **그대로 이어서 굴린다.**
  1. R15 첫 턴 절차(브랜치 · 플랜 커밋 · push · draft PR)를 플랜 세션에서 그대로 한다.
  2. 레이어마다 그 모드의 구현자를 **순차로** 하나씩 띄운다. `model`을 넘기지 않는다.
  3. 레이어 끝: 커밋(구현자) → `plan-reviewer` → 수정 → push(오케스트레이터).
  4. **그 레이어가 렌더 결과를 바꿨으면 push 전에 `screenshot-verifier`를 1회 띄운다.**
     아무도 화면을 안 본다는 게 full-auto의 정의라, 자동 게이트의 사각지대가 그대로 main까지 간다
     (pholex #235: `.admin-page`가 CSS에 없어 페이지 전체가 브라우저 기본값으로 렌더됐고
      다크 명암비가 1.20:1이었는데 기계 게이트가 styles.css 안쪽만 훑어서 못 잡았다).
  5. 마지막 레이어 push 직후 `gh pr ready`.
  오케스트레이터는 플래닝 컨텍스트를 안은 채 이 전부를 낸다 — 그게 이 형태의 대가다(§8 O19).
```

- [ ] **Step 4: Name the agents in each mode block of `plan-exec-modes.md`**

`## ① 속도` — the bullet currently reading `Agent(isolation: "worktree", model: "sonnet")` becomes:

```markdown
- 트랙 단위로만 위임한다(태스크 단위 아님).
  `Agent(subagent_type: "plan-implementer-sonnet-xhigh", isolation: "worktree")` — `model`을 넘기지 않는다.
```

`②b` — the bullet at lines 129-131 reading ``Agent(subagent_type: "plan-implementer", model: "sonnet", …)`` and the `**`model`을 반드시 명시한다**` warning after it are both obsolete. Replace that whole bullet with:

```markdown
- 레이어마다 `plan-implementer-sonnet-medium`을 **순차로** 하나씩 띄운다(병렬 아님 — 레이어끼리 의존한다).
  `Agent(subagent_type: "plan-implementer-sonnet-medium", prompt: "<overview 경로> + <task-N.md 경로들 순서대로>")`
  — **`model`도 effort도 넘기지 않는다.** 정의가 `sonnet`·`medium`을 소유한다. 넘기면 이름과 실제가 갈린다.
```

Keep the following `memory: local` / `maxTurns` bullet, but change its opening word `정의에` to `세 변이체 정의 모두에`.

Replace the `⚠️ plan-implementer는 확인 게이트에서 멈추고 보고한다` bullet with:

```markdown
- ⚠️ 구현자는 **확인 게이트에서 멈추고 보고**한다(정의에 박아둠). 게이트가 있는 플랜은 애초에 ②a로
  라우팅되므로 ②b에서 이걸 보면 리뷰어의 게이트 인벤토리가 틀렸다는 신호다 — 사용자에게 올리고,
  답을 받아 같은 레이어를 이어서 갈 새 구현자를 띄운다.
```

`## ③ 최고 퀄리티` — the bullet `- 구현은 메인 루프에서 Opus 5 @ xhigh.` becomes:

```markdown
- 구현은 `plan-implementer-opus-xhigh`에 레이어 단위로 위임한다(게이트가 있으면 그 지점에서 멈춘다).
  **max는 쓰지 않는다** — "on some structured-output or less intelligence-sensitive tasks it can lead to overthinking." 플랜 실행이 그 부류다.
```

- [ ] **Step 5: Mirror all of it into `plan-exec-modes-codex.md`**

Same four changes, Codex names and slugs, no Claude vocabulary:

1. After `## 모든 모드 공통` (line 7), insert the same `### 무인 실행 여부는 게이트 수가 정한다` section verbatim — the routing rule is host-independent.
2. Replace the bullet `- 새 CLI 세션에서 모델·effort를 고정하려면 …` with:

```markdown
- 모델·effort의 소유자는 둘로 갈린다. **세션**은 `codex -m <model> -c 'model_reasoning_effort="<effort>"'`
  (②a와 플랜 세션 자신). **위임된 구현자**는 자기 프로필 TOML의 `model`·`model_reasoning_effort`가 소유하며,
  호출 쪽에서 덮어쓰지 않는다.
```

3. In `### ②b`, change the heading and first bullet to name `plan-implementer-gpt56-medium`; in `## ① 속도`, name `plan-implementer-terra-medium`; in `## ③`, change `구현은 메인 세션 또는 순차 plan-implementer가 수행한다.` to `구현은 순차 plan-implementer-gpt56-xhigh가 수행한다(게이트가 있으면 그 지점에서 멈춘다).`
4. In `## 선택 결과 전달`, replace the first sentence `플랜을 저장한 세션에서는 구현을 시작하지 않는다.` with:

```markdown
게이트가 1개 이상이면 플랜을 저장한 세션에서 구현을 시작하지 않고, 다음 task에서 사용할 모델·effort,
모드 번호, plan 경로를 한 번에 전달한다. 게이트가 0개이면 그 세션이 그대로 full-auto로 굴린다 —
전달할 것이 없다. Claude 전용 `sonnet`·`opus`·`/effort` 문구를 Codex kickoff에 섞지 않는다.
```

- [ ] **Step 6: Run the check**

```bash
./scripts/test-agents.sh
```

Expected: PASS. Check 5 (mode files quote all six agent names) is what this task exists to satisfy.

- [ ] **Step 7: Commit**

```bash
git add woobin-harness/plan-exec-modes.md woobin-harness/plan-exec-modes-codex.md
git commit -m "feat(modes): 게이트 수로 무인 실행 라우팅 + 구현자 이름을 변이체로"
```
