# claude-harness

This repository is the shared source for a personal Claude Code and Codex harness.

Before changing it, read `CLAUDE.md` in full. That file is the canonical routing, ownership, versioning, and documentation-sync policy for both hosts. Treat Claude-specific install or validation commands there as host-specific; the Codex equivalents are documented in `README.md`.

Keep the runtime layers separate:

- Claude Code: `.claude-plugin/`, `woobin-harness/.claude-plugin/`, and `bootstrap.sh`.
- Codex: `.agents/plugins/`, `woobin-harness/.codex-plugin/`, `codex/`, and `bootstrap-codex.sh`.
- Shared: `woobin-harness/skills/` and the hook scripts. Do not fork a shared skill or script merely to change a path; prefer a small runtime adapter.

When the plugin changes, keep both plugin manifests on the same semantic version and run every validation command listed in `README.md`.
