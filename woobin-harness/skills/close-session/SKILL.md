---
name: close-session
description: Mark this session as finished so the idle auto-handoff hook does not wake up and write a handoff document for it.
disable-model-invocation: true
---

The user has declared this conversation finished.

Normally `idle-return-guard.sh` intercepts `/close-session` at the `UserPromptSubmit` hook and blocks it, so this skill never runs — that path costs zero tokens. If you are reading this, the interception did not happen, so do the same thing here.

Run exactly this, and nothing else:

```bash
mkdir -p ~/.claude/idle-handoff && touch ~/.claude/idle-handoff/"$CLAUDE_CODE_SESSION_ID".handoff-done
bash ~/.claude/hooks/close-session-cleanup.sh "$PWD"
```

`CLAUDE_CODE_SESSION_ID` is set in the Bash tool environment and matches the `session_id` the hooks receive on stdin — do not try to derive the id any other way.

The second command cleans up worktrees and branches, and checks disk and memory headroom. It is the same script the hook runs, so the rules live in one place — do not reimplement its checks here, do not pass it extra flags, and do not "fix up" anything it declined to remove or clean.

- Worktrees: it removes one only if it is simultaneously clean, merged into `origin/<default>`, and unlocked; everything else it reports and leaves alone.
- Disk: below 20GB free or at/above 85% used, it prunes docker dangling images and build cache, then reports the remaining reclaimable space as a suggestion. It never touches volumes (dev/prod DBs live there), tagged images, or npm/system caches.
- Memory: below 10% free, it reports the top RSS consumers. It never kills a process.

Under the thresholds it prints nothing at all. That conservatism is the design, not a gap — do not run prune commands yourself to "finish the job".

Then reply with this line, followed verbatim by the script's output if it printed any, and end the turn:

> 🔒 세션을 닫았습니다 — 자리비움 자동 핸드오프를 만들지 않아요. 이 세션에 다시 프롬프트를 보내면 자동으로 해제됩니다.

Do not summarise the conversation, do not write a handoff document, do not read files, and do not ask the user anything — including about the worktrees the script left behind. The whole point is to spend as little as possible on a session that is already over.
