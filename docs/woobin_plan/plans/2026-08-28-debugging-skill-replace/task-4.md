### Task 4: Version bump and full validation

**Files:**
- Modify: `woobin-harness/.claude-plugin/plugin.json` (`version` field)
- Modify: `woobin-harness/.codex-plugin/plugin.json` (`version` field)

**Interfaces:**
- Consumes: Tasks 1–3 complete.
- Produces: nothing.

**Why this is last:** the installed plugin lives at `~/.claude/plugins/cache/<mp>/<plugin>/<version>/` as a **frozen per-version copy**. Without a bump, the repo changes exist but the installed skill stays the old one. This was missed once on 2026-08-08.

- [ ] **Step 1: Re-check that the target version is free**

Do this before writing. The repo's `version` can lag behind the installed one if another branch installed a newer build; adding `+1` to the repo value then lands on a directory that is already frozen and the update silently does nothing (this happened 2026-08-19: repo 1.5.0, installed 1.6.0).

```bash
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/
jq -r '.plugins["woobin-harness@woobin-harness"][].version' ~/.claude/plugins/installed_plugins.json
jq -r .version woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
```

Expected at plan time: cache holds `1.3.3 1.6.0 1.7.0 1.8.0 1.9.0 1.10.0 1.11.0 1.12.0 1.14.0 1.15.0 1.16.0`; installed is `1.16.0`; both repo files are `1.16.0`. Target is therefore **`1.17.0`**.

If `1.17.0` already appears in the cache listing, use the next free minor (`1.18.0`) and say so in the commit message.

- [ ] **Step 2: Bump both manifests**

Set `"version": "1.17.0"` in both files. They must match — the two runtimes read different manifests and a mismatch means one of them installs a different build.

```bash
jq '.version = "1.17.0"' woobin-harness/.claude-plugin/plugin.json > /tmp/cp.json && mv /tmp/cp.json woobin-harness/.claude-plugin/plugin.json
jq '.version = "1.17.0"' woobin-harness/.codex-plugin/plugin.json > /tmp/xp.json && mv /tmp/xp.json woobin-harness/.codex-plugin/plugin.json
```

Verify formatting survived (both files are 2-space indented JSON):

```bash
git diff --stat woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
```

Expected: 1 insertion and 1 deletion in each file. If more lines changed, `jq` reformatted the file — restore with `git checkout` and edit the single `version` line by hand instead.

- [ ] **Step 3: Run the full gate**

```bash
claude plugin validate ./woobin-harness
./scripts/validate-codex.sh
./scripts/test-hooks.sh
./scripts/test-skills.sh
./scripts/check-harness-docs.sh
```

Expected: all pass.

**Known pre-existing failure:** `test-hooks.sh` has one failing item, `stale-branch-guard`. It fails on `main` too and is recorded in `HARNESS-LOG` #28 / PR #26. If that is the *only* failure, it is not caused by this work — note it in the PR body and continue. Any other failure must be fixed before commit.

Do not skip `claude plugin validate`. It is the only thing that catches a colon-plus-space inside a frontmatter `description:`, which makes YAML parse the scalar as a mapping and silently drop every frontmatter field. The runtime is more permissive and will look fine.

- [ ] **Step 4: Commit**

```bash
git add woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
git commit -m "chore(plugin): 1.16.0 → 1.17.0 (repro-loop 교체 반영)

캐시에 1.17.0 미존재 확인. 두 매니페스트 동시 갱신."
```

- [ ] **Step 5: Apply the update locally and confirm the installed copy changed**

```bash
claude plugin marketplace update woobin-harness
claude plugin update woobin-harness@woobin-harness
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/1.17.0/skills/ | grep -c .
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/1.17.0/skills/repro-loop/
```

Expected: the skills listing counts 21, and `repro-loop/SKILL.md` exists. Restart Claude Code afterwards — `claude plugin update` prints "Restart to apply".

Note: the short name `woobin-harness` fails with "not found" on `plugin update`; the fully qualified `woobin-harness@woobin-harness` is required.

**This step only takes effect after the branch is merged** if the marketplace source is the GitHub remote rather than this local path. If `claude plugin update` reports no change, that is why — the update is not a failure of Tasks 1–4.
