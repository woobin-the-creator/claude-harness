---
name: design-workflow
description: "Route product UI work through conditional direction, project evidence, implementation contracts, render review, and rule evolution. Use explicitly for first adoption, redesign, design review, or recurring UI failures; also use implicitly for UI work when a managed DESIGN.md enables design_workflow."
---

# Design workflow router

DESIGN.md가 없어도 작업을 멈추지 않는다. 파일은 디자인 기억을 영속화하는 선택적 장치다.

## Startup contract

1. Inspect only enough project context to classify the task.
2. If `DESIGN.md` is absent, continue and use code, tokens, and adjacent UI as temporary authority.
3. If it exists without the managed marker, treat it as `DESIGN_UNMANAGED`; do not overwrite it.
4. If managed, run `scripts/validate-design-md.mjs` before trusting lifecycle data.
5. If the validator exits non-zero, report stable `DESIGN_E_*` diagnostics, do not trust lifecycle or design decisions, and ask the user to choose: fix the document, or ignore the managed document for this task and continue with code/tokens/adjacent UI as temporary authority.
6. Do not treat an invalid managed document as unmanaged, and do not auto-fix it.
7. Announce the route once in commentary using `작업 유형: <mode> · 사용 모듈: <ordered modules>`.
8. Read only the references listed for that route.

The router must not always run every module. If the user explicitly requests a module override, record why the route changed.
In review-only mode, do not edit files.

## Route matrix

| Situation | Ordered modules | Required behavior |
|---|---|---|
| Existing project, first explicit use | system-evidence → implementation-contracts → review | Scope inspection to current work; propose DESIGN.md only after durable value appears |
| Greenfield | direction → system-evidence → implementation-contracts → review | Obtain approval for direction before adoption |
| Established incremental UI | system-evidence → implementation-contracts → review | Skip direction |
| Large redesign | direction → system-evidence → implementation-contracts → review → evolution | Keep new direction candidate until approved |
| Review-only | system-evidence → review | Do not edit files |
| Recurring failure/enforce | system-evidence → implementation-contracts → evolution → review | Choose lowest effective guard; respect approval boundary |
| Render-invariant logic | none | State that this skill does not apply and continue normal engineering work |

## Module paths

- direction: `references/direction.md`
- system-evidence: `references/system-evidence.md`
- implementation-contracts: `references/implementation-contracts.md`
- review: `references/review.md`
- evolution: `references/evolution.md`
- DESIGN.md contract: `references/design-document.md`
- validator: `scripts/validate-design-md.mjs`

## Optional persistence

Suggest `templates/DESIGN.md` only after one of these exists:

- an adopted direction;
- a project-specific override;
- a repeat incident;
- an accepted external precedent;
- an enforcement path.

Ask once at the end of the work, not before implementation. If declined, continue and do not repeat during the same task. A managed document enables implicit invocation on later UI work; absence means explicit invocation remains the default.

## Automatic actions

- Report existing code and tokens as `observed`.
- Attach evidence from tests actually run.
- Implement an in-scope component or test guard the user requested.
- Mark a decision `component-enforced` only after its implementation and verification path exist.

## Approval-required actions

- Promote `candidate` to the project's adopted default.
- Add a dependency or break a public component API.
- Migrate broad existing UI.
- Enable a CI failure gate.
- Remove legacy behavior, exceptions, or waivers.

“다시 발생하지 않게 막아줘” authorizes the in-scope component and test guard, but none of the approval-required expansions.
