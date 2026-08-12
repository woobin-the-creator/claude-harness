# Design document

## Purpose

`DESIGN.md` is optional project state. Missing files and unmanaged existing notes are valid and never block direction, implementation, review, or enforcement work.

## When to suggest creating it

Suggest the template only when the project has durable direction, a project-specific override, a repeated incident worth tracking, an accepted external precedent, or a concrete enforcement path. Do not overwrite an unmanaged file; ask before creating or migrating.

## Managed format

A managed file has initial frontmatter with `design_workflow.enabled: true`, `schema_version: 1`, and exactly one marker-delimited JSON block:

```text
<!-- design-workflow:data:start -->
```json
{ "...": "..." }
```
<!-- design-workflow:data:end -->
```

Narrative prose is for explanation. Token values, prop inventories, component APIs, and exact constants stay in code; `DESIGN.md` links to the authority path that owns them.

## Enums

Project states: `greenfield`, `established`, `mixed`, `legacy`.

Direction statuses: `unset`, `candidate`, `adopted`.

Decision statuses: `observed`, `candidate`, `adopted`, `component-enforced`, `ci-enforced`, `retired`.

Source types: `user-decision`, `local-code`, `local-incident`, `external-precedent`.

Enforcement types: `component`, `static`, `unit`, `a11y`, `browser`, `ci`.

An external precedent remains `candidate` until local evidence exists. It cannot become `adopted`, `component-enforced`, or `ci-enforced` from upstream reputation alone.

## Approval boundary

Agents may record observations, candidates, and accepted user decisions. They must ask before changing public component APIs, enabling a CI failure gate, removing waivers, broad-migrating legacy UI, or promoting an external precedent without local evidence.

## Validator outputs

Stable success states:

- `DESIGN_ABSENT path=<absolute-path>` for no file.
- `DESIGN_UNMANAGED path=<absolute-path>` for an existing file without managed frontmatter.
- `DESIGN_OK schema=1 decisions=<count>` for a valid managed file.

Implemented diagnostics:

- `DESIGN_E_ROOT`: JSON root is not an object.
- `DESIGN_E_SCHEMA`: JSON `schemaVersion` is unsupported.
- `DESIGN_E_FRONTMATTER_SCHEMA`: managed frontmatter is missing schema version `1`.
- `DESIGN_E_PROJECT_STATE`: unknown project state.
- `DESIGN_E_DIRECTION_STATUS`: unknown direction status.
- `DESIGN_E_AUTHORITIES`: authorities is not an array.
- `DESIGN_E_AUTHORITY_ITEM`: authority lacks a kind or safe relative path.
- `DESIGN_E_DECISIONS`: decisions is not an array.
- `DESIGN_E_ID`: decision id is not kebab-case.
- `DESIGN_E_ID_DUPLICATE`: decision id is repeated.
- `DESIGN_E_STATUS`: unknown decision status.
- `DESIGN_E_SOURCE`: unknown source type.
- `DESIGN_E_RULE`: rule is empty.
- `DESIGN_E_REFERENCES`: source references is not an array.
- `DESIGN_E_LOCAL_EVIDENCE`: local evidence is not an array.
- `DESIGN_E_ENFORCEMENT`: enforcement is not an array.
- `DESIGN_E_WAIVERS`: waivers is not an array.
- `DESIGN_E_INCIDENT_EVIDENCE`: local incidents lack source references or local evidence.
- `DESIGN_E_EXTERNAL_NEEDS_LOCAL_EVIDENCE`: adopted external precedent lacks local evidence.
- `DESIGN_E_ENFORCEMENT_REQUIRED`: enforced status lacks enforcement records.
- `DESIGN_E_ENFORCEMENT_ITEM`: enforcement item lacks known type or safe relative path.
- `DESIGN_E_WAIVER`: waiver lacks reason, owner, or `YYYY-MM-DD` expiry.
- `DESIGN_E_MARKERS`: managed file lacks exactly one ordered marker pair.
- `DESIGN_E_DATA_BLOCK`: marker contents are not exactly one fenced `json` block.
- `DESIGN_E_JSON`: JSON failed to parse.
- `DESIGN_E_PATH_MISSING`: local authority, evidence, reference, or enforcement path is absent.
- `DESIGN_E_PATH_OUTSIDE_REPO`: referenced path would leave the repository root.
