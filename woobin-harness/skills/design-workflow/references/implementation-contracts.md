# Implementation contracts

## Load this module when

Load when changing or designing reusable UI behavior, component APIs, validation, overflow, overlays, async states, semantic formatting, or guard selection.

## Choose the lowest effective enforcement layer

Each step away from what already exists re-implements behavior someone else got right — keyboard handling, form semantics, assistive-technology mapping, and the conventions users arrive with (`principles.md`, Jakob). That is the reason for the usual order:

```text
existing design system → native HTML → accessible primitive → custom implementation
```

A project with a stricter order of its own wins over this one.

For each adopted pattern, choose prose, a shared component/API, a static scanner, a unit/a11y/browser test, or a CI gate. CI gates and public API changes require approval.

## Input normalization contract

```text
input → validate → normalize → render | refuse
```

Warning, normalization, and render refusal are separate choices. Validate dirty input, normalize only when the result is unambiguous, and refuse rendering when continuing would misrepresent state or create risk.

## Measured overflow contract

```text
measure → reserve affordance → prefix-fit → stable update
```

Measure actual item, margin, action, and overflow-trigger widths instead of using a fixed slice. Include header and body together for data columns, reserve sort/action affordances, and derive min/max from project evidence.

## Overlay lifecycle contract

```text
open → initial focus → presence/close → launcher focus return
```

Initial focus follows task safety: when the dialog opens with focus on the danger action, a keyboard Enter destroys data, so confirmation starts on the input or on cancel. Escape behavior derives from modality and dismissibility, not from a component name.

## Async state contract

```text
idle → pending → success | error, with label + icon + action state synchronized
```

Pending prevents duplicate submit. Preserve stable data while refreshing when stale content is still truthful. Suppress saving feedback before the first dirty input.

## Formatting and semantic-state contract

Invalid, missing, unknown, and zero mean different things, so collapsing them into one representation makes the interface lie. Hand-built K/M/B abbreviations do not survive a locale change, which is what `Intl.NumberFormat(locale, { notation: 'compact' })` exists for. Color alone excludes anyone who cannot separate the hues, so severity needs shape or text as well.

## Observed cases

These are things that went wrong in real products, kept as evidence rather than as instructions. None of them decides the current task — read what failed, then check whether this project has the same exposure. Provenance is in `sources.md`.

| Case | What it showed |
|---|---|
| Raw color/spacing/type/easing values | Token-aware Stylelint/ESLint rules catch these where a project already has them; pulling in a vendor dependency to obtain the check is a larger commitment than the check is worth |
| Data column width | Widths derived from body cells alone broke once headers and sort/action affordances were included, and the vendor's 58/400 bounds came from its own content |
| Truncation tooltip | Tooltips attached without measuring announced truncation that had not happened |
| Action groups | Count/kind validation, order normalization, and render refusal are three separate failures; collapsing them hid which one fired |
| Destructive confirmation | Initial focus on the danger action made a keyboard Enter destructive, and without a pending state the same submit fired twice |
| Tag/filter overflow | A fixed visible count ignored item margins, trigger width, and persistent action width, so the row overflowed anyway |
| Loading existing data | Replacing still-truthful data with skeleton rows during a refresh lost the user's place |
| Compact numbers | Rendering an equal numerator and denominator added no information |
| Missing / unknown / zero | Collapsed into one fallback, these three read identically while meaning different things |
| Severity | Conveyed by color alone, severity disappeared for part of the audience |
| Numeric alignment | Headers aligned separately from their body cells read as two columns |
| Panel Escape behavior | Escape derived from the component name `SidePanel` rather than from modality behaved differently in two panels that looked identical |
| Clipped actions | Scroll clipping removed controls entirely rather than making them harder to reach |
| Nested overlays | The vendor's depth limit of three came from its own products; an unbounded stack, however, left no way back |
| Overflow ladder | Inline, then overflow disclosure, then a searchable surface — where each threshold sits followed from measured volume and cost, not from the ladder itself |
| Saving feedback | Label, icon, and action state drifting apart left the user unsure whether a save happened, and status shown before the first dirty input announced a save that never occurred |
| Search vs filter | Search locates matching results while filters constrain attributes, including attributes not rendered as columns; whether filters apply immediately or in a batch was a product choice each time |

## Project-stack adaptation

React: map contracts to component props, hooks, Testing Library, axe, and browser tests already used by the project.

Vue: map contracts to props/emits/composables, Vue Test Utils, axe, and project browser tests.

CSS: prefer token-aware lint rules, semantic class patterns, and browser assertions for measured layout or clipping.

Do not ship framework runtime code in the skill.

## Verification before promotion

Before promotion, show local evidence, false-positive risk, rollback path, and the lowest effective enforcement layer. Carbon-specific values and APIs remain external examples.
