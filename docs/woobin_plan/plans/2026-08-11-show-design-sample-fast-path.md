# show-design-sample Fast Path Implementation Plan

> **For agentic workers:** Implement task-by-task in a fresh session (`/clear` first — the planning conversation is not needed and gets re-billed on every request). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `show-design-sample` produce the requested preview variants with the fewest blocking questions and model contexts, then publish them to GitHub Pages by default without using Playwright or screenshots.

**Architecture:** A deterministic skill-local scaffold owns the ignored Vite preview entry, variant switcher, build checks, local serving, and GitHub Pages deployment. The model only resolves the candidate set and writes variant components: one Sonnet 5 builder for one to three variants, or isolated parallel builders for four or more. The existing skill becomes a short routing contract; measurements, safety rationale, and rejected alternatives move to `REFERENCE.md`.

**Tech Stack:** Claude Code plugin skills, POSIX `sh`, Node.js standard library, Vite/React already installed by the target project, Git, GitHub CLI, GitHub Pages.

## Global Constraints

- Do not add package dependencies. Use the target project's local `node_modules/.bin/vite` and `@vitejs/plugin-react`; never let `npx` download a tool.
- Never modify application source under `<app-dir>/src/` while generating samples.
- Keep all generated preview files under `<app-dir>/.preview/`; exclude them locally through `git rev-parse --path-format=absolute --git-path info/exclude`, not the tracked `.gitignore`.
- Do not use Playwright, a browser, screenshots, image inspection, or a visual correction loop anywhere in this skill.
- Default delivery is the reusable `<owner>/<project>-preview` GitHub Pages repository. Use local preview only when the user explicitly requests local delivery.
- Updating an existing preview repository needs no second confirmation. Creating a new public repository or detecting possible private data must stop and request user confirmation.
- Fixtures must be synthetic. Preserve real field shapes and stress lengths, but never copy real names, employee numbers, departments, lot IDs, emails, or internal URLs.
- Preserve candidate labels and descriptions already established in the conversation; do not regenerate or reconfirm them.
- Prior candidate set plus `all`/`다`/`전부`/a matching count selects all candidates. Explicit labels select exactly those labels. A bare subset count must ask once which labels to use.
- No prior candidate set falls back to one variant for singular wording and three for plural/comparison wording.
- Use one Sonnet 5 builder for `N <= 3`. Use one concise exploration brief plus per-variant parallel builders only for `N >= 4` or an explicit parallel request.
- Keep `home/HARNESS-LOG.md` unchanged during implementation; it is historical evidence. Add a new entry only after a real post-release measurement exists.
- Bump `woobin-harness/.claude-plugin/plugin.json` from `1.5.0` to `1.6.0` because this adds executable skill infrastructure and changes runtime behavior.
- All shell scripts must run under POSIX `sh` with `set -eu`; do not use Bash arrays, `[[ ... ]]`, or process substitution.

## File Map and Ownership
- `templates/{index.html,main.tsx,vite.preview.config.ts,fixtures.ts}` owns stable preview infrastructure.
- `scripts/{init-preview.sh,build-preview.sh,verify-dist.mjs,serve-preview.sh,deploy-preview.sh}` owns deterministic execution and delivery.
- `tests/*.sh` owns persistent POSIX regression coverage.
- `SKILL.md` owns runtime routing; `REFERENCE.md` owns measurements, safety rationale, and rejected alternatives.
- `sdd-orchestrator-edit-guard.sh`, `workflow-spec.md`, and `plugin.json` own synchronized harness guidance and release version.

## Dependency Graph
`Task 1 -> Task 2 -> Task 3 -> Task 4`
The tasks are intentionally serial: Task 2 consumes the preview directory contract from Task 1; Task 3 references the exact script interfaces from Tasks 1–2; Task 4 synchronizes and validates the final policy.
---

### Task 1: Deterministic Preview Scaffold

**Files:**
- Create: `woobin-harness/skills/show-design-sample/templates/index.html`
- Create: `woobin-harness/skills/show-design-sample/templates/main.tsx`
- Create: `woobin-harness/skills/show-design-sample/templates/vite.preview.config.ts`
- Create: `woobin-harness/skills/show-design-sample/templates/fixtures.ts`
- Create: `woobin-harness/skills/show-design-sample/scripts/init-preview.sh`
- Create: `woobin-harness/skills/show-design-sample/tests/init-preview.sh`
**Interfaces:**
- Consumes: repository root as argument 1; optional app directory as argument 2.
- Produces: `<app-dir>/.preview/`, an `APP_DIR=<absolute-path>` stdout line, and exit code `2` with `APP_DIR_REQUIRED` when detection is ambiguous.

- [ ] **Step 1: Write the failing initialization regression test**
Create a temporary Git repository with `frontend/package.json`, fake executable `frontend/node_modules/.bin/vite`, and an empty `frontend/src/`. Run the not-yet-created initializer and assert:

```sh
#!/bin/sh
set -eu

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/show-design-init.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM
git -C "$ROOT" init -q
mkdir -p "$ROOT/frontend/node_modules/.bin" "$ROOT/frontend/node_modules/@vitejs/plugin-react" "$ROOT/frontend/src"
printf '%s\n' '{"devDependencies":{"vite":"7.3.2","@vitejs/plugin-react":"5.2.0"}}' > "$ROOT/frontend/package.json"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$ROOT/frontend/node_modules/.bin/vite"
chmod +x "$ROOT/frontend/node_modules/.bin/vite"
printf '%s\n' '{"name":"@vitejs/plugin-react"}' > "$ROOT/frontend/node_modules/@vitejs/plugin-react/package.json"
printf '%s\n' 'node_modules/' >> "$(git -C "$ROOT" rev-parse --git-path info/exclude)"
git -C "$ROOT" add frontend/package.json
git -C "$ROOT" -c user.name=test -c user.email=test@example.com commit -qm baseline

SCRIPT=$(git rev-parse --show-toplevel)/woobin-harness/skills/show-design-sample/scripts/init-preview.sh
output=$($SCRIPT "$ROOT")
printf '%s\n' "$output" | grep -F "APP_DIR=$ROOT/frontend"
test -f "$ROOT/frontend/.preview/index.html"
test -f "$ROOT/frontend/.preview/main.tsx"
test -f "$ROOT/frontend/.preview/vite.preview.config.ts"
test -f "$ROOT/frontend/.preview/fixtures.ts"
git -C "$ROOT" check-ignore -q frontend/.preview/index.html
test -z "$(git -C "$ROOT" status --short)"

$SCRIPT "$ROOT" >/dev/null
test "$(grep -Fc '/frontend/.preview/' "$(git -C "$ROOT" rev-parse --path-format=absolute --git-path info/exclude)")" -eq 1
echo ALL-OK
```

- [ ] **Step 2: Run the test and verify the missing-script failure**
Run: `sh woobin-harness/skills/show-design-sample/tests/init-preview.sh`
Expected: non-zero exit because `scripts/init-preview.sh` does not exist.

- [ ] **Step 3: Add stable preview templates**
Use a fixed HTML entry and a switcher that discovers `variants/*.tsx`, sorts labels, selects `?variant=<label>` case-insensitively, and falls back to the first variant. The stable entry must not be edited by a builder.

```tsx
import React, { type ComponentType } from 'react'
import { createRoot } from 'react-dom/client'

const modules = import.meta.glob<{ default: ComponentType }>('./variants/*.tsx', { eager: true })
const variants = Object.entries(modules)
  .map(([path, module]) => ({ label: path.split('/').pop()!.replace(/\.tsx$/, ''), Component: module.default }))
  .sort((left, right) => left.label.localeCompare(right.label))

const requested = new URLSearchParams(location.search).get('variant')?.toLowerCase()
const selected = variants.find(({ label }) => label.toLowerCase() === requested) ?? variants[0]

if (!selected) throw new Error('No preview variants found in .preview/variants')

function Preview() {
  return <>
    <nav aria-label="Design variants">
      {variants.map(({ label }) => <a key={label} href={`?variant=${encodeURIComponent(label)}`}>{label}</a>)}
    </nav>
    <selected.Component />
  </>
}

createRoot(document.getElementById('root')!).render(<Preview />)
```

Use a config located inside `.preview/` so every generated file is locally excluded. It must resolve packages from the parent frontend project, use relative asset URLs for any Pages repository path, and emit only to `.preview/.dist/`:

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath, URL } from 'node:url'

const previewRoot = fileURLToPath(new URL('.', import.meta.url))

export default defineConfig({
  root: previewRoot,
  base: './',
  plugins: [react()],
  resolve: { alias: { '@': fileURLToPath(new URL('../src', import.meta.url)) } },
  build: {
    outDir: fileURLToPath(new URL('./.dist', import.meta.url)),
    emptyOutDir: true,
  },
})
```

`fixtures.ts` must expose synthetic helpers such as `syntheticText(length)` and `syntheticId(length)` using repeated non-sensitive characters. It must contain no project-specific example values.

- [ ] **Step 4: Implement idempotent app detection and local exclusion**
`init-preview.sh` must prefer `frontend/package.json`, then root `package.json`, then exactly one Vite-bearing `package.json` within depth three. Validate that the chosen directory is inside the repository and contains executable local Vite plus `@vitejs/plugin-react`. If zero or multiple candidates remain, print `APP_DIR_REQUIRED` and exit `2`.

Resolve the template directory relative to the script:

```sh
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEMPLATE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../templates" && pwd -P)
```

Copy `index.html`, `main.tsx`, and `vite.preview.config.ts` on every initialization so infrastructure upgrades propagate. Create `fixtures.ts` only when absent so a builder's synthetic fixture shape survives re-runs. Register `/<relative-app-dir>/.preview/` once in the absolute Git exclude path.

- [ ] **Step 5: Run the initialization regression test**
Run: `sh woobin-harness/skills/show-design-sample/tests/init-preview.sh`
Expected: `ALL-OK`.

- [ ] **Step 6: Commit Task 1**
```bash
git add woobin-harness/skills/show-design-sample/templates \
        woobin-harness/skills/show-design-sample/scripts/init-preview.sh \
        woobin-harness/skills/show-design-sample/tests/init-preview.sh
git commit -m "Make preview setup deterministic and local-only

Constraint: Generated preview infrastructure must not alter tracked application files
Confidence: high
Scope-risk: narrow
Tested: POSIX initialization and idempotency regression"
```

---

### Task 2: Browser-Free Build and Delivery Scripts

**Files:**
- Create: `woobin-harness/skills/show-design-sample/scripts/verify-dist.mjs`
- Create: `woobin-harness/skills/show-design-sample/scripts/build-preview.sh`
- Create: `woobin-harness/skills/show-design-sample/scripts/serve-preview.sh`
- Create: `woobin-harness/skills/show-design-sample/scripts/deploy-preview.sh`
- Create: `woobin-harness/skills/show-design-sample/tests/build-preview.sh`
- Create: `woobin-harness/skills/show-design-sample/tests/deploy-preview.sh`
**Interfaces:**
- Consumes: absolute or repository-relative app directory produced by Task 1.
- Produces: `.preview/.dist/`, a local URL only on explicit invocation, or a Pages URL plus an exact `preview-version.txt` marker.

- [ ] **Step 1: Write failing build-script tests with a fake local Vite binary**
The fake Vite executable must create `.preview/.dist/index.html` and `.preview/.dist/assets/app.js`. Assert that a valid build passes, a missing referenced asset fails, and the script never invokes `npx` or network installation.

```sh
PATH="$ROOT/no-npx-bin:$PATH" "$BUILD" "$ROOT/frontend"
test -f "$ROOT/frontend/.preview/.dist/index.html"
rm "$ROOT/frontend/.preview/.dist/assets/app.js"
if node "$VERIFY" "$ROOT/frontend/.preview/.dist"; then
  echo "expected missing asset failure" >&2
  exit 1
fi
```

- [ ] **Step 2: Implement static distribution verification**
`verify-dist.mjs` must use only `node:fs`, `node:path`, and `node:url`. Read `index.html`, extract local `src` and `href` references, ignore `http:`, `https:`, `data:`, and fragments, strip query/hash suffixes, and assert every remaining path exists under the distribution root. Also require at least one `.js` asset.

```js
const refs = [...html.matchAll(/(?:src|href)=["']([^"']+)["']/g)].map((match) => match[1])
const localRefs = refs.filter((ref) => !/^(?:https?:|data:|#)/.test(ref))
for (const ref of localRefs) {
  const clean = ref.split(/[?#]/, 1)[0].replace(/^\.\//, '').replace(/^\//, '')
  if (!existsSync(resolve(dist, clean))) failures.push(clean)
}
```

Print only `DIST_OK files=<count>` on success or one missing path per line on failure.

- [ ] **Step 3: Implement the pinned build and explicit local serve paths**
`build-preview.sh <app-dir>` must run:

```sh
VITE="$APP_DIR/node_modules/.bin/vite"
test -x "$VITE" || { echo "LOCAL_VITE_REQUIRED" >&2; exit 2; }
cd "$APP_DIR"
"$VITE" build --config .preview/vite.preview.config.ts
node "$SCRIPT_DIR/verify-dist.mjs" "$APP_DIR/.preview/.dist"
```

`serve-preview.sh <app-dir>` must call the build script, then execute the same local Vite binary with `preview --config .preview/vite.preview.config.ts --host 127.0.0.1`. This script is never the default route.

- [ ] **Step 4: Write failing deploy-script tests using a local bare Git remote and fake curl**
Test these cases independently:

- Existing deploy clone is reused rather than cloned again.
- Dotfiles other than `.git` are replaced, not leaked from the prior deployment.
- A changed build creates and pushes a new marker.
- An unchanged build exits successfully without an empty commit.
- A missing target repository exits `3` with `NEW_PUBLIC_REPO_REQUIRED=<owner/repo>` unless `--create-public` is present.
- Polling succeeds only when the returned marker equals the new marker, not merely when `index.html` returns HTTP 200.

Inject `GH_BIN`, `CURL_BIN`, and `PREVIEW_URL` environment variables in the test so no real network or GitHub state is touched.

- [ ] **Step 5: Implement safe reusable Pages deployment**
Use this command contract:

```text
deploy-preview.sh [--create-public] <app-dir> [owner/repo]
```

If the target is omitted, derive the source `owner/project` with `gh repo view --json nameWithOwner --jq .nameWithOwner`, then select `owner/project-preview`. If the preview repository does not exist and `--create-public` was not passed, exit `3` before any external mutation. With the flag, create it as public and enable Pages from `main:/` only when the Pages API reports it absent.

Validate that the deploy directory is exactly `<app-dir>/.preview/.deploy` before cleaning it. Reuse an existing clone with `fetch` plus a hard reset confined to that ignored deploy cache. Synchronize the built output including dotfiles while excluding `.git`, add `.nojekyll`, and write a marker derived from the built `index.html` hash plus the current epoch:

```sh
HASH=$(shasum "$DIST/index.html" | awk '{print $1}')
MARKER="${HASH}-$(date +%s)"
printf '%s\n' "$MARKER" > "$DEPLOY/preview-version.txt"
```

After push, poll `<pages-url>/preview-version.txt?marker=<marker>` with a bounded 120-second loop and succeed only on exact content equality. Output only `PREVIEW_URL=<url>` and `PREVIEW_VERSION=<marker>`.

- [ ] **Step 6: Run browser-free script tests**
Run:

```bash
sh woobin-harness/skills/show-design-sample/tests/build-preview.sh
sh woobin-harness/skills/show-design-sample/tests/deploy-preview.sh
```
Expected: both print `ALL-OK`; `rg -n 'playwright|screenshot' woobin-harness/skills/show-design-sample/scripts woobin-harness/skills/show-design-sample/templates` returns no matches.

- [ ] **Step 7: Commit Task 2**
```bash
git add woobin-harness/skills/show-design-sample/scripts \
        woobin-harness/skills/show-design-sample/tests
git commit -m "Make preview delivery reproducible without browser context

Constraint: GitHub Pages remains the default delivery path
Rejected: Playwright smoke test | the accepted workflow removes browser execution entirely
Confidence: high
Scope-risk: moderate
Tested: Local fake-Vite build and isolated Git deployment regressions"
```

---

### Task 3: Rewrite the Skill Around Candidate Sets and the One-Builder Fast Path

**Files:**
- Modify: `woobin-harness/skills/show-design-sample/SKILL.md`
- Create: `woobin-harness/skills/show-design-sample/REFERENCE.md`
- Create: `woobin-harness/skills/show-design-sample/tests/skill-contract.sh`
**Interfaces:**
- Consumes: script paths and output contracts from Tasks 1–2 plus the latest candidate set in conversation context.
- Produces: a selected label set, one or more builder assignments, and either a Pages URL or explicitly requested local URL.

- [ ] **Step 1: Write the failing skill-contract test**
Assert the rewritten skill contains the accepted routing rules and no stale mandatory browser or per-variant-agent language:

```sh
#!/bin/sh
set -eu
S=woobin-harness/skills/show-design-sample/SKILL.md
R=woobin-harness/skills/show-design-sample/REFERENCE.md
fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }
chk "candidate set first" "grep -q '후보 집합' '$S'"
chk "all candidates mapping" "grep -q '다.*전부' '$S'"
chk "ambiguous subset asks once" "grep -q '부분 집합.*한 번' '$S'"
chk "one builder fast path" "grep -q 'N <= 3.*에이전트 1개' '$S'"
chk "parallel threshold" "grep -q 'N >= 4' '$S'"
chk "pages default" "grep -q 'GitHub Pages.*기본' '$S'"
chk "local explicit only" "grep -q '로컬.*명시' '$S'"
chk "no browser contract" "grep -q 'Playwright.*사용하지 않는다' '$S'"
chk "local exclude" "grep -q 'info/exclude' '$S'"
chk "reference split" "test -f '$R' && grep -q '^## 기각한 대안' '$R'"
bytes=$(wc -c < "$S" | tr -d ' ')
chk "runtime body compact" "test '$bytes' -le 6500"
test "$fail" -eq 0
echo ALL-OK
```

- [ ] **Step 2: Run the contract test and verify failure against v1.5.0**
Run: `sh woobin-harness/skills/show-design-sample/tests/skill-contract.sh`
Expected: failures for candidate-set routing, one-builder threshold, scripts, and compact body.

- [ ] **Step 3: Replace count-first questioning with candidate-set resolution**
Put this decision table in `SKILL.md`:

| Conversation state | User wording | Result |
|---|---|---|
| Latest candidates `{A,B,C}` | `3개 다`, `다`, `전부` | Build `A+B+C` immediately |
| Latest candidates `{A,B,C}` | `A와 C` | Build `A+C` immediately |
| Latest candidates `{A,B,C}` | bare `2개` | Ask once: `A+B`, `A+C`, or `B+C`; recommend the most structurally contrasting pair |
| Latest candidates `{A,B,C}` | bare `4개` | Ask for the added fourth direction |
| No candidate set | singular sample wording | Build one inferred candidate |
| No candidate set | plural/comparison wording | Build three structurally distinct candidates |

The latest assistant-authored candidate labels and descriptions are authoritative input. Do not propose them again. A high-confidence mapping is announced non-blockingly and execution continues. Only an unresolved subset or missing extra direction blocks.

- [ ] **Step 4: Encode the adaptive builder topology**
For `N <= 3`, initialize the preview and spawn one Sonnet 5 general-purpose builder. Its prompt contains the exact selected labels/descriptions, the app directory, and these constraints:

- Inspect the target component and design-token sources once.
- Import the project's actual global style and font entrypoints from the variant modules; do not copy their contents.
- Write only `.preview/variants/<label>.tsx` and synthetic `.preview/fixtures.ts`.
- Do not modify `.preview/main.tsx`, Vite infrastructure, or `src/`.
- Do not invoke Playwright, browser tools, screenshot tools, or image generation.
- Return paths plus one line per variant; never return diffs.

For `N >= 4` or explicit parallel execution, use one concise read-only exploration pass to create a maximum-20-line brief, persist it to `.preview/BRIEF.md`, then spawn one Sonnet builder per label with distinct filenames. This is the only branch that uses per-variant agents.

- [ ] **Step 5: Replace generated infrastructure and inline deployment commands with script calls**
The runtime sequence must be exactly:

1. Resolve candidate labels.
2. Run `scripts/init-preview.sh` and ask only on `APP_DIR_REQUIRED`.
3. Run the selected builder topology.
4. Run `scripts/build-preview.sh`.
5. Confirm fixtures are synthetic and print the distribution file list.
6. Default: run `scripts/deploy-preview.sh`; on exit `3`, ask before re-running with `--create-public`.
7. Explicit local request only: run `scripts/serve-preview.sh` instead.
8. Return variant URLs and one-line tradeoffs; state that application source was not changed.

Remove the project-to-preview-repository table, inline clone/copy commands, hard-coded A/B/C paths, mandatory pre-build confirmation, and the unmeasured hard `$3/25 requests/30 minutes` stop. Replace the latter with a measurement section in `REFERENCE.md` that records the target but does not claim it has been achieved.

- [ ] **Step 6: Move evidence and rejected alternatives to `REFERENCE.md`**
Preserve the existing measurements and explain these accepted/rejected decisions:

- Rejected per-variant screenshots and Playwright: Sonnet 5 is adequate for error-free mock generation; browser/image context conflicts with the speed/cost goal.
- Rejected pure main-loop implementation: historical cache-read amplification remains valid.
- Rejected one agent per variant for `N <= 3`: without image loops, duplicated exploration and integration are unnecessary; the repository has no comparative timing yet, so remeasure.
- Rejected tracked `.gitignore`: `.git/info/exclude` provides the same local ignore behavior without a repository diff.
- Rejected asking before every scaffold or candidate count: deterministic setup and existing conversation labels resolve the common path.
- Rejected local-first delivery: the user explicitly selected GitHub Pages as the default.
- Preserve the official Vite Pages `base` reference and the Sonnet 5/WebDev benchmark links gathered during design.

- [ ] **Step 7: Run the skill-contract test and plugin validation**
Run:

```bash
sh woobin-harness/skills/show-design-sample/tests/skill-contract.sh
claude plugin validate ./woobin-harness
```
Expected: `ALL-OK` and plugin validation success.

- [ ] **Step 8: Commit Task 3**
```bash
git add woobin-harness/skills/show-design-sample
git commit -m "Route design samples through the cheapest complete path

Constraint: Existing conversation candidates are authoritative
Rejected: Mandatory count confirmation | blocks the common all-candidates request
Rejected: Local-first delivery | GitHub Pages is the selected default
Confidence: medium
Scope-risk: moderate
Tested: Skill contract and Claude plugin validation"
```

---

### Task 4: Synchronize Harness Guidance, Version, and End-to-End Gates

**Files:**
- Modify: `woobin-harness/hooks/sdd-orchestrator-edit-guard.sh:145-146`
- Modify: `docs/workflow-spec.md:83`
- Modify: `woobin-harness/.claude-plugin/plugin.json:4`
- Create: `woobin-harness/skills/show-design-sample/tests/all.sh`
**Interfaces:**
- Consumes: final policy and executable contracts from Tasks 1–3.
- Produces: installable plugin `1.6.0` with synchronized operator guidance and one regression entry point.

- [ ] **Step 1: Add the aggregate failing gate**
```sh
#!/bin/sh
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
sh "$DIR/init-preview.sh"
sh "$DIR/build-preview.sh"
sh "$DIR/deploy-preview.sh"
sh "$DIR/skill-contract.sh"
echo ALL-OK
```

Before running the aggregate gate, append these exact version/guidance assertions to `skill-contract.sh`, then expect them to fail until Steps 2–3 are complete:

```sh
chk "adaptive hook guidance" "grep -q 'N<=3.*빌더 1개' woobin-harness/hooks/sdd-orchestrator-edit-guard.sh"
chk "workflow route synchronized" "grep -q '브라우저 없이.*N<=3' docs/workflow-spec.md"
chk "plugin version" "grep -q '\"version\": \"1.6.0\"' woobin-harness/.claude-plugin/plugin.json"
```

- [ ] **Step 2: Update the bulk-edit guard without duplicating the full skill**
Replace the stale unconditional “one agent per variant” instruction with:

```text
- 디자인 시안 제작 → show-design-sample 규정대로 메인 루프는 편집하지 않습니다.
  N<=3은 Sonnet 빌더 1개, N>=4 또는 명시적 병렬 요청은 시안별 빌더를 사용합니다.
```

Keep the hook a routing reminder. Candidate selection, Pages behavior, and script details remain owned exclusively by `SKILL.md`.

- [ ] **Step 3: Synchronize the workflow route and plugin version**
Update `docs/workflow-spec.md:83` so the UI/design branch describes the adaptive builder topology and browser-free sample delivery in one line. Do not duplicate the decision table. Set `plugin.json` version to `1.6.0`; skill, agent, and hook counts remain unchanged, so marketplace and README counts do not change.

- [ ] **Step 4: Run all repository gates**
Run:

```bash
sh woobin-harness/skills/show-design-sample/tests/all.sh
sh scripts/check-harness-docs.sh
claude plugin validate ./woobin-harness
DRY_RUN=1 ./bootstrap.sh
git diff --check
```
Expected: all script suites print `ALL-OK`; doc synchronization exits zero and may show the expected `workflow.html`/historical-log judgment warnings; plugin validation passes; bootstrap dry-run succeeds; `git diff --check` is silent.

- [ ] **Step 5: Perform one controlled real-project acceptance run**
After installing plugin `1.6.0` and restarting Claude Code, use a non-sensitive Vite/React project with an existing reusable preview repository. In one conversation, first define A=simple, B=complex, C=hybrid, then request `3개 다 샘플로 만들어서 gh page로 보여줘`.

Record these facts without changing `home/HARNESS-LOG.md` yet:

- Candidate resolution selects A+B+C without a question.
- Exactly one Sonnet 5 builder is spawned.
- No Playwright, browser, screenshot, or image tool is called.
- Application `src/` and tracked `.gitignore` remain unchanged.
- The exact new `preview-version.txt` marker becomes reachable.
- Main-loop request count, builder cost, total cost, and wall-clock time.

Repeat only after at least three comparable real runs. Then use their median to decide whether `$3`, 25 requests, and 30 minutes are defensible release limits; until then, document them as unverified targets in `REFERENCE.md`.

- [ ] **Step 6: Commit Task 4 using the Lore protocol**
```bash
git add woobin-harness/hooks/sdd-orchestrator-edit-guard.sh \
        docs/workflow-spec.md \
        woobin-harness/.claude-plugin/plugin.json \
        woobin-harness/skills/show-design-sample/tests/all.sh
git commit -m "Keep preview orchestration cheap as variant count changes

The harness now routes small candidate sets through one disposable builder and reserves parallel builders for larger sets, while deterministic scripts own setup and delivery.

Constraint: GitHub Pages remains the default delivery surface
Rejected: Per-variant builders for every request | browser capture was removed, so duplicate contexts no longer buy isolation
Confidence: medium
Scope-risk: moderate
Directive: Do not restore browser verification without a measured failure rate that exceeds the build-only path
Tested: Skill regressions, doc sync, plugin validation, bootstrap dry-run
Not-tested: Three-run production cost median"
```

## Rejected Alternatives Carried Forward from the Grill

| Alternative | Reason rejected |
|---|---|
| Ask before creating `.preview/` | Deterministic local-only setup is reversible and changes no tracked files; waiting adds latency without changing the result. |
| Add `.preview/` to tracked `.gitignore` | It creates a project diff for a local disposable artifact; `.git/info/exclude` has the intended scope. |
| Playwright or screenshot verification | The accepted quality bar is an error-free mock page, and Sonnet 5 plus build/static checks is sufficient for the first sample. |
| One agent per variant for all counts | Image-context isolation was its main justification; that loop is gone. Small sets share exploration more cheaply in one builder. |
| Always use one builder | Four or more variants can benefit from explicit parallelism despite the token premium. |
| Always default to one or three solely from grammar | Existing A/B/C decisions in the conversation are better evidence than singular/plural wording. |
| Guess a subset when the user says only `2개` | Different label pairs produce different work; one targeted combination question is load-bearing. |
| Local preview by default | The user explicitly chose GitHub Pages as the standard delivery surface. |
| Keep the hard `$3/25 requests/30 minutes` claim | The rewritten pipeline has not yet been measured; builders alone previously cost `$3.09`. |
| Store project preview repositories in the skill | Deriving `<owner>/<project>-preview` removes a growing table and per-project skill edits. |
