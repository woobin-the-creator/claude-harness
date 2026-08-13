# Implementation contracts

## Load this module when

Load when changing or designing reusable UI behavior, component APIs, validation, overflow, overlays, async states, semantic formatting, or guard selection.

## Choose the lowest effective enforcement layer

Start with this reuse order unless the established project has a stricter order:

```text
existing design system → native HTML → accessible primitive → custom implementation
```

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

Initial focus follows task safety. Destructive confirmation starts on input or cancel, never the danger action. Escape behavior derives from modality and dismissibility, not a component name.

## Async state contract

```text
idle → pending → success | error, with label + icon + action state synchronized
```

Pending prevents duplicate submit. Preserve stable data while refreshing when stale content is still truthful. Suppress saving feedback before the first dirty input.

## Formatting and semantic-state contract

Invalid, missing, unknown, and zero states need distinct representations. Prefer `Intl.NumberFormat(locale, { notation: 'compact' })` over hand-built K/M/B. Severity uses shape/text and color, not color alone.

## Portable pattern catalog

| Source observation | Portable treatment |
|---|---|
| Raw color/spacing/type/easing | Prefer the project's existing token-aware Stylelint/ESLint rule; add no Carbon dependency by default |
| Data column width | Include header and representative cells in measurement; reserve sort/action affordances; use project-derived min/max rather than universal 58/400 values |
| Truncation tooltip | Attach `title` or tooltip only after actual overflow measurement |
| Action groups | Validate count/kinds separately from order normalization and render refusal; vertical order may differ only when the project's reading/action order requires it |
| Destructive confirmation | Initial focus goes to confirmation input or cancel, never danger; pending state prevents duplicate submit |
| Tag/filter overflow | Measure item margins, trigger width, and persistent action width; use prefix fit rather than a fixed slice |
| Loading existing data | Preserve stable data while refreshing when stale content is still truthful; do not universally append skeleton rows |
| Compact numbers | Use locale-aware `Intl.NumberFormat`; avoid redundant equal numerator/denominator display |
| Missing/unknown/zero | Use distinct semantic states and copy |
| Severity | Convey with shape/text and color, not color alone |
| Numeric alignment | Align numeric headers and body cells together |
| Panel Escape behavior | Derive Escape from modality and dismissibility, not the component name `SidePanel` |
| Clipped actions | Preserve access by relocating or pinning controls when scroll clipping would remove them |
| Nested overlays | Define a project maximum and refuse/warn beyond it; do not universalize IBM's depth of three |
| Overflow ladder | Inline → overflow disclosure → searchable surface when measured volume/cost crosses a project threshold |
| Saving feedback | Keep label/icon/action state synchronized and suppress status before the first dirty input |
| Search vs filter | Search locates matching results; filters constrain attributes, including attributes not rendered as columns; batch apply is a product choice, not a universal default |

## Project-stack adaptation

React: map contracts to component props, hooks, Testing Library, axe, and browser tests already used by the project.

Vue: map contracts to props/emits/composables, Vue Test Utils, axe, and project browser tests.

CSS: prefer token-aware lint rules, semantic class patterns, and browser assertions for measured layout or clipping.

Do not ship framework runtime code in the skill.

## Verification before promotion

Before promotion, show local evidence, false-positive risk, rollback path, and the lowest effective enforcement layer. Carbon-specific values and APIs remain external examples.
