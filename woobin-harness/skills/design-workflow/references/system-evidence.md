# System and evidence

## Load this module when

Load when a task needs repository design evidence, local authority order, content-derived dimensions, a11y evidence, or durable rule recording.

## Authority order

Project values beat skill defaults. Prefer `user-decision`, then adopted `DESIGN.md` decisions, then local component/token code, then local incidents, then external precedent.

External precedent can inform a `candidate`, but it does not become adopted policy without local evidence.

## Scope the repository read

Read the smallest set of real authorities: component sources, token files, CSS, design docs, tests, and relevant routes. Screenshots alone are not authority.

Inspect actual minimum and maximum content before deciding dimensions. Use real headings, body copy, numbers, empty states, and localized strings when available.

## Classify what you find

Classify evidence as `user-decision`, `local-code`, `local-incident`, or `external-precedent`. Observed code is not automatically a durable rule.

Keep a compact rule record with wrong form, replacement, and observed consequence. Move long evidence to a linked reference.

## Tone and foundations

Use type size, weight, and color together for hierarchy. The project’s adopted depth strategy beats generic border or shadow preferences.

Nested surfaces may use concentric radii when the project depth strategy calls for radii. Optical alignment may override naive geometric centering when the reason is explicit.

Avoid treating `transition: all` or layout-property animation as defaults.

## Content-derived dimensions

Use actual content to size layouts. Dynamic numeric columns may use `tabular-nums`.

KPI labels and table headers need enough size, weight, and color contrast, but do not blindly enlarge every label. Separate a label from its value by weight, not by tone: give the label slightly more size and weight and the same contrast grade as the value. Observed: a mockup rendered labels at nearly the same tone as their values, so neither read first.

Table cells default to a compact 한 줄 unless an explicit multiline variant is selected. Headings and body copy define long-text wrapping behavior.

## Information density and truth

Ellipsis communicates truncation. Attach `title` or tooltip 실제로 잘렸을 때만, after measuring or otherwise proving overflow.

State when a dense layout is preserving useful scan speed versus when it hides truth.

For tables, fitting more rows and columns into one screen is the first principle. A cell that needs two lines is a signal to revisit the column width or the value format, not to let the row grow. Observed: wrapping a date-range and a notes column doubled those rows and cut the visible row count; reformatting the range to `08-11 > 08-12` restored it.

## Accessibility evidence

Measure light and dark contrast instead of inferring from color names. WCAG 2.2 AA target-size minimum is 24×24 CSS px with exceptions; 44×44 is AAA enhanced or a product recommendation, not AA.

Check focus order, keyboard access, reduced motion, label relationships, and color-independent state cues when interaction is in scope.

## Self-comparison

Compare the proposed result against the no-discipline default and state the useful difference: what became clearer, safer, faster, or more honest.

## Record durable evidence

Record only decisions that are useful beyond the current patch. Do not turn a local observation into adopted policy without user approval.
