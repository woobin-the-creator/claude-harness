### Task 4: `writing-plans` handoff rewrite

Make the skill dispatch the plan-document reviewer unconditionally, route on the gate count, and either run the implementation itself (full-auto) or emit the kickoff block (②a) — instead of always emitting the kickoff block.

**Files:**
- Modify: `woobin-harness/skills/writing-plans/SKILL.md` — the dispatch paragraph at line 217 (end of `## Self-Review`), and the whole `## Execution Handoff` section from line 219 to the end of file

**Interfaces:**
- Consumes: the `**Gates:** N` output line from Task 3; the routing table and full-auto procedure from Task 2; the three Claude agent type strings from Task 1.
- Produces: nothing later tasks read. Task 5's hook mirrors this procedure for skill-less sessions but owns its own wording.

`SKILL.md` is written in English. Keep it that way; only the kickoff block inside it matches the user's language.

---

- [ ] **Step 1: Make the reviewer dispatch unconditional**

Replace the paragraph at line 217, which currently reads:

```
**For high-stakes plans only** — irreversible work such as migrations, prod-facing changes, or anything headed for execution mode ③ — dispatch an independent plan-document reviewer using [plan-document-reviewer-prompt.md](plan-document-reviewer-prompt.md). Skip it otherwise: for ordinary plans the checklist above catches the same things at a fraction of the cost.
```

with:

```
Then dispatch an independent plan-document reviewer using [plan-document-reviewer-prompt.md](plan-document-reviewer-prompt.md). Do this for **every** plan, not only high-stakes ones: the checklist above is you checking your own work, and the plan may be executed with no human reading it first. Apply the findings to the plan files before going any further — a finding you leave unfixed is a finding nobody will see again.

Keep the reviewer's `**Gates:** N` line. The Execution Handoff below routes on that number.
```

- [ ] **Step 2: Replace the Execution Handoff section**

Everything from `## Execution Handoff` (line 219) to the end of the file is replaced by:

````markdown
## Execution Handoff

Read the execution-mode file for the current host and follow it — it owns the mode contract, the gate-routing table, and the full-auto procedure:

- Claude Code: [plan-exec-modes.md](../../plan-exec-modes.md)
- Codex: [plan-exec-modes-codex.md](../../plan-exec-modes-codex.md)

### Pick the mode

Recommend exactly one and state the evidence, because the only basis for the choice is the ordering section you just wrote into `00-overview.md`, and no later session can reconstruct it as cheaply:

- ① Speed — only when two or more tracks share no files.
- ② Thrift — dependency chain or shared files. Most plans land here.
- ③ Max quality — migrations, prod-facing changes, UI that automated gates cannot check.

### Then route on the gate count

The reviewer's `**Gates:** N` decides whether the run is attended, and it can override the mode you just picked:

- **N = 0** → run it here, full-auto. Do not emit a kickoff block.
- **N ≥ 1** → ②a. Emit the kickoff block and end the turn; the user drives the layer boundaries.
- **N ≥ 1 and the plan meets ③'s trigger** → keep ③ and run it here. It will stop at the gate and report; you relay that to the user and resume. A migration plan does not get demoted to `sonnet`/`medium` over one visual check.

State the routing outcome and the gate count in one line so the user can override it.

### Full-auto (N = 0)

Do not start implementing inline. Follow the modes file's full-auto procedure: open the `plan/<slug>` branch and draft PR first, then spawn one implementer per layer, serially, using the agent name the modes file gives for the chosen mode. Pass the overview path and that layer's `task-N.md` paths in execution order — never the task bodies, and never a `model` argument, because the agent definition owns model and effort.

Between layers: the implementer commits, you run `plan-reviewer`, you apply its findings, you push. If a layer changed anything that renders, dispatch `screenshot-verifier` before pushing — nobody is looking at the screen, which is the whole point of full-auto and also its blind spot.

Never fan out a subagent per task, and never tell an implementer to verify its own work — both are measured losses, cited in the modes file.

### The kickoff block (N ≥ 1 only)

End the response with a copyable kickoff prompt, because the handoff only pays off if the user can start the next session without composing anything. Anything they have to fill in themselves is a place the handoff breaks.

Make a fenced ` ```text ` block the **final content of the response** — nothing after it. Match the user's language — the kickoff block is read by a person, unlike the plan documents themselves. Follow the selected host file's kickoff format, and substitute the real model, effort, mode number, and absolute plan path. Leave no angle-bracket placeholders.

Do not mix hosts: no Claude model names or `/effort` commands in a Codex kickoff, and no Codex model slugs or `-c model_reasoning_effort=…` in a Claude Code kickoff. A kickoff that names the wrong runtime is worse than none — it gets pasted and fails in a way the user has to debug.

Measured basis: this harness repo's `home/HARNESS-LOG.md` §12·§16·§31, and the sources at the bottom of the selected modes file.
````

- [ ] **Step 3: Run the check**

```bash
./scripts/test-skills.sh
```

Expected: PASS. The fixture verifies that the relative links `../../plan-exec-modes.md`, `../../plan-exec-modes-codex.md`, and `plan-document-reviewer-prompt.md` all resolve from the skill directory. It fails loudly if a path was mangled while editing.

- [ ] **Step 4: Commit**

```bash
git add woobin-harness/skills/writing-plans/SKILL.md
git commit -m "feat(writing-plans): 게이트 0개면 그 세션이 끝까지 굴린다"
```
