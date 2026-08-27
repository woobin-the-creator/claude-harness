### Task 5: Bump both manifests to 1.16.0, fix the local `skillOverrides` key, run the full suite

**Files:**
- Modify: `woobin-harness/.claude-plugin/plugin.json` (`version`)
- Modify: `woobin-harness/.codex-plugin/plugin.json` (`version`)
- Modify: `~/.claude/settings.json` (one key inside `skillOverrides`) — **outside the repo, not committed**

**Interfaces:**
- Consumes: the directory name `interview` from Task 1, which determines the new `skillOverrides` key `woobin-harness:interview`.
- Produces: the final validated state. Nothing follows this task.

**Why the version bump matters on this machine too.** The installed plugin lives at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` as a **frozen per-version copy**. Without a bump, every file this plan changed stays invisible to the running Claude Code — the repo is fixed and the installation is not. This was missed once already, on 2026-08-08.

**The target is 1.16.0, and it was checked against the cache, not guessed.** Verified 2026-08-27: the cache holds `1.3.3, 1.6.0, 1.7.0, 1.8.0, 1.9.0, 1.10.0, 1.11.0, 1.12.0, 1.14.0, 1.15.0`; installed is `1.15.0`; repo is `1.15.0`. Re-verify in Step 1 anyway — if another branch installed something in the meantime, the repo value can be *behind* the cache, and blindly adding one to the repo value lands on an already-frozen directory where the update silently does nothing (this happened on 2026-08-19 with repo 1.5.0 / installed 1.6.0).

**Why `~/.claude/settings.json` has to change.** It currently contains `"woobin-harness:grill-me": "off"`. That override exists because plugin skills are namespaced and would otherwise load twice, costing the always-on description budget in every session. After the rename the key dangles and `woobin-harness:interview` is **on**, restoring the double load. `bootstrap.sh` does not manage `skillOverrides` — it only merges `extraKnownMarketplaces`, `enabledPlugins`, `statusLine`, `crossSessionInbound`, and `outputStyle` — so nothing fixes this automatically.

---

- [ ] **Step 1: Re-verify the frozen cache before choosing the number**

```bash
cd /Users/mac_wb/.paseo/worktrees/11zirkjp/rabid-stingray
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/
jq -r '.plugins["woobin-harness@woobin-harness"][].version' ~/.claude/plugins/installed_plugins.json
jq -r .version woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
```

Pick the next minor version that appears in **neither** the cache listing nor the installed list. Expected: `1.16.0`. If `1.16.0` already exists in the cache, use `1.17.0` and carry that number through every remaining step.

- [ ] **Step 2: Bump both manifests**

```bash
for f in woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json; do
  tmp=$(mktemp)
  jq '.version = "1.16.0"' "$f" > "$tmp" && mv "$tmp" "$f"
done
jq -r .version woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
```

Expected: `1.16.0` printed twice. The two manifests must always carry the same value.

- [ ] **Step 3: Rename the `skillOverrides` key in the local settings**

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak-before-interview-rename
tmp=$(mktemp)
jq '.skillOverrides |= (
      to_entries
      | map(if .key == "woobin-harness:grill-me" then .key = "woobin-harness:interview" else . end)
      | from_entries
    )' ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
```

- [ ] **Step 4: Verify the key moved and the entry count is unchanged**

```bash
jq -r '.skillOverrides | to_entries[] | select(.key|test("interview|grill")) | "\(.key) = \(.value)"' ~/.claude/settings.json
jq -r '.skillOverrides | keys[] | select(startswith("woobin-harness:"))' ~/.claude/settings.json | wc -l
```

Expected: a line `woobin-harness:interview = off`, **no** `woobin-harness:grill-me` line, and the count `41` — the same as before, since this is a rename.

The unrelated `grilling`, `mattpocock-skills:grilling`, and `grill-with-docs` entries belong to other plugins and must remain untouched.

- [ ] **Step 5: Run the full validation suite**

```bash
claude plugin validate ./woobin-harness
./scripts/test-hooks.sh
./scripts/test-skills.sh
DRY_RUN=1 ./bootstrap.sh
```

Expected: all four exit 0. `test-skills.sh` prints `21 packaged skills`.

Do not skip `claude plugin validate`. It is the only thing that catches a colon-plus-space inside a frontmatter `description:`, which silently voids every frontmatter field while the runtime keeps looking normal.

- [ ] **Step 6: Run the Codex validator and confirm it fails for the known reason**

```bash
./scripts/validate-codex.sh; echo "exit=$?"
```

Expected: **non-zero exit**, with the failure naming `woobin-harness/skills/kick-off/SKILL.md` and `disable-model-invocation`. That is the documented intentional failure (`docs/codex-compatibility-audit-2026-08-12.md:55`). If it fails for any *other* reason — for example a skill-count mismatch or an unresolved `interview` path — that failure is real and belongs to this plan.

- [ ] **Step 7: Commit**

```bash
git add woobin-harness/.claude-plugin/plugin.json woobin-harness/.codex-plugin/plugin.json
git commit -m "chore(plugin): 1.15.0 → 1.16.0 (interview 개명 + 되물음 메뉴 재구성 규칙)"
```

`~/.claude/settings.json` is outside the repo and is not committed. Say so explicitly in the PR body so a second machine knows it needs the same one-key edit.

- [ ] **Step 8: Refresh the installed plugin**

```bash
claude plugin marketplace update woobin-harness
claude plugin update woobin-harness@woobin-harness
```

Use the fully-qualified `woobin-harness@woobin-harness`; the short name fails with `not found`. Then restart Claude Code — the update command says `Restart to apply`. Until that restart, `/interview` will not exist and `/grill-me` will still resolve from the 1.15.0 cache copy.

- [ ] **Step 9: Confirm the installed copy actually moved**

```bash
ls ~/.claude/plugins/cache/woobin-harness/woobin-harness/ | tail -2
jq -r '.plugins["woobin-harness@woobin-harness"][].version' ~/.claude/plugins/installed_plugins.json
test -f ~/.claude/plugins/cache/woobin-harness/woobin-harness/1.16.0/skills/interview/SKILL.md \
  && echo "installed copy has the renamed skill" \
  || echo "FAIL: installed copy is stale"
```

Expected: `1.16.0` present in the cache listing, `1.16.0` installed, and `installed copy has the renamed skill`.

If the marketplace source is the GitHub remote rather than this worktree, the update pulls the merged branch — this check will only pass after the PR merges. In that case record the result as pending in the PR body rather than forcing it locally.
