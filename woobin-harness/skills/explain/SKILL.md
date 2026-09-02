---
name: explain
description: Write a self-contained explanation of a result, decision, status, cause, or next step for a reader who may lack thread or project context. Use when the reader asks for a simpler explanation, says they did not understand, or when the answer must survive outside this conversation. Korean triggers — "더 쉽게 설명해줘", "초등학생 수준으로", "무슨 말인지 모르겠어", "상위 맥락부터", "쉽게 풀어줘".
---

# Explain

Write the final user-facing answer so it stands on its own at the reader's
demonstrated level of familiarity. Restore missing context only where it helps
the reader understand the answer or act on it.

## Calibrate the reader's starting point

Infer the lowest missing layer from the user's wording and prior feedback. Do
not ask a calibration question when the prompt already gives a usable signal.

- **Direct** — The reader uses the relevant identifiers and domain vocabulary
  confidently. Answer first; define only thread-local names.
- **Situated** — The reader knows the domain but not this project or thread.
  Briefly establish the system's purpose and the named components' roles before
  explaining the result.
- **Foundation-first** — The reader asks for a simple explanation, lacks the
  underlying background, or did not understand the previous answer. Start with
  purpose and actors, then introduce the mechanism and the exact identifiers.

Default to situated when there is no reliable signal. A request for more
context asks for a higher-level frame; a request for simpler language asks for
fewer assumed prerequisites.

**If an explanation did not land, change its entry point and vocabulary rather
than repeating it with more detail.** Restating the same frame at greater
length is the common failure — the reader did not need more words, they needed
a different starting layer.

## Make the answer self-contained

- Lead with the outcome or central point. Name the subject before using "it",
  "this", or "the change".
- Define unfamiliar acronyms, local labels, files, or options on first use when
  the name alone would not orient a new reader.
- Supply the minimum background and causal chain that shows why the result
  matters and how the conclusion follows.
- Separate verified facts and completed work from assumptions, proposals,
  limitations, and pending work. Include evidence when it affects confidence.
- Preserve exact identifiers when they let the reader verify or continue the
  work, but introduce them after the conceptual model when the reader needs
  that foundation first.
- Do not replay the conversation, the tool calls, or the search process unless
  that history is itself the subject.

For a foundation-first explanation: establish the purpose, introduce the few
necessary actors, show the event as simple causal steps, and finish with the
current state. Use an analogy or a compact mapping table only when it makes a
relationship materially clearer, and map it back to the real system.

## Use proportionate structure

Keep a short, single-topic answer to one or two paragraphs. For multiple
workstreams, decisions, or mixed completion states, use descriptive headings
and organize by subject rather than by conversation chronology. Integrate
status, verification, limitations, and remaining work instead of repeating the
same facts in an overview and again in detail.

End with the concrete next action and its owner, or state that no action
remains. Distinguish states with different consequences — created versus
committed, committed versus pushed, an open pull request versus a merged one.
Never invent a clean state, a verification result, a blocker, or a next step to
make the ending sound decisive.

## Handle missing context

Never invent context to make an answer feel complete. If an unresolved detail
would materially change the answer, name the exact gap and ask only for what is
needed. Otherwise state the bounded assumption and continue.

Before sending, cold-read the answer as if it had been pasted into a fresh
thread. Revise if the subject, a local term, the conclusion, the evidence, the
current state, or the next action would be unclear there — or if the answer
assumes a prerequisite the reader has not shown.

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
  separate from what was assumed. The title is a single line that outlives the
  branch, so it carries the problem — not the branch name, not the file count.

Output formatting and answer density follow the active output style and the
global `CLAUDE.md` density rules. This skill decides **which layer to start
from**, not how long the answer is.
