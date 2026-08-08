# Token & Prompt-Caching Efficiency

Two parts: **Static** checks (always, from the repo) and **Sessions** analysis (only if session logs exist). Never fabricate numbers — if there are no logs, say so and skip Sessions.

## Caching mechanics (ground truth — verify against Anthropic docs before quoting)
- Default TTL **5 min**, refreshed on each cache hit; optional 1-hour TTL.
- Cache **read = 0.1×** base input; **5-min write = 1.25×**; 1-hour write = 2.0×. (Opus 4.8 @ $5/MTok → write $6.25, read $0.50.)
- Minimum cacheable prefix ≈ **1,024 tokens** (Opus 4.8 / Sonnet 5); below threshold = silently uncached.
- Invalidation cascades **tools → system → messages**. One byte changed high in the prefix busts everything downstream. A 20-block lookback window means a long, growing conversation can miss + pay the write premium — add a second breakpoint near stable content.

---

## Static caching hygiene (always)
Inspect the repo's agent context for things that would silently 10× input cost by breaking the stable prefix:

- **Dynamic values at the prefix head.** Timestamps, `current date`, `git rev-parse HEAD`, per-run counters injected at the *top* of `CLAUDE.md` / a system-context hook → new hash every request → never a cache hit. Fix: move dynamic content *below* the stable docs.
- **Oversized context files.** A `CLAUDE.md` far over a few hundred lines both wastes budget every turn and risks pushing past the cache prefix. Flag for splitting via progressive disclosure.
- **Per-invocation content mixed into static docs.** Anything that varies run-to-run interleaved with otherwise-stable instructions.
- **Model-switching guidance.** Note if the workflow encourages switching models mid-session (Opus→Sonnet) — that busts the cache entirely; fine between tasks, costly mid-task.

Report as: "정적 캐싱 위생: 이상 없음" or a bulleted list of specific offenders with file:line.

---

## Session-log analysis (only if logs available)
Claude Code logs typically live at `~/.claude/projects/**/*.jsonl` (one JSON object per line, with usage fields: `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`). If none found, skip and say so.

Aggregate across a project's recent sessions and score four axes:

| Axis | Weight | Formula | Healthy | Reads as |
|---|---|---|---|---|
| **Cache utilization** | 40% | `cache_read / total_input` | ≥ 0.85 | low = re-reading same tokens each turn (prefix churn) |
| **Output density** | 20% | `output / input` | ~2% (roughly 1–5%) | very low = read-heavy thrash; very high = verbose monologue |
| **Duplicate-read ratio** | 20% | repeated file reads without narrowing (grep/glob between) | low | navigation thrash — repo hard to find things in |
| **Tool-use efficiency** | 20% | tool calls per 1k output tokens | 2–10 | 20+ = thrashing |

Grade the token axis A+ ≥90 … F <40 and fold the finding into the report's "토큰·캐싱" section. A low cache-utilization score usually points straight back at the Static offenders above, or at a poorly-structured repo forcing re-exploration each turn — connect the two.

### How to compute (portable, no dependency on the blog's scripts)
You can do this with a short `jq`/`python3` one-liner over the `.jsonl` files, or delegate to a subagent. Sum the usage fields per session, apply the formulas, average across sessions. Keep it read-only. Report the actual numbers with the files you read — never estimate.

---

## Cost gates (optional recommendation, not scored)
If the user wants running-cost guardrails, suggest (don't build unless asked):
- **Per-session gate:** warn/confirm past a cumulative token threshold (e.g. 300k).
- **Per-PR gate:** CI label when an agent-assisted PR's estimated cost exceeds a ceiling.
These normalize cost by making it visible on a shared dashboard rather than by nagging.
