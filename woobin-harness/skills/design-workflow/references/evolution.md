# Evolution

## Load this module when

Load when deciding whether a design observation should become durable policy, whether enforcement should be added, whether a waiver should exist, or whether a rule should retire.

## Decision lifecycle

```text
observed → candidate → adopted → component-enforced → ci-enforced → retired
```

Observed means seen locally. Candidate means possibly general. Adopted means approved as durable project direction or rule. Component-enforced means the shared API makes the right behavior easy. CI-enforced means failures block merges. Retired means no longer active.

## Promotion evidence

Three related incidents trigger a generalization review, not an automatic promotion. Require a common cause, representative examples, false-positive estimate, lowest-effective-layer choice, and rollback path.

External precedent needs local evidence before adoption. Local code needs approval before becoming policy.

## Writing a rule

Fill three slots and keep each to one clause: wrong form, replacement, observed consequence. A list item holds all three on one line. Past three lines, move the rule into a linked reference or onto the enforcement ladder.

Keep the precedent. It is the only part a later session cannot recover by reading the code, and a rule stripped down to its prescription gets judged an exception.

Write the prescription as the action to take, not the action to avoid: "keep it to one line" rather than "no wrapping". A prohibition names the thing it prohibits and invites it back.

## Enforcement ladder

Prefer prose for rare judgment, component/API for repeated safe defaults, static scanners for mechanical mistakes, unit/a11y/browser tests for behavioral contracts, and CI only when confidence and cost justify a failure gate.

## Automatic actions

Agents may record observed and candidate evidence, suggest a guard, add local tests requested by the implementation task, and preserve existing waivers.

## Approval-required actions

CI failure gate activation, public component API changes, adding dependencies, broad migrations, deleting waivers, and promoting external precedent without local evidence require user approval.

## Waivers and expiry

Temporary waivers require `reason`, `owner`, and `expires`. The waiver should name the affected rule, the allowed exception, and the expected cleanup trigger.

## Retirement and migration

Retire a rule when the product direction changes, the underlying component disappears, the false-positive cost exceeds value, or a stricter local authority replaces it. Include migration notes and remove enforcement only with the same care used to add it.
