---
name: close-session
description: Mark a Claude Code session as finished so the idle auto-handoff hook does not wake up and write a handoff document for it. Use only when the user explicitly invokes or requests close-session; Codex does not enable the idle auto-handoff hook.
---

The user has declared this conversation finished.

## Codex

Do not derive or invent a session id. The Codex hook set intentionally omits the asynchronous idle handoff because Codex does not support asynchronous command hooks. Tell the user that no idle handoff is scheduled and stop. Do not run the Claude cleanup commands below.

## Claude Code

Normally `idle-return-guard.sh` intercepts `/close-session` at the `UserPromptSubmit` hook and blocks it, so this skill never runs — that path costs zero tokens. If you are reading this, the interception did not happen, so do the same thing here.

In Claude Code, run exactly this, and nothing else:

```bash
mkdir -p ~/.claude/idle-handoff && touch ~/.claude/idle-handoff/"$CLAUDE_CODE_SESSION_ID".handoff-done
bash "$CLAUDE_PLUGIN_ROOT/lib/close-session-cleanup.sh" "$PWD"
```

`CLAUDE_CODE_SESSION_ID` is set in the Bash tool environment and matches the `session_id` the hooks receive on stdin — do not try to derive the id any other way.

The second command reclaims what the session left running and checks disk and memory headroom. It is the same script the hook runs, so the rules live in one place — do not reimplement its checks here, do not pass it extra flags, and do not "fix up" anything it declined to remove or clean.

- Worktrees: it removes one only if it is simultaneously clean, merged into `origin/<default>`, and unlocked; everything else it reports and leaves alone.
- Disk: below 20GB free or at/above 85% used, it prunes docker dangling images and build cache, then reports the remaining reclaimable space as a suggestion. It never touches volumes (dev/prod DBs live there), tagged images, or npm/system caches.
- Memory threshold: below 10% free, it reports the top RSS consumers. That report never kills anything.
- Automation browsers: it kills any browser carrying an e2e/MCP signature (`--remote-debugging-pipe|-port`, `--enable-automation`, `--headless`, or a `--user-data-dir` under ms-playwright/puppeteer/a temp dir). This matches on process arguments, not app name, because a Playwright-launched Chrome is also just called "Google Chrome" — and it ignores frontmost and the keep list, since the profile is throwaway. Opt out with `CLOSE_SESSION_KEEP_AUTOMATION=1`.
- Docker stacks: it stops (never `down`s) compose projects whose `working_dir` label sits inside this repo or one of its worktrees — those are what the session started. Everything else, including non-compose containers, it only counts and reports. Volumes are never touched, so dev/prod DBs survive; `docker start` restores what it stopped. Opt out with `CLOSE_SESSION_KEEP_DOCKER=1`.
- Apps: it quits idle GUI apps (and the Claude Desktop VM) a session may have left running. Policy comes from `~/.claude/close-session-keep.conf`, falling back to `lib/close-session-keep.conf.default` in this plugin: `keep|<App>` never quits, `ondemand|<App>` quits only when that run names it, `idle|<App>|<days>|<paths>` quits once the activity paths have gone untouched that long. Docker projects use the same policy under the name `docker/<project>`. Anything it cannot decide, it keeps.

Per-run overrides: `CLOSE_SESSION_KEEP_APPS="A:B"` and `CLOSE_SESSION_QUIT_APPS="A:B"` — colon-separated, because app names contain spaces. If an app is in both, keep wins. When the user asks to also close the on-demand apps, re-run the script with `CLOSE_SESSION_QUIT_APPS` naming them; never kill anything yourself.

To change the policy, edit the conf — not this skill and not the script. `CLOSE_SESSION_DRY_RUN=1` decides everything, kills nothing, and prints why each app was kept.

Under the thresholds it prints nothing at all. That conservatism is the design, not a gap — do not run prune commands yourself to "finish the job".

Then reply with this line, followed verbatim by the script's output if it printed any, and end the turn:

> 🔒 세션을 닫았습니다 — 자리비움 자동 핸드오프를 만들지 않아요. 이 세션에 다시 프롬프트를 보내면 자동으로 해제됩니다.

Do not summarise the conversation, do not write a handoff document, do not read files, and do not ask the user anything — including about the worktrees the script left behind. The whole point is to spend as little as possible on a session that is already over.
