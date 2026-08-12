---
name: git-guardrails-codex
description: Set up Codex PreToolUse hooks that block dangerous Git commands such as push, reset --hard, clean -f, branch -D, checkout ., and restore . before execution. Use when the user wants project or global Git safety guardrails specifically for Codex, asks to prevent destructive Git operations, or wants a .codex/hooks.json policy.
---

# Set up Git guardrails for Codex

Install the bundled deterministic hook without overwriting existing hooks.

## 1. Choose scope

Ask whether to install for the current project or all projects:

- Project: `<repo>/.codex/hooks/block-dangerous-git.sh` and `<repo>/.codex/hooks.json`
- Global: `~/.codex/hooks/block-dangerous-git.sh` and `~/.codex/hooks.json`

## 2. Copy the script

Copy [scripts/block-dangerous-git.sh](scripts/block-dangerous-git.sh) to the selected hooks directory and make it executable. Preserve the bundled source.

## 3. Merge the hook

Merge this matcher group into `hooks.PreToolUse`; do not replace other groups:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "<absolute-path>/block-dangerous-git.sh",
            "statusMessage": "Checking Git command"
          }
        ]
      }
    ]
  }
}
```

Use an absolute command path. Codex may start in a nested directory, so do not rely on a relative `.codex/hooks/...` path.

## 4. Verify

Run both cases against the copied script:

```bash
printf '%s' '{"tool_input":{"command":"git push origin main"}}' | <script-path>
printf '%s' '{"tool_input":{"command":"git status --short"}}' | <script-path>
```

Require exit code `2` with a `BLOCKED` reason for the first and exit code `0` for the second.

Tell the user to open `/hooks` in Codex and trust the new or changed hook definition. Until that review is complete, Codex skips the command hook.

## 5. Customize only on request

If the user asks to add or remove patterns, edit the installed copy. Keep the bundled source unchanged unless they explicitly want to update the reusable skill.
