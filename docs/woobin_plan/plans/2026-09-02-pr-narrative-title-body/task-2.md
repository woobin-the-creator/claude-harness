### Task 2: Give `explain` a documented PR consumer

`explain` currently assumes its output is a chat reply. Task 1 makes it write a PR title and body. Without this task the skill's own text contradicts the caller — the same class of contradiction that killed R15 on 2026-09-02.

**Files:**
- Modify: `woobin-harness/skills/explain/SKILL.md` (currently 83 lines)

**Interfaces:**
- Consumes: from Task 1, the fact that `explain` is invoked for a PR title and body at two points.
- Produces: the heading `## Consumers outside the chat`, which nothing else greps for but Task 4's spec text names.

---

- [ ] **Step 1: Read the tail of the file**

Run: `sed -n '56,83p' woobin-harness/skills/explain/SKILL.md`

Expected: a `## Use proportionate structure` section, a `## Handle missing context` section, and a closing 3-line paragraph beginning `Output formatting and answer density follow the active output style`.

- [ ] **Step 2: Insert the new section**

Insert this section **between** the end of `## Handle missing context` (the paragraph ending `assumes a prerequisite the reader has not shown.`) and the closing `Output formatting and answer density…` paragraph. Keep one blank line on each side.

```markdown
## Consumers outside the chat

Some callers use this skill to write a document rather than a chat reply. The
calibration and self-containment rules above apply unchanged; only the
container differs, and the container is owned by the caller, not by this skill.

- **Pull request title and body** — the caller is the R15 procedure in
  `woobin-harness/plan-exec-modes.md`, invoked once when the draft PR is opened
  and again just before `gh pr ready`. The reader is a maintainer reading the
  PR list or `git log` months later with no access to this session, so default
  to the *situated* layer. Lead with the problem the user actually had, in the
  user's terms, before naming any file, hook, or symbol. Keep what was verified
  separate from what was assumed. The title is a single line and becomes the
  squash merge commit subject, so it carries the problem — not the branch name,
  not the file count.
```

- [ ] **Step 3: Verify the frontmatter survived**

Run: `head -4 woobin-harness/skills/explain/SKILL.md`
Expected: the `---` / `name: explain` / `description: …` / `---` block, byte-for-byte unchanged. A colon-space inside a `description:` scalar silently destroys every frontmatter field, so this file's first four lines must not be touched.

- [ ] **Step 4: Verify placement and syntax**

Run: `grep -n 'Consumers outside the chat' woobin-harness/skills/explain/SKILL.md`
Expected: exactly one hit, at a line number greater than the `## Handle missing context` hit and smaller than the `Output formatting and answer density` hit. Confirm with:

Run: `grep -n 'Handle missing context\|Consumers outside the chat\|Output formatting and answer density' woobin-harness/skills/explain/SKILL.md`
Expected: three lines, in that order.

Run: `./scripts/test-skills.sh`
Expected: PASS. The skill count assertion is unchanged — this task creates no directory.

Run: `claude plugin validate ./woobin-harness`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add woobin-harness/skills/explain/SKILL.md
git commit -m "feat(L2): explain에 PR 제목·본문 소비처를 명시"
```
