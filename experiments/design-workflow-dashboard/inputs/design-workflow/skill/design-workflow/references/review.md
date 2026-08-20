# Review

## Load this module when

Load for render review, UX QA, visual regression triage, accessibility interaction checks, or when the user asks for review-only feedback.

## Establish scope and authority

Identify the changed surface, intended user path, existing design authorities, and whether the task is review-only. Filter intentional adopted decisions before reporting findings.

## Render matrix

Use the smallest material matrix, expanding for risky changes:

- desktop and mobile;
- shortest and longest representative values;
- loading, empty, and error;
- light and dark when both themes exist;
- focus, keyboard, and reduced-motion for interactions;
- clipping, overlap, and layout shift.

## Craft tests

Squint: blur attention and check hierarchy.

Swap: exchange adjacent labels, icons, or states and see whether meaning survives.

Signature: verify the selected signature and focal point are visible, not decorative noise.

Token: compare color, spacing, radius, depth, and motion to project authorities.

## Interaction and accessibility

Exercise pointer, keyboard, focus return, reduced motion, screen-reader labels where relevant, color-independent severity, and target size. Report only reproducible states.

## Findings format

Use `blocker`, `should-fix`, or `note`. Include reproducible state, authority/evidence, impact, and the smallest suggested correction.

`blocker` means the user path fails, data becomes misleading, controls are inaccessible, or a dangerous action is easy to trigger by mistake.

`should-fix` means quality or consistency is materially below the adopted system but the path still works.

`note` means useful context, low-risk polish, or an intentional tradeoff to record.

## Review-only boundary

In review-only mode, never mutate code, files, dependencies, or CI. If a fix is obvious, describe it and ask before editing.

## Unverified output

Mark any finding unverified when the render state, browser, theme, data range, or assistive behavior was not directly exercised.
