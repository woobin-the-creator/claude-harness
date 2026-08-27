### Task 1: kick-off skill + skill-count sync

**Files:**
- Create: `woobin-harness/skills/kick-off/SKILL.md`
- Create: `woobin-harness/skills/kick-off/agents/openai.yaml`
- Modify: `scripts/test-skills.sh` (2 places)
- Modify: `scripts/validate-codex.sh` (1 place)
- Modify: `README.md` (3 places)
- Modify: `docs/workflow-spec.md` (2 places)
- Modify: `docs/workflow.html` (2 places)
- Modify: `.claude-plugin/marketplace.json` (1 place)
- Modify: `woobin-harness/.claude-plugin/plugin.json` (2 places)
- Modify: `woobin-harness/.codex-plugin/plugin.json` (1 place)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the file `woobin-harness/skills/kick-off/SKILL.md`, whose absolute runtime path is `${CLAUDE_PLUGIN_ROOT}/skills/kick-off/SKILL.md`. Task 2's hook injects exactly that path string. Also produces the state-file contract `.claude/kickoff.local.md` with YAML frontmatter keys `active` (boolean), `stage` (one of `spec` / `plan` / `impl`), `topic` (string), `session_id` (string), `started_at` (ISO 8601 string) — Task 2's hook parses `active` and `stage` from it.

---

- [ ] **Step 1: Create the skill directory and `SKILL.md`**

Write `woobin-harness/skills/kick-off/SKILL.md` with exactly this content:

````markdown
---
name: kick-off
description: 이 하네스의 작업 워크플로우로 들어가는 단일 진입점.
disable-model-invocation: true
---

# kick-off

이 하네스에서 무언가를 만들 때 여는 문이다. 어느 스킬을 어떤 순서로 부를지는 **여기서만** 안다 —
사용자는 `/kick-off` 하나만 기억하면 된다.

## 시작할 때

1. `.claude/kickoff.local.md`가 있고 `active: true`면 읽고, 적힌 `stage`부터 이어간다.
2. 없으면 **파일을 먼저 보고** 진입 지점을 정한다. 사용자에게 묻는 건 파일로 판정이 안 될 때뿐이다.

| 레포에 있는 것 | 진입 지점 |
|---|---|
| 이 주제의 `docs/woobin_plan/plans/<slug>/00-overview.md` | 구현 — 그 경로를 그대로 쓴다 |
| `docs/woobin_plan/specs/` 아래 확정 스펙 | `writing-plans` |
| 둘 다 없음 | `grill-me` |

3. 정한 것을 **한 줄로 선언**한다: `진입: <단계> · 경로: <이어질 스킬 이름들>`
   틀렸으면 사용자가 그 자리에서 잡는다.
4. `.claude/kickoff.local.md`를 쓴다(형식은 아래).

## 문 목록

- 기능 개발 → `grill-me` → `writing-plans`
- 제품 UI·디자인 → `design-workflow`
- 디버깅 → `systematic-debugging`

**이름만 부른다.** 각 스킬이 무엇을 어떻게 하는지 여기서 설명하지 않는다 — 사본이 갈라진다.

## 난이도는 판정하지 않는다

`/kick-off`가 눌렸다는 것 자체가 "이건 워크플로우를 태울 일이다"라는 사용자의 판정이다.
크기에 맞춰 산출물을 줄이는 건 `grill-me`와 `writing-plans`가 각자 이미 한다.

## 상태 파일

`.claude/kickoff.local.md`:

```markdown
---
active: true
stage: spec
topic: <한 줄>
session_id: <세션 id>
started_at: <ISO 8601>
---
<사용자가 처음 준 요구사항 원문>
```

- `stage`는 `spec` → `plan` → `impl` 순으로만 간다. 스펙이 확정되면 `plan`, 플랜이 저장되면 `impl`.
- 훅이 이 파일을 읽는다. `active: false`면 훅은 조용해진다.

## 끝내기

`done` 인자로 불리면(`/kick-off done`) `active: false`만 쓰고 끝낸다. 다른 일은 하지 않는다.
````

- [ ] **Step 2: Create the Codex policy file**

Write `woobin-harness/skills/kick-off/agents/openai.yaml` with exactly this content:

```yaml
interface:
  display_name: "Kick Off"
  short_description: "이 하네스의 워크플로우로 들어가는 단일 진입점"
policy:
  allow_implicit_invocation: false
```

- [ ] **Step 3: Run the skill fixture to verify it fails on the count**

Run: `./scripts/test-skills.sh`
Expected: FAIL with `✗ expected 20 skills, found 21`

- [ ] **Step 4: Update `scripts/test-skills.sh`**

Two edits.

At lines 19–20, replace:

```sh
[ "$skill_count" -eq 20 ] || fail "expected 20 skills, found $skill_count"
pass "20 packaged skills"
```

with:

```sh
[ "$skill_count" -eq 21 ] || fail "expected 21 skills, found $skill_count"
pass "21 packaged skills"
```

At line 82, replace:

```python
expected = {"hooks": 12, "agents": 4, "skills": 20}
```

with:

```python
expected = {"hooks": 12, "agents": 4, "skills": 21}
```

(The `hooks` value stays 12 here — Task 2 changes it.)

- [ ] **Step 5: Run the skill fixture to verify it passes**

Run: `./scripts/test-skills.sh`
Expected: PASS, ending with all `✓` lines and no `✗`

- [ ] **Step 6: Update `scripts/validate-codex.sh`**

Around line 144, replace:

```sh
  [ "$(find "$cache/skills" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' ';' -print | wc -l | tr -d ' ')" -eq 20 ] \
    || fail "Codex cache가 스킬 20개를 모두 포함하지 않는다"
```

with:

```sh
  [ "$(find "$cache/skills" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' ';' -print | wc -l | tr -d ' ')" -eq 21 ] \
    || fail "Codex cache가 스킬 21개를 모두 포함하지 않는다"
```

If the second line's wording differs from the above, keep the existing wording and change only the number.

- [ ] **Step 7: Update `README.md`**

Three edits. Line 11:

```
- Claude Code: `/plugin install`이 스킬 20개·에이전트 4개·훅 12개를 붙인다.
```
→
```
- Claude Code: `/plugin install`이 스킬 21개·에이전트 4개·훅 12개를 붙인다.
```

Line 12: change `스킬 20개와 검증된 훅 4개` → `스킬 21개와 검증된 훅 4개` (leave `훅 4개` alone — Task 2 changes it).

Line 39, in the directory tree:

```
│   ├── skills/<name>/SKILL.md        20개
```
→
```
│   ├── skills/<name>/SKILL.md        21개
```

Line 110: change `실제 \`codex debug prompt-input\`에서 스킬 20개와` → `... 스킬 21개와`.

- [ ] **Step 8: Update `docs/workflow-spec.md` §2 pipeline**

In the fenced pipeline diagram in `## 2. 실제 파이프라인`, replace:

```
요구사항
   │
   ├─(A) 기능 개발 ─────────────────────────────────────────────
```

with:

```
요구사항
   │   진입: /kick-off — 사용자가 외울 유일한 트리거. 아래 분기를 대신 고르고 상태를
   │         .claude/kickoff.local.md 에 적는다. 난이도는 판정하지 않는다
   │
   ├─(A) 기능 개발 ─────────────────────────────────────────────
```

- [ ] **Step 9: Update `docs/workflow-spec.md` §4 skill inventory**

At line 668, replace the heading `### 스킬 20개` with `### 스킬 21개`.

Immediately after that heading, insert this paragraph before the existing `2026-08-26, 기존 인포그래픽 스킬을 …` paragraph:

```
2026-08-27, 파이프라인의 단일 진입점 `kick-off`을 추가해 20 → 21이 됐다. 이 레포에서 처음으로
`disable-model-invocation: true`를 쓰는 스킬이다(Codex 대응은 `agents/openai.yaml`의
`policy.allow_implicit_invocation: false`) — 사람만 부를 수 있어서 `grill-me`와 트리거가 경쟁하지
않는다. 본문은 위임만 하고 하위 스킬의 절차를 한 줄도 옮겨 적지 않는다. 규칙은 §3 R20.
```

Then add `kick-off` to the "파이프라인에 직접 물린 것:" list in that section — put it first, so the list starts `\`kick-off\` · \`grill-me\` · \`writing-plans\` · …`.

- [ ] **Step 10: Update `docs/workflow.html`**

Two edits. First, in section `01 전체 흐름`, insert a new step card as the **first** child of `<ul class="rail">`, before the existing `인터뷰 grill-me` card:

```html
  <li class="step">
    <div class="step-card">
      <h3>진입 <span class="tag">kick-off</span></h3>
      <p><b>외울 트리거는 이것 하나다.</b> <code>/kick-off</code>가 레포 상태를 보고 어느 단계부터 시작할지 정하고, 아래 분기 중 하나로 넘긴다. 상태는 <code>.claude/kickoff.local.md</code>에 남아 다음 세션이 이어받는다.</p>
      <p class="why">사람만 부를 수 있게 막아뒀다(<code>disable-model-invocation</code>) — 모델이 알아서 켜는 프론트도어는 비슷한 스킬에 밀려 안 켜진다. 실제로 <code>brainstorming</code>이 3일 246세션에서 발동 0회로 삭제됐다. 난이도는 판정하지 않는다: <code>/kick-off</code>를 쳤다는 것 자체가 사용자의 판정이다.</p>
    </div>
  </li>
```

Second, at line 409, replace `<li><b>공통 스킬 20개</b>` with `<li><b>공통 스킬 21개</b>`.

- [ ] **Step 11: Update the two manifests and the marketplace**

`.claude-plugin/marketplace.json` — in `plugins[0].description`, change `스킬 20개` → `스킬 21개`.

`woobin-harness/.claude-plugin/plugin.json` — change `스킬 20개` → `스킬 21개` in `description`, and `"version": "1.14.0"` → `"version": "1.15.0"`.

`woobin-harness/.codex-plugin/plugin.json` — change `"version": "1.14.0"` → `"version": "1.15.0"`. Its `description` carries no counts; leave it.

- [ ] **Step 12: Run the full check for this task**

Run: `./scripts/test-skills.sh && ./scripts/check-harness-docs.sh && claude plugin validate ./woobin-harness`
Expected: `test-skills.sh` all `✓`; `check-harness-docs.sh` prints `동기화됨.` or `동기화됨 (⚠ 는 판단이 필요한 항목).` with no `✗`; `claude plugin validate` reports the plugin as valid.

If `check-harness-docs.sh` prints `✗ … 스킬 20개로 적혀 있는데 실제는 21개`, the named file still holds an old number — fix that file and re-run.

- [ ] **Step 13: Commit**

```bash
git add woobin-harness/skills/kick-off scripts/test-skills.sh scripts/validate-codex.sh \
        README.md docs/workflow-spec.md docs/workflow.html \
        .claude-plugin/marketplace.json \
        woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
git commit -m "feat(skills): kick-off — 워크플로우 단일 진입점, 사람만 호출 가능"
```
