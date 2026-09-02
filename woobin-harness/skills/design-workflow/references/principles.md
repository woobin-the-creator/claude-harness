# Principles

## Load this module when

Load first for any UI work. These are lenses, not rules — they cost little to hold and they change what you notice before you read the project's own authorities.

## What a principle is here, and what it is not

A principle explains **why a UI decision has consequences**. It does not tell you what to build.

This distinction is what keeps principles compatible with the authority order in `system-evidence.md`. A rule competes with project evidence — if the skill says "tables default to one line" and the project's own component wraps, one of them has to lose. A principle never competes, because it produces a *question*, and the project's code, tokens, incidents, and the user supply the *answer*.

So use these to decide what to look at and what to ask. Never quote one as the reason a design must take a particular form, and never convert one into a number. The published thresholds attached to several of these laws — a millisecond count, an item count, a ratio — came from studies of other products; the useful part is the mechanism, not the constant. When a principle suggests a threshold matters, measure it in this project.

If a principle and a local authority point in different directions, the local authority wins, and the disagreement is worth recording as evidence.

## Perception and grouping

These describe how the eye assembles a layout before anyone reads it. They are the most directly checkable of the set, because spacing, borders, and shared styling are all visible in the code.

**Proximity** — Things placed near each other are read as belonging together, and this happens faster than reading labels.
- Ask: does the whitespace inside each group stay smaller than the whitespace separating groups, or does the layout imply a grouping the data does not have?
- Weakens when: an explicit boundary or an alignment grid already carries the grouping, or the layout is a single undifferentiated list.

**Common Region** — A shared enclosure (a card, a panel, a ruled area) groups its contents even when they sit far apart.
- Ask: does every visible boundary correspond to a real conceptual group, and does every real group have a boundary or something equivalent?
- Weakens when: boundaries carry depth or elevation rather than grouping, which is a legitimate project choice recorded elsewhere.

**Similarity** — Elements that look alike are assumed to behave alike.
- Ask: do two things that share a style also share a function? A control styled like a label, or a static badge styled like a filter chip, teaches the wrong affordance.
- Weakens when: the shared styling is decorative and the difference in function is unmistakable from position or context.

**Uniform Connectedness** — Anything visually joined (a shared background, a connecting line, a continuous container) reads as more related than proximity alone can achieve.
- Ask: is the strongest visual connection on the screen the one you actually want emphasized?
- Weakens when: the connection is structural scaffolding the user is not meant to read as meaning.

**Prägnanz** — People resolve what they see into the simplest form that explains it.
- Ask: what is the simplest reading of this screen, and is that reading correct? A layout that is only correct under careful inspection will be misread.
- Weakens when: the domain requires irreducible detail and the simple reading would be a lie — see Tesler below.

## The cost of an interaction

**Fitts's Law** — The effort of hitting a target grows with distance and shrinks with size, so small or distant controls are slow and error-prone.
- Ask: is the hit area at least as large as the thing that looks clickable, and is a destructive control far enough from its neighbour that a slip is unlikely?
- Relation to existing rules: this is the reasoning behind the WCAG target-size floor recorded in `system-evidence.md`. The standard is the authority; this explains why it exists and why distance still matters when the size passes.
- Weakens when: the control is deliberately hard to reach because reaching it should require intent.

**Doherty Threshold** — Below some response time an interaction feels continuous; above it, attention detaches and has to be re-recruited.
- Ask: is this operation fast enough to need no feedback at all, slow enough to need progress, or in the band where a spinner appears and vanishes and reads as a flicker? Measure the real latency rather than assuming it.
- Relation to existing rules: this is why the async state contract in `implementation-contracts.md` separates pending from idle instead of always showing a loader.
- Weakens when: the wait is one the user expects and understands, where honest slowness beats manufactured immediacy.

**Hick's Law and Choice Overload** — Decision time rises with the number and complexity of options, and past some point people disengage or take the default rather than choose.
- Ask: what is this screen asking the user to decide, and is every option on it load-bearing for that decision? Options are cheap to add and expensive to read.
- Relation to existing rules: this is why `implementation-contracts.md` measures overflow instead of slicing at a fixed count — the right number depends on this project's items, not on a published one.
- Weakens when: the user is an expert scanning a known set, where a full list is faster than progressive disclosure.

**Jakob's Law** — People arrive with expectations formed by every other product they use, and they spend most of their time in those other products.
- Ask: has this design invented a new interaction for something that already has a convention — sign-in, pagination, date entry, search, destructive confirmation? Novelty here is paid for by every user, once each.
- Why this matters for generated UI in particular: inventing a plausible-looking variant of a standard control is cheap for a model and expensive for a user. When you notice yourself designing a control from scratch, check first whether the platform or the project already has one.
- Weakens when: the convention actively fails this product's task — a direction-level decision that belongs in `direction.md`.

## Attention and memory

**Chunking** — Information split into meaningful units is held and compared far more easily than the same information as an undifferentiated run. Miller's work is the usual citation; treat the famous capacity number as folklore and the chunking mechanism as the real finding.
- Ask: are long identifiers, numbers, and dates grouped the way a person would say them aloud, and are form fields sectioned by the user's task rather than by the database schema?
- Weakens when: the value exists to be copied rather than read, where inserted separators cause harm.

**Von Restorff Effect** — The one item that differs from its neighbours is what gets noticed and remembered.
- Ask: how many things on this screen are competing to be the emphasized one? Emphasis is a fixed budget; spending it twice spends it zero times.
- Note: this argues for scarcity of emphasis, not for a specific count of accent colours or primary buttons. How much a given screen can carry depends on its density and task — decide that there, not here.
- Weakens when: the screen is a deliberate parallel comparison where nothing should dominate.

**Serial Position Effect** — The first and last items in a sequence are recalled best, and the middle blurs.
- Ask: does the order of this navigation, list, or step sequence carry the importance you intend, and is anything critical buried mid-list?
- Weakens when: the order is meaningful in itself — chronological, alphabetical, ranked — where reordering for memorability would misinform.

**Selective Attention** — People filter aggressively toward their current goal and go blind to anything shaped like something irrelevant.
- Ask: is anything essential placed where users have learned nothing essential appears — a banner strip, a right rail, a dismissible bar?
- Weakens when: the message genuinely is optional, in which case the peripheral placement is correct.

## Where complexity is absorbed

**Postel's Law** — A system that accepts input generously and emits it precisely absorbs variation the user would otherwise have to manage.
- Ask: what shapes of input will real people paste here — trailing spaces, alternate date orders, formatted numbers, mixed case — and which of those can be resolved without guessing at intent?
- Relation to existing rules: this is the reasoning behind the input normalization contract in `implementation-contracts.md`, which is also where the limit lives — normalize only when the result is unambiguous, and refuse rather than guess.
- Weakens when: accepting a variant would silently change meaning, where refusing is the honest behavior.

**Tesler's Law** — Every task has complexity that cannot be removed, only relocated. Simplifying an interface moves work either into the system or onto the user.
- Ask: for this simplification, who absorbed the complexity? If the answer is the user, the interface got simpler and the product got worse.
- Weakens when: the complexity was accidental rather than inherent, in which case it can genuinely be deleted.

## How an experience is judged afterward

These describe recall and satisfaction rather than mechanics. They are review questions, not implementation checks — they mostly cannot be verified from a diff, and they belong to the discussion of a rendered result.

**Peak-End Rule** — An experience is remembered by its most intense moment and by its ending, not by its average.
- Ask: what are the peaks and the ending of this flow, and are those the moments getting attention? Error handling and completion states are usually both.

**Goal-Gradient Effect** — Effort intensifies as a goal appears closer, so visible progress accelerates completion.
- Ask: can the user see how far along they are and how much remains, and does progress already made stay visible?

**Zeigarnik Effect** — Unfinished tasks stay mentally active in a way finished ones do not.
- Ask: does an interrupted task leave a visible, resumable trace, or does the user have to carry it in their head?

**Aesthetic-Usability Effect** — Attractive designs are judged more usable, which means beauty can hide real usability failures — including from the person doing the review.
- Ask, of yourself during review: am I approving this because the user path works, or because it looks finished? This is the argument for exercising states rather than admiring a screenshot.

**Mental Model** — People act from an internal, compressed, frequently wrong model of how the system works.
- Ask: do labels, groupings, and error messages use the user's vocabulary and the user's model of the domain, or the implementation's?

**Paradox of the Active User** — People start using software immediately and do not read instructions, even when reading would be faster.
- Ask: is anything necessary for success available only in documentation, a product tour, or a first-run overlay?

## Provenance

These paraphrase widely published usability and perception findings collected at `lawsofux.com`; see `sources.md`. They enter this skill as external precedent, which under `system-evidence.md` informs a candidate and never becomes adopted project policy on its own.
