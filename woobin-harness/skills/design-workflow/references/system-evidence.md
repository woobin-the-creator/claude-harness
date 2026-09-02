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

The project's adopted depth and hierarchy strategy beats generic border, shadow, or type preferences. Read which signals it already uses to mark rank before introducing another one.

Nested surfaces may use concentric radii when the project depth strategy calls for radii. Optical alignment may override naive geometric centering when the reason is explicit.

## Content-derived dimensions

Use actual content to size layouts. Inspect real minimum and maximum content — headings, body copy, numbers, empty states, and localized strings — before fixing a dimension. Dynamic numeric columns may use `tabular-nums`.

Observed: a mockup rendered KPI labels at nearly the same size and tone as their values, so neither read first — the pair carried no rank at all. Which signal should carry that rank is a project decision; the observation only shows that something has to.

## Information density and truth

Ellipsis communicates truncation. Attach `title` or tooltip 실제로 잘렸을 때만, after measuring or otherwise proving overflow.

State when a dense layout is preserving useful scan speed and when it is hiding truth. Both happen, and only the content and the reader's task decide which.

Observed: a table wrapped a date-range column and a notes column to two lines, which halved the rows visible in one screen; reformatting the range to `08-11 > 08-12` restored them. The reformat moved the complexity into the value format instead of onto the reader's scrolling — see `principles.md` under Tesler for why that direction is the one worth checking.

## Accessibility evidence

Measure light and dark contrast instead of inferring from color names. WCAG 2.2 AA target-size minimum is 24×24 CSS px with exceptions; 44×44 is AAA enhanced or a product recommendation, not AA.

Check focus order, keyboard access, reduced motion, label relationships, and color-independent state cues when interaction is in scope.

## Self-comparison

Compare the proposed result against the no-discipline default and state the useful difference: what became clearer, safer, faster, or more honest.

## Record durable evidence

Record only decisions that are useful beyond the current patch. Do not turn a local observation into adopted policy without user approval.
