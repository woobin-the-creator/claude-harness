# Task 5: Workflow Docs, Plugin Metadata, and Release Validation

**Files:**
- Modify: `README.md`
- Modify: `docs/workflow.html`
- Modify: `docs/workflow-spec.md`
- Modify: `woobin-harness/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Verify only: `home/HARNESS-LOG.md`

**Interfaces:**
- Consumes: Task 3 route matrix and Task 4 aggregate test command.
- Produces: public workflow routing, model-facing rule R16, plugin version `1.7.0`, and synchronized skill count `27`.
- Release gate: all commands in `00-overview.md` exit `0`.

- [ ] **Step 1: Capture the pre-existing count drift before editing**

Run:

```bash
find woobin-harness/skills -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l
rg -n "스킬 (25|26)개|skills/<name>/SKILL.md" \
  README.md \
  woobin-harness/.claude-plugin/plugin.json \
  .claude-plugin/marketplace.json \
  docs/workflow-spec.md
```

Expected at the current base:

- filesystem: `26` skills before adding `design-workflow`, `27` after Tasks 1–4;
- README, plugin description, and workflow spec still say `25`;
- marketplace says `26`;
- plugin version is already `1.6.0`.

Record this as pre-existing metadata drift in the implementation handoff so the final `27` correction is not misattributed solely to the new skill.

- [ ] **Step 2: Update the human README inventory**

In `README.md`, change the repository tree comment:

```text
skills/<name>/SKILL.md        25개
```

to:

```text
skills/<name>/SKILL.md        27개
```

Add one sentence in the existing skills/workflow explanation, not a new summary section:

```markdown
제품 UI 작업은 `design-workflow`가 신규 방향·기존 시스템 증분 변경·리뷰·반복 실패를 먼저 분류하고, 필요한 디자인 모듈만 읽는다. `DESIGN.md`는 선택적이다.
```

- [ ] **Step 3: Add the human-facing route row to `workflow.html`**

In the delegation table beginning near line 310, add one row with these cells:

```html
<tr>
  <td>제품 UI 방향·구현·리뷰·반복 실패</td>
  <td><code>design-workflow</code></td>
  <td>작업을 분류해 direction, system-evidence, implementation-contracts, review, evolution 중 필요한 모듈만 읽는다. <code>DESIGN.md</code>가 없어도 진행한다.</td>
</tr>
```

Do not duplicate the module explanations elsewhere in the HTML.

- [ ] **Step 4: Replace the workflow-spec UI branch with the Router**

Change the existing line:

```text
├─(B) UI·디자인 ─── show-design-sample 스킬 …
```

to a two-level branch:

```text
├─(B) 제품 UI·디자인 ─── design-workflow (작업 분류, 선택적 DESIGN.md, 조건부 모듈)
│                       └─ 복수 시안 격리 프리뷰·공유가 필요할 때만 show-design-sample
```

In §4, change `### 스킬 25개` to `### 스킬 27개`. Add `design-workflow` to the pipeline-connected skills list and describe `design-rules` as its backward-compatible concrete-UI entry. Keep `show-design-sample` as the preview/delivery branch rather than the top-level UI Router.

- [ ] **Step 5: Add workflow rule R16 with all required evidence fields**

Insert after R15 and before §4:

```markdown
### R16 — 제품 UI 작업은 한 Router가 분류하고 필요한 디자인 모듈만 읽는다

**문제.** 신규 방향 탐색, 기존 시스템 보존, 구현 계약, 렌더 리뷰, 반복 실패의 가드 승격은 서로 다른 비용과 권한을 가진다. 하나의 큰 규칙 문서나 넓은 자동 트리거로 합치면 작은 변경도 모든 컨텍스트를 읽고 `design-rules`와 후보 비교 스킬이 경쟁한다.

**규칙.** 명시적 첫 도입·리디자인·리뷰·반복 실패와 managed `DESIGN.md`가 있는 프로젝트의 UI 작업은 `design-workflow`가 먼저 분류한다. 그린필드/대규모 리디자인에서만 direction을 읽고, review-only는 쓰지 않으며, `DESIGN.md` 부재·unmanaged 상태는 작업을 막지 않는다. 복수 시안 렌더가 필요할 때만 `show-design-sample`로 내려간다.

**기전.** 짧은 Router가 route를 공개하고 progressive disclosure reference를 조건부로 읽는다. 구조화된 `DESIGN.md`는 선택적 durable state이고, validator는 managed block만 검사한다. 프로젝트별 가드는 기존 컴포넌트·린터·테스트 스택에 생성한다.

**근거.** `interface-design`은 방향·craft review, 기존 `design-rules`는 프로젝트 근거·실데이터·실패 선례, `ibm-products@eeff1e98`는 컴포넌트/린트/브라우저 가드가 각각 강했다. 2026-08-12 설계 인터뷰에서 하나의 Router+모듈, 선택적 구조화 `DESIGN.md`, 공통 validator+현지 가드, 위험도별 승인을 확정했다.

**대가.** Router 오분류와 문서/실행 경로 drift가 새 실패 모드다. managed document와 validator가 추가되며, 첫 도입 시 현재 작업 범위의 시스템 조사가 필요하다.

**무효화 조건.** 실제 라우팅 eval에서 증분 변경이 direction을 반복 로드하거나 review-only가 파일을 쓰는 회귀가 지속되고, route contract를 좁혀도 단일 스킬보다 비용·정확도가 개선되지 않을 때 폐기한다. 또는 plugin runtime이 동일 정본을 공유하는 typed module composition과 deterministic trigger를 제공해 Router prose가 불필요해질 때 그 원시 기능으로 대체한다.
```

- [ ] **Step 6: Synchronize plugin and marketplace release metadata**

Set `woobin-harness/.claude-plugin/plugin.json` to:

```json
{
  "version": "1.7.0"
}
```

while preserving all other fields, and change its description count from `25` to `27`.

Change `.claude-plugin/marketplace.json` description count from `26` to `27`. Do not invent a separate marketplace version field if the current schema does not have one.

- [ ] **Step 7: Run the deterministic skill and documentation gates**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/all.sh
sh scripts/check-harness-docs.sh
```

Expected: both exit `0`; the first ends with `ALL-OK` and the second reports no count/version/document drift.

- [ ] **Step 8: Validate plugin parsing and clean-machine installation behavior**

Run:

```bash
claude plugin validate ./woobin-harness
DRY_RUN=1 ./bootstrap.sh
```

Expected: both exit `0`. The plugin validator recognizes both `design-workflow` and the narrowed `design-rules` frontmatter. The dry-run prints intended operations without applying them.

- [ ] **Step 9: Verify source ownership, counts, and historical-log immutability**

Run:

```bash
test "$(find woobin-harness/skills -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')" = 27
rg -n --glob '!docs/woobin_plan/**' "스킬 (25|26)개" \
  README.md docs woobin-harness/.claude-plugin .claude-plugin && exit 1 || true
git diff -- home/HARNESS-LOG.md
git diff --check
```

Expected:

- no stale `25개` or `26개` count under runtime docs/manifests; archived plans are excluded because they intentionally quote the pre-change state and migration commands;
- no diff for `home/HARNESS-LOG.md`;
- no whitespace errors.

- [ ] **Step 10: Run the final spec-coverage audit**

For each design-spec completion condition, map it to evidence:

```text
ten user scenarios                 → route matrix + seven deterministic fixtures + five headless cases
absent/unmanaged/managed DESIGN    → validator fixtures and Router contract
source types                       → schema module + system-evidence
review-only read-only              → route fixture + headless assertion
approval boundary                 → Router + evolution
design-rules compatibility        → compatibility contract
no dependencies                   → imports inspection + validator tests
plugin/docs synchronization        → check-harness-docs + plugin validate
```

If any row lacks a passing command or an inspectable file, add the missing assertion to the owning task's existing test; do not create a new summary test.

- [ ] **Step 11: Commit Task 5**

```bash
git add README.md \
        docs/workflow.html \
        docs/workflow-spec.md \
        woobin-harness/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json
git commit -m "Publish the modular design workflow

Constraint: UI routing, skill counts, and plugin cache version must move together
Confidence: medium
Scope-risk: medium
Tested: skill suite, docs guard, plugin validation, bootstrap dry-run"
```

- [ ] **Step 12: Prepare the implementation handoff without closing external issues**

Report:

- deterministic gate results;
- whether the optional headless eval ran and which cases passed;
- pre-existing 25/26 count drift corrected to 27;
- #8 claims corrected in `sources.md`;
- any approval-required project guard intentionally left unimplemented.

Do not close #7 or #8, push, or publish a plugin from this local implementation task unless the user separately authorizes those external actions.
