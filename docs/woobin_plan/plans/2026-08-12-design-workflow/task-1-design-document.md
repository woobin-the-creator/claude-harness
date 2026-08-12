# Task 1: Optional Structured DESIGN.md Contract and Validator

**Files:**
- Create: `woobin-harness/skills/design-workflow/templates/DESIGN.md`
- Create: `woobin-harness/skills/design-workflow/references/design-document.md`
- Create: `woobin-harness/skills/design-workflow/scripts/design-document-schema.mjs`
- Create: `woobin-harness/skills/design-workflow/scripts/validate-design-md.mjs`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/design-absent/.gitkeep`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/design-unmanaged/DESIGN.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/design-valid-minimal/DESIGN.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/design-valid-full/DESIGN.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/design-invalid-json/DESIGN.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/design-invalid-schema/DESIGN.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/design-invalid-external-adopted/DESIGN.md`
- Create: `woobin-harness/skills/design-workflow/tests/fixtures/design-invalid-enforcement/DESIGN.md`
- Create: `woobin-harness/skills/design-workflow/tests/validate-design-md.sh`

**Interfaces:**
- Consumes: an optional repository root or `DESIGN.md` path.
- Produces: `validateDesignData(data) -> Array<{ code: string, path: string, message: string }>`; the CLI performs repository-path checks and outputs the stable messages defined in `00-overview.md`.
- Later tasks consume: exact lifecycle enums, marker strings, template sections, CLI name, and optional-file semantics.

- [ ] **Step 1: Write the positive and optional-state fixtures**

Create `design-unmanaged/DESIGN.md` without the managed frontmatter:

```markdown
# Existing project design notes

This file predates design-workflow and must not be overwritten or rejected.
```

Create `design-valid-minimal/DESIGN.md`:

````markdown
---
design_workflow:
  enabled: true
  schema_version: 1
---

# Product direction

No durable direction has been adopted yet.

<!-- design-workflow:data:start -->
```json
{
  "schemaVersion": 1,
  "project": { "state": "established", "directionStatus": "unset" },
  "authorities": [],
  "decisions": []
}
```
<!-- design-workflow:data:end -->
````

Create `design-valid-full/DESIGN.md` with one authority and two decisions. Make the component path real inside the fixture:

```json
{
  "schemaVersion": 1,
  "project": { "state": "established", "directionStatus": "adopted" },
  "authorities": [
    { "kind": "components", "path": "src/components" }
  ],
  "decisions": [
    {
      "id": "table-cell-wrapping",
      "status": "component-enforced",
      "source": {
        "type": "local-incident",
        "references": ["evidence/table-density.md"]
      },
      "rule": "Table cells use one line unless an explicit multiline variant is selected.",
      "localEvidence": ["evidence/table-density.md"],
      "enforcement": [
        { "type": "component", "path": "src/components/TableCell.tsx" }
      ],
      "waivers": []
    },
    {
      "id": "measured-overflow",
      "status": "candidate",
      "source": {
        "type": "external-precedent",
        "references": ["carbon-design-system/ibm-products@eeff1e98"]
      },
      "rule": "Visible items are selected from measured widths rather than a fixed count.",
      "localEvidence": [],
      "enforcement": [],
      "waivers": []
    }
  ]
}
```

Create `src/components/TableCell.tsx` and `evidence/table-density.md` as empty fixture files. The managed Markdown must use the exact frontmatter and marker shape from the minimal fixture.

- [ ] **Step 2: Write negative fixtures for the three load-bearing invariants**

`design-invalid-json/DESIGN.md` must contain `{ invalid json }` inside otherwise valid markers.

`design-invalid-schema/DESIGN.md` must use `enabled: true`, `schema_version: 2`, and JSON `"schemaVersion": 2`. It is managed-but-unsupported and must not fall through to `DESIGN_UNMANAGED`.

`design-invalid-external-adopted/DESIGN.md` must contain:

```json
{
  "schemaVersion": 1,
  "project": { "state": "established", "directionStatus": "adopted" },
  "authorities": [],
  "decisions": [
    {
      "id": "external-without-local-proof",
      "status": "adopted",
      "source": { "type": "external-precedent", "references": ["vendor/repo@abc123"] },
      "rule": "Adopt the vendor behavior.",
      "localEvidence": [],
      "enforcement": [],
      "waivers": []
    }
  ]
}
```

`design-invalid-enforcement/DESIGN.md` must declare `status: "component-enforced"` with `enforcement: []`.

- [ ] **Step 3: Write the failing CLI regression test**

Create `tests/validate-design-md.sh`:

```sh
#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd -P)
SKILL="$ROOT/woobin-harness/skills/design-workflow"
CLI="$SKILL/scripts/validate-design-md.mjs"
FIXTURES="$SKILL/tests/fixtures"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/design-workflow-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

output=$(node "$CLI" "$FIXTURES/design-absent")
printf '%s\n' "$output" | grep -F 'DESIGN_ABSENT path='

output=$(node "$CLI" "$FIXTURES/design-unmanaged")
printf '%s\n' "$output" | grep -F 'DESIGN_UNMANAGED path='

output=$(node "$CLI" "$FIXTURES/design-valid-minimal")
test "$output" = 'DESIGN_OK schema=1 decisions=0'

cp -R "$FIXTURES/design-valid-full/." "$TMP_ROOT/"
output=$(node "$CLI" "$TMP_ROOT/DESIGN.md")
test "$output" = 'DESIGN_OK schema=1 decisions=2'

if node "$CLI" "$FIXTURES/design-invalid-json" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
  echo 'invalid JSON unexpectedly passed' >&2
  exit 1
fi
grep -F 'DESIGN_E_JSON' "$TMP_ROOT/err"

if node "$CLI" "$FIXTURES/design-invalid-schema" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
  echo 'unsupported managed schema unexpectedly passed' >&2
  exit 1
fi
grep -F 'DESIGN_E_FRONTMATTER_SCHEMA' "$TMP_ROOT/err"

if node "$CLI" "$FIXTURES/design-invalid-external-adopted" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
  echo 'unverified external adoption unexpectedly passed' >&2
  exit 1
fi
grep -F 'DESIGN_E_EXTERNAL_NEEDS_LOCAL_EVIDENCE' "$TMP_ROOT/err"

if node "$CLI" "$FIXTURES/design-invalid-enforcement" >"$TMP_ROOT/out" 2>"$TMP_ROOT/err"; then
  echo 'missing enforcement unexpectedly passed' >&2
  exit 1
fi
grep -F 'DESIGN_E_ENFORCEMENT_REQUIRED' "$TMP_ROOT/err"

echo ALL-OK
```

- [ ] **Step 4: Run the test and verify the missing-validator failure**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/validate-design-md.sh
```

Expected: non-zero exit because `validate-design-md.mjs` does not exist.

- [ ] **Step 5: Implement the pure schema module**

Create `scripts/design-document-schema.mjs` with these exports and no filesystem access:

```js
export const SCHEMA_VERSION = 1
export const PROJECT_STATES = new Set(['greenfield', 'established', 'mixed', 'legacy'])
export const DIRECTION_STATUSES = new Set(['unset', 'candidate', 'adopted'])
export const DECISION_STATUSES = new Set([
  'observed',
  'candidate',
  'adopted',
  'component-enforced',
  'ci-enforced',
  'retired',
])
export const SOURCE_TYPES = new Set([
  'user-decision',
  'local-code',
  'local-incident',
  'external-precedent',
])
export const ENFORCEMENT_TYPES = new Set([
  'component', 'static', 'unit', 'a11y', 'browser', 'ci',
])

const ADOPTED_STATUSES = new Set(['adopted', 'component-enforced', 'ci-enforced'])
const KEBAB_CASE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/

export function validateDesignData(data) {
  const errors = []
  const add = (code, path, message) => errors.push({ code, path, message })

  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    add('DESIGN_E_ROOT', '/', 'data must be an object')
    return errors
  }
  if (data.schemaVersion !== SCHEMA_VERSION) {
    add('DESIGN_E_SCHEMA', '/schemaVersion', `expected ${SCHEMA_VERSION}`)
  }
  if (!PROJECT_STATES.has(data.project?.state)) {
    add('DESIGN_E_PROJECT_STATE', '/project/state', 'unknown project state')
  }
  if (!DIRECTION_STATUSES.has(data.project?.directionStatus)) {
    add('DESIGN_E_DIRECTION_STATUS', '/project/directionStatus', 'unknown direction status')
  }
  if (!Array.isArray(data.authorities)) {
    add('DESIGN_E_AUTHORITIES', '/authorities', 'authorities must be an array')
  }
  if (!Array.isArray(data.decisions)) {
    add('DESIGN_E_DECISIONS', '/decisions', 'decisions must be an array')
    return errors
  }

  const seen = new Set()
  data.decisions.forEach((decision, index) => {
    const base = `/decisions/${index}`
    if (!KEBAB_CASE.test(decision?.id ?? '')) {
      add('DESIGN_E_ID', `${base}/id`, 'id must be unique kebab-case')
    } else if (seen.has(decision.id)) {
      add('DESIGN_E_ID_DUPLICATE', `${base}/id`, 'duplicate decision id')
    } else {
      seen.add(decision.id)
    }
    if (!DECISION_STATUSES.has(decision?.status)) {
      add('DESIGN_E_STATUS', `${base}/status`, 'unknown decision status')
    }
    if (!SOURCE_TYPES.has(decision?.source?.type)) {
      add('DESIGN_E_SOURCE', `${base}/source/type`, 'unknown source type')
    }
    if (typeof decision?.rule !== 'string' || decision.rule.trim() === '') {
      add('DESIGN_E_RULE', `${base}/rule`, 'rule must be a non-empty string')
    }
    const refs = decision?.source?.references
    const evidence = decision?.localEvidence
    const enforcement = decision?.enforcement
    const waivers = decision?.waivers
    if (!Array.isArray(refs)) add('DESIGN_E_REFERENCES', `${base}/source/references`, 'references must be an array')
    if (!Array.isArray(evidence)) add('DESIGN_E_LOCAL_EVIDENCE', `${base}/localEvidence`, 'localEvidence must be an array')
    if (!Array.isArray(enforcement)) add('DESIGN_E_ENFORCEMENT', `${base}/enforcement`, 'enforcement must be an array')
    if (!Array.isArray(waivers)) add('DESIGN_E_WAIVERS', `${base}/waivers`, 'waivers must be an array')

    if (decision?.source?.type === 'local-incident' && (!refs?.length || !evidence?.length)) {
      add('DESIGN_E_INCIDENT_EVIDENCE', base, 'local incidents require source references and local evidence')
    }
    if (decision?.source?.type === 'external-precedent' && ADOPTED_STATUSES.has(decision?.status) && !evidence?.length) {
      add('DESIGN_E_EXTERNAL_NEEDS_LOCAL_EVIDENCE', `${base}/localEvidence`, 'adopted external precedents require local evidence')
    }
    if ((decision?.status === 'component-enforced' || decision?.status === 'ci-enforced') && !enforcement?.length) {
      add('DESIGN_E_ENFORCEMENT_REQUIRED', `${base}/enforcement`, 'enforced status requires an enforcement record')
    }
    enforcement?.forEach((item, itemIndex) => {
      if (!ENFORCEMENT_TYPES.has(item?.type) || typeof item?.path !== 'string' || item.path === '') {
        add('DESIGN_E_ENFORCEMENT_ITEM', `${base}/enforcement/${itemIndex}`, 'enforcement requires a known type and path')
      }
    })
    waivers?.forEach((item, itemIndex) => {
      if (!item?.reason || !item?.owner || !ISO_DATE.test(item?.expires ?? '')) {
        add('DESIGN_E_WAIVER', `${base}/waivers/${itemIndex}`, 'waiver requires reason, owner, and YYYY-MM-DD expires')
      }
    })
  })

  return errors.sort((left, right) => `${left.path}:${left.code}`.localeCompare(`${right.path}:${right.code}`))
}
```

Also validate each authority as `{ kind: non-empty string, path: non-empty relative path }`. Reject absolute paths and any normalized path beginning with `..` for authority and enforcement records.

- [ ] **Step 6: Implement managed Markdown detection and CLI behavior**

Create `scripts/validate-design-md.mjs` using only `node:fs`, `node:path`, and the schema module. Use these exact marker constants:

```js
const START = '<!-- design-workflow:data:start -->'
const END = '<!-- design-workflow:data:end -->'
const MANAGED = /design_workflow:\s*\n(?:[ \t]+.*\n)*?[ \t]+enabled:\s*true(?:\s|$)/
const FRONTMATTER_SCHEMA = /design_workflow:\s*\n(?:[ \t]+.*\n)*?[ \t]+schema_version:\s*(\d+)(?:\s|$)/
```

Resolve a directory argument to `<dir>/DESIGN.md`; resolve a file argument as-is. If the file is absent, print `DESIGN_ABSENT`. Extract only the initial `---` frontmatter before applying `MANAGED` and `FRONTMATTER_SCHEMA`; narrative text cannot activate management. If enabled management is absent, print `DESIGN_UNMANAGED`. If enabled is true but the frontmatter schema is missing or not `1`, emit `DESIGN_E_FRONTMATTER_SCHEMA` and exit `1`. A managed file must then have exactly one START and END marker, with one fenced `json` block between them:

```js
const block = between.match(/^\s*```json\s*\n([\s\S]*?)\n```\s*$/)
```

Parse JSON, call `validateDesignData`, then verify that authority, source reference, local evidence, and enforcement paths which look like project paths exist under the repository root. Skip existence checks for external references containing `@` or `://`. Do not follow a normalized path outside the repository root.

Format diagnostics without stack traces:

```js
for (const error of errors) {
  console.error(`${error.code} path=${error.path} message=${error.message}`)
}
process.exitCode = errors.length ? 1 : 0
```

- [ ] **Step 7: Run the validator regression test**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/validate-design-md.sh
```

Expected: `ALL-OK`.

- [ ] **Step 8: Create the starter template and authoring reference**

Create `templates/DESIGN.md` using the valid-minimal managed block and these human sections:

```markdown
# Product direction
## Tone and intended feeling
## Domain vocabulary and signature
## Avoided defaults
# Foundations and authorities
## Color, typography, spacing, radius, depth, and motion
# Interaction contracts
# Decisions and evidence
# Legacy and migration
# Unverified checks
```

`references/design-document.md` must explain:

- absent and unmanaged files are valid and never overwritten;
- when to suggest creation: durable direction, project-specific override, repeated incident, accepted external precedent, or enforcement path;
- token values stay in code and `DESIGN.md` links to their authority;
- exact status/source/enforcement enums and approval boundary;
- all validator output codes implemented above;
- an external precedent stays `candidate` until `localEvidence` exists.

- [ ] **Step 9: Re-run Task 1 tests and inspect the template itself**

Run:

```bash
sh woobin-harness/skills/design-workflow/tests/validate-design-md.sh
node woobin-harness/skills/design-workflow/scripts/validate-design-md.mjs \
  woobin-harness/skills/design-workflow/templates/DESIGN.md
```

Expected:

```text
ALL-OK
DESIGN_OK schema=1 decisions=0
```

- [ ] **Step 10: Commit Task 1**

```bash
git add woobin-harness/skills/design-workflow/templates \
        woobin-harness/skills/design-workflow/references/design-document.md \
        woobin-harness/skills/design-workflow/scripts \
        woobin-harness/skills/design-workflow/tests/fixtures \
        woobin-harness/skills/design-workflow/tests/validate-design-md.sh
git commit -m "Add optional design document contract

Constraint: DESIGN.md absence and unrelated existing files must remain non-blocking
Confidence: high
Scope-risk: narrow
Tested: dependency-free validator fixtures"
```
