### Task 5: Version bump and full validation

The installed plugin lives at `~/.claude/plugins/cache/woobin-harness/woobin-harness/<version>/` as a **frozen per-version copy**. If the version is not bumped, the repo changes never reach the running harness — and if the number chosen is already a directory there, the update is silently blocked instead of failing loudly.

**Files:**
- Modify: `woobin-harness/.claude-plugin/plugin.json`
- Modify: `woobin-harness/.codex-plugin/plugin.json`

**Interfaces:**
- Consumes: nothing. This task only reads the version fields and re-runs validators.
- Produces: nothing.

---

- [ ] **Step 1: Confirm the target version is free**

Run:

```bash
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/
jq -r '.plugins["woobin-harness@woobin-harness"][].version' ~/.claude/plugins/installed_plugins.json
jq -r .version woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
```

Expected at plan time: cache holds `1.3.3`, `1.6.0`–`1.12.0`, `1.14.0`–`1.19.0`; installed is `1.19.0`; both repo files read `1.19.0`. Target is therefore `1.20.0`.

**If the cache already contains `1.20.0`, do not use it.** The repo version can lag the installed one when another branch installed first, and writing into an already-frozen directory updates nothing. Pick the next free number above the highest cache entry and record which one you used in the commit message.

- [ ] **Step 2: Bump both files**

Set `"version": "1.20.0"` in `woobin-harness/.claude-plugin/plugin.json` and in `woobin-harness/.codex-plugin/plugin.json`. Both must carry the same value.

Run: `jq -r .version woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json`
Expected:
```
1.20.0
1.20.0
```

- [ ] **Step 3: Run every validator**

```bash
claude plugin validate ./woobin-harness
./scripts/test-hooks.sh
./scripts/test-skills.sh
./scripts/test-agents.sh
./scripts/check-harness-docs.sh
```

Expected: all five PASS. `test-hooks.sh` should report 13/13.

Then run, and expect a **failure that is not yours**:

```bash
./scripts/validate-codex.sh
```

Expected: fails on `kick-off`'s `disable-model-invocation` frontmatter key. This predates the plan. Do not fix it here; note it in the PR comment for this layer.

- [ ] **Step 4: Confirm no count drifted**

Run: `git diff --stat main...HEAD -- README.md woobin-harness/.claude-plugin/marketplace.json .agents/plugins/marketplace.json`
Expected: **empty output.** This plan adds no skill, hook, or agent, so none of the count declarations may have moved. If any of these files appears, a count was edited that should not have been — revert that edit.

Run: `grep -nE '(훅|에이전트|스킬) [0-9]+개' README.md docs/workflow.html docs/workflow-spec.md | head -20`
Expected: prints the count lines for a human to eyeball. `check-harness-docs.sh` passing in Step 3 is the real proof.

- [ ] **Step 5: Commit**

```bash
git add woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
git commit -m "chore(L4): 1.19.0 → 1.20.0"
```
