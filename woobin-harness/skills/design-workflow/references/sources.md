# Sources

## External sources

- `interface-design` at `2f9be3206855bcb2d1d0af262c8bae25cba6658d`, MIT. Relevant paths: `skills/interface-design/SKILL.md`, `skills/interface-design/references/review.md`, `skills/interface-design/references/deslop.md`, and `skills/interface-design/templates/system.md`.
- `carbon-design-system/ibm-products` at `eeff1e98ac8332f60a90d015dea2ba7c38edd26d`, Apache-2.0. Relevant paths include ActionSet, `useOverflowItems`, RemoveModal, status definitions, Stylelint rules, achecker/Playwright accessibility checks, and CI examples.

This release paraphrases mechanisms. Substantial copied text or code requires preserving copyright and license notices.

## Local provenance

- Existing local `design-rules` skill supplied durable evidence behavior and review discipline.
- Issues #5, #6, #7, and #8 supplied accepted corrections and candidates.
- Commit `17994e0` supplied accepted KPI label, table density, truncation, and compact evidence outcomes; ownership is ported into shared modules instead of cherry-picked.
- Commit `a61a9ab` supplied additional local comparison context.

## Corrections from #8

1. Carbon APIs and values are not project defaults. Convert them to portable contracts and adapt through the target project stack.
2. Fixed visible counts such as “first three items” are weaker than measured overflow using item, margin, trigger, and persistent action widths.
3. Accessibility and status behavior must distinguish warning, normalization, refusal, pending, success, error, missing, unknown, and zero instead of collapsing them into color or one generic fallback.

## Boundary rule

Record repository, commit, path, and license for external precedent. Do not promote external behavior to `adopted` without local evidence, and do not copy substantial upstream prose or code into this skill.
