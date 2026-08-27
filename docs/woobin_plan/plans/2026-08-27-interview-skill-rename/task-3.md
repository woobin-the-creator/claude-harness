### Task 3: Update the five live references to the old name

**Files:**
- Modify: `woobin-harness/skills/kick-off/SKILL.md:21`, `:29`, `:38`
- Modify: `woobin-harness/hooks/kickoff-guard.sh:58`
- Modify: `woobin-harness/skills/writing-plans/SKILL.md:3`, `:47`
- Modify: `README.md:136`
- Modify: `docs/workflow.html:168`

**Interfaces:**
- Consumes: the directory name `interview` and the slash command `/interview` produced by Task 1.
- Produces: nothing later tasks consume, but Task 4's `workflow-spec.md` §4 inventory must describe the state this task leaves behind.

**The distinction that governs this task.** A reference is *live* if it routes the reader or the runtime to the skill as it exists now — update those. A reference is *historical* if it narrates something that happened when the skill was named `grill-me` — leave those alone, because renaming them detaches the evidence from what was measured. Exactly one line in this task's files is historical: `woobin-harness/hooks/kickoff-guard.sh:5`. Do not touch it.

`scripts/test-hooks.sh` asserts on the string `이탈 알림` for the `kickoff-guard` drift branch (line 271), not on the `spec` branch's message text — verified. Editing line 58 will not break the fixture.

---

- [ ] **Step 1: Update `kick-off/SKILL.md` — three lines**

In `woobin-harness/skills/kick-off/SKILL.md`, make these three replacements.

Line 21, find:

```
| 둘 다 없음 | `grill-me` |
```

Replace with:

```
| 둘 다 없음 | `interview` |
```

Line 29, find:

```
- 기능 개발 → `grill-me` → `writing-plans`
```

Replace with:

```
- 기능 개발 → `interview` → `writing-plans`
```

Line 38, find:

```
크기에 맞춰 산출물을 줄이는 건 `grill-me`와 `writing-plans`가 각자 이미 한다.
```

Replace with:

```
크기에 맞춰 산출물을 줄이는 건 `interview`와 `writing-plans`가 각자 이미 한다.
```

- [ ] **Step 2: Update the `kickoff-guard.sh` runtime message**

In `woobin-harness/hooks/kickoff-guard.sh`, find line 58:

```
  spec) next="스펙을 굳히는 중입니다(\`grill-me\`). 결정 원장의 미결이 비기 전에는 코드로 넘어가지 마세요." ;;
```

Replace with:

```
  spec) next="스펙을 굳히는 중입니다(\`interview\`). 결정 원장의 미결이 비기 전에는 코드로 넘어가지 마세요." ;;
```

Keep the backslash-escaped backticks exactly as they are — they are inside a double-quoted shell string and dropping the escapes turns them into command substitution.

**Leave line 5 unchanged.** It reads `# 그게 목적이다 — \`brainstorming\`이 \`grill-me\`와 트리거가 겹쳐 3일 246세션 발동 0회로 죽었다.` That is a record of a measurement taken in August 2026, when the skill was named `grill-me`.

- [ ] **Step 3: Update `writing-plans/SKILL.md` — two lines**

In `woobin-harness/skills/writing-plans/SKILL.md`, line 3 is the `description:` field and contains the old name twice. Find these two fragments within that single line and replace each in place:

Find `right after grill-me settles a spec` → replace with `right after interview settles a spec`

Find `that is grill-me.` → replace with `that is interview.`

Do not reflow line 3 or insert newlines into it — it is a single YAML scalar. Introducing a colon-plus-space or a line break there makes the whole frontmatter parse as a mapping and silently drops every field.

Line 47, find:

```
working in — those have a human reader, and `grill-me` depends on the user
```

Replace with:

```
working in — those have a human reader, and `interview` depends on the user
```

- [ ] **Step 4: Update `README.md:136`**

Find this fragment inside line 136:

```
off로 끄면 슬래시 이름(`/grill-me`)이 그대로 유지된다
```

Replace with:

```
off로 끄면 슬래시 이름(`/interview`)이 그대로 유지된다
```

Leave the `스킬 41개` and `41건` counts alone. That 41 is the number of `skillOverrides` entries across all installed plugins, not this harness's 21 skills, and a rename does not change it.

- [ ] **Step 5: Update `docs/workflow.html:168`**

Find:

```
      <h3>인터뷰 <span class="tag">grill-me</span></h3>
```

Replace with:

```
      <h3>인터뷰 <span class="tag">interview</span></h3>
```

- [ ] **Step 6: Verify every live reference is gone and only historical ones remain**

```bash
cd /Users/mac_wb/.paseo/worktrees/11zirkjp/rabid-stingray
command grep -rn "grill-me" README.md docs/workflow.html woobin-harness/ \
  --include="*.md" --include="*.sh" --include="*.html" --include="*.json"
```

Expected: exactly one line — `woobin-harness/hooks/kickoff-guard.sh:5`. Anything else is a live reference that was missed.

- [ ] **Step 7: Run the completion check**

```bash
./scripts/test-hooks.sh && ./scripts/test-skills.sh
```

Expected: both exit 0. `test-hooks.sh` covers 12 shared hooks including `kickoff-guard`; `test-skills.sh` re-asserts the 21-skill count and parses skill assets.

- [ ] **Step 8: Commit**

```bash
git add README.md docs/workflow.html woobin-harness/skills/kick-off/SKILL.md \
        woobin-harness/skills/writing-plans/SKILL.md woobin-harness/hooks/kickoff-guard.sh
git commit -m "refactor: interview 리네임에 따른 살아있는 참조 5곳 갱신"
```
