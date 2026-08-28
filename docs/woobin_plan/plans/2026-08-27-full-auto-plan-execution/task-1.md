### Task 1: Implementer variants + mechanical name lock

Replace the single `plan-implementer` with three definitions whose frontmatter pins both `model` and `effort`, on both hosts, and add a fixture that keeps each filename honest about the frontmatter it claims.

**Why the pinning is required:** the `Agent` tool accepts `model` but has no `effort` argument, and `woobin-harness/agents/plan-implementer.md` deliberately omits both so it inherits the mode's effort from the session relaunch. Once the planning session spawns the implementer directly, no relaunch happens and the implementer silently runs at the planning session's effort.

**Files:**
- Create: `woobin-harness/agents/plan-implementer-sonnet-xhigh.md`
- Create: `woobin-harness/agents/plan-implementer-sonnet-medium.md`
- Create: `woobin-harness/agents/plan-implementer-opus-xhigh.md`
- Delete: `woobin-harness/agents/plan-implementer.md`
- Create: `codex/agents/plan-implementer-terra-medium.toml`
- Create: `codex/agents/plan-implementer-gpt56-medium.toml`
- Create: `codex/agents/plan-implementer-gpt56-xhigh.toml`
- Delete: `codex/agents/plan-implementer.toml`
- Create: `scripts/test-agents.sh`
- Modify: `scripts/validate-codex.sh:80-88` (the `expected` dict and the `!= 4` count guard)

**Interfaces:**
- Produces: the exact agent type strings `plan-implementer-sonnet-xhigh`, `plan-implementer-sonnet-medium`, `plan-implementer-opus-xhigh` (Claude) and `plan-implementer-terra-medium`, `plan-implementer-gpt56-medium`, `plan-implementer-gpt56-xhigh` (Codex). Tasks 2, 4, 5, and 6 quote these strings verbatim.
- Produces: `./scripts/test-agents.sh`, an executable POSIX-sh fixture. Task 6 adds it to the validation lists in `CLAUDE.md` and `README.md`.
- Consumes: nothing.

**Model/effort mapping** — taken from the current mode files, not invented:

| Mode | Claude agent | model | effort | Codex agent | model | model_reasoning_effort |
|---|---|---|---|---|---|---|
| ① speed | `plan-implementer-sonnet-xhigh` | `sonnet` | `xhigh` | `plan-implementer-terra-medium` | `gpt-5.6-terra` | `medium` |
| ②b thrift | `plan-implementer-sonnet-medium` | `sonnet` | `medium` | `plan-implementer-gpt56-medium` | `gpt-5.6` | `medium` |
| ③ max quality | `plan-implementer-opus-xhigh` | `opus` | `xhigh` | `plan-implementer-gpt56-xhigh` | `gpt-5.6` | `xhigh` |

The Codex filename tokens are `terra` for `gpt-5.6-terra` and `gpt56` for `gpt-5.6`, because the real slugs contain dots. The fixture in Step 1 owns that mapping.

---

- [ ] **Step 1: Write the failing fixture**

Create `scripts/test-agents.sh` with mode `0755`:

```sh
#!/bin/sh
# 에이전트 정의 fixture — 파일명이 주장하는 model·effort 가 frontmatter 와 같은지 기계가 센다.
#
# 왜: 규율 6("이름이 아니라 출처로 판정한다"). `plan-implementer-sonnet-medium` 이라는 이름은
# frontmatter 에 사는 사실을 한 번 더 주장하는 형태다. 누가 frontmatter 만 고치면 이름이 조용히
# 거짓말을 하고, 그 결과는 "모드에 없는 조합으로 구현이 돌았다"인데 증상이 없다.
# 이 fixture 가 이름을 두 번째 소유자에서 파생값으로 바꾼다.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)

fail() { printf '✗ %s\n' "$*" >&2; exit 1; }
pass() { printf '✓ %s\n' "$*"; }

python3 - "$ROOT" <<'PY'
import pathlib
import re
import sys

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

root = pathlib.Path(sys.argv[1])

# 모드 3종 ↔ 두 호스트의 에이전트 이름·모델·effort. 여기가 정본이고 mode 파일이 이걸 인용한다.
MODES = {
    "1": {
        "claude": ("plan-implementer-sonnet-xhigh", "sonnet", "xhigh"),
        "codex": ("plan-implementer-terra-medium", "gpt-5.6-terra", "medium"),
    },
    "2b": {
        "claude": ("plan-implementer-sonnet-medium", "sonnet", "medium"),
        "codex": ("plan-implementer-gpt56-medium", "gpt-5.6", "medium"),
    },
    "3": {
        "claude": ("plan-implementer-opus-xhigh", "opus", "xhigh"),
        "codex": ("plan-implementer-gpt56-xhigh", "gpt-5.6", "xhigh"),
    },
}
# 파일명 토큰 → 실제 Codex 모델 슬러그. 슬러그에 점이 있어 파일명에 그대로 못 쓴다.
CODEX_SLUG = {"terra": "gpt-5.6-terra", "gpt56": "gpt-5.6"}

errors = []


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return {}
    body = text.split("---\n", 2)[1]
    out = {}
    for line in body.splitlines():
        match = re.match(r"^([A-Za-z_]+):\s*(.+?)\s*$", line)
        if match:
            out[match.group(1)] = match.group(2)
    return out


# 1) 이름이 주장하는 model·effort 가 frontmatter 와 같은가 (Claude)
for path in sorted((root / "woobin-harness/agents").glob("plan-implementer-*.md")):
    stem = path.stem
    parts = stem.split("-")
    claimed_model, claimed_effort = parts[-2], parts[-1]
    data = frontmatter(path)
    if data.get("name") != stem:
        errors.append(f"{path}: name={data.get('name')!r} != filename {stem!r}")
    if data.get("model") != claimed_model:
        errors.append(f"{path}: 이름은 model={claimed_model!r} 인데 frontmatter 는 {data.get('model')!r}")
    if data.get("effort") != claimed_effort:
        errors.append(f"{path}: 이름은 effort={claimed_effort!r} 인데 frontmatter 는 {data.get('effort')!r}")

# 2) 같은 검사 (Codex TOML)
for path in sorted((root / "codex/agents").glob("plan-implementer-*.toml")):
    stem = path.stem
    parts = stem.split("-")
    claimed_slug_token, claimed_effort = parts[-2], parts[-1]
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    if data.get("name") != stem:
        errors.append(f"{path}: name={data.get('name')!r} != filename {stem!r}")
    expected_model = CODEX_SLUG.get(claimed_slug_token)
    if expected_model is None:
        errors.append(f"{path}: 파일명 토큰 {claimed_slug_token!r} 이 CODEX_SLUG 에 없다")
    elif data.get("model") != expected_model:
        errors.append(f"{path}: 이름은 model={expected_model!r} 인데 TOML 은 {data.get('model')!r}")
    if data.get("model_reasoning_effort") != claimed_effort:
        errors.append(
            f"{path}: 이름은 effort={claimed_effort!r} 인데 TOML 은 {data.get('model_reasoning_effort')!r}"
        )

# 3) 모드 3종이 두 호스트에 모두 존재하는가, 그리고 값이 MODES 와 같은가
for mode, hosts in MODES.items():
    name, model, effort = hosts["claude"]
    path = root / "woobin-harness/agents" / f"{name}.md"
    if not path.exists():
        errors.append(f"모드 {mode}: {path} 가 없다")
    name, model, effort = hosts["codex"]
    path = root / "codex/agents" / f"{name}.toml"
    if not path.exists():
        errors.append(f"모드 {mode}: {path} 가 없다")

# 4) 핀 없는 옛 정의가 남아 있으면 실패 — 세션 effort 상속 경로가 살아 있다는 뜻이다
for stale in (root / "woobin-harness/agents/plan-implementer.md", root / "codex/agents/plan-implementer.toml"):
    if stale.exists():
        errors.append(f"{stale}: model·effort 가 안 박힌 옛 정의가 남아 있다 — 지워라")

# 5) mode 파일이 세 이름을 실제로 인용하는가 (Task 2 가 이 검사에 걸린다)
claude_modes = (root / "woobin-harness/plan-exec-modes.md").read_text(encoding="utf-8")
codex_modes = (root / "woobin-harness/plan-exec-modes-codex.md").read_text(encoding="utf-8")
for mode, hosts in MODES.items():
    if hosts["claude"][0] not in claude_modes:
        errors.append(f"plan-exec-modes.md 에 {hosts['claude'][0]} 인용이 없다")
    if hosts["codex"][0] not in codex_modes:
        errors.append(f"plan-exec-modes-codex.md 에 {hosts['codex'][0]} 인용이 없다")

if errors:
    for line in errors:
        print(f"  ✗ {line}")
    raise SystemExit(1)
PY

pass "에이전트 이름 ↔ frontmatter model·effort 일치"

for f in "$ROOT"/woobin-harness/agents/*.md; do
  head -1 "$f" | grep -q '^---$' || fail "$f: frontmatter 가 --- 로 시작하지 않는다"
done
pass "에이전트 frontmatter 구분자"

- [ ] **Step 2: Run the fixture to verify it fails**

```bash
chmod +x scripts/test-agents.sh && ./scripts/test-agents.sh
```

Expected: FAIL. The three variants do not exist yet, `woobin-harness/agents/plan-implementer.md` is still present, and the mode files do not quote the new names.

- [ ] **Step 3: Create the three Claude agent definitions**

All three share one body — the current `woobin-harness/agents/plan-implementer.md` body, unchanged. Only the frontmatter differs. Copy the body verbatim; do not rewrite it.

`woobin-harness/agents/plan-implementer-sonnet-medium.md` (mode ②b — the one most plans use):

```markdown
---
name: plan-implementer-sonnet-medium
description: Implements one layer of a plan — a group of task-N.md files that must run in order — and reports back a short summary. Mode ②b default. Pass the task file paths in execution order plus the overview path; never paste task bodies into the prompt. Model and effort are pinned here, so do not pass a model argument.
model: sonnet
effort: medium
tools: Read, Write, Edit, Grep, Glob, Bash, TodoWrite, Skill
memory: local
maxTurns: 60
---
```

Then the body, copied verbatim from the deleted `plan-implementer.md`, starting at `You implement one layer of an already-written plan.` and ending at `Do not paste diffs, file contents, or test output verbatim. Do not spawn subagents. Do not commit unless a task file tells you to.`

`woobin-harness/agents/plan-implementer-sonnet-xhigh.md` — same body, frontmatter:

```markdown
---
name: plan-implementer-sonnet-xhigh
description: Implements one track of a plan in an isolated worktree — a group of task-N.md files that share no files with other tracks — and reports back a short summary. Mode ① speed. Pass the task file paths in execution order plus the overview path; never paste task bodies into the prompt. Model and effort are pinned here, so do not pass a model argument.
model: sonnet
effort: xhigh
tools: Read, Write, Edit, Grep, Glob, Bash, TodoWrite, Skill
memory: local
maxTurns: 60
---
```

`woobin-harness/agents/plan-implementer-opus-xhigh.md` — same body, frontmatter:

```markdown
---
name: plan-implementer-opus-xhigh
description: Implements one layer of a high-stakes plan — migrations, prod-facing changes, UI that automated gates cannot check — and reports back a short summary. Mode ③. Pass the task file paths in execution order plus the overview path; never paste task bodies into the prompt. Model and effort are pinned here, so do not pass a model argument.
model: opus
effort: xhigh
tools: Read, Write, Edit, Grep, Glob, Bash, TodoWrite, Skill
memory: local
maxTurns: 60
---
```

Do not put a colon followed by a space inside any `description:` value. YAML parses that as a mapping and every frontmatter field is silently dropped; only `claude plugin validate` detects it (`CLAUDE.md`, 2026-08-08 `Explore.md` incident). The descriptions above already avoid it — keep it that way if you reword them.

Then delete the old definition:

```bash
git rm woobin-harness/agents/plan-implementer.md
```

- [ ] **Step 4: Create the three Codex agent definitions**

Same pattern. The body is the `developer_instructions` string from the deleted `codex/agents/plan-implementer.toml`, copied verbatim.

`codex/agents/plan-implementer-gpt56-medium.toml`:

```toml
name = "plan-implementer-gpt56-medium"
description = "Implements one ordered layer of task-N.md plan files and returns a short verification summary. Mode 2b default."
model = "gpt-5.6"
model_reasoning_effort = "medium"
developer_instructions = """
Implement one layer of an existing plan without redesigning it. Read 00-overview.md first, then read each assigned task-N.md immediately before implementing it. Execute tasks in the supplied order. For every task, implement exactly the specified change, run its completion checks, fix failures, and rerun before continuing. Stop and report instead of guessing when the plan contradicts the code, requires user confirmation, or hits an unanticipated non-obvious failure. Do not spawn subagents or commit unless the task explicitly says to. Keep the final report under 25 lines: one status line per task, changed paths, verification results, and any blocker.
"""
```

`codex/agents/plan-implementer-terra-medium.toml` — identical except:

```toml
name = "plan-implementer-terra-medium"
description = "Implements one independent track of task-N.md plan files in an isolated worktree and returns a short verification summary. Mode 1 speed."
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"
```

`codex/agents/plan-implementer-gpt56-xhigh.toml` — identical except:

```toml
name = "plan-implementer-gpt56-xhigh"
description = "Implements one ordered layer of a high-stakes plan and returns a short verification summary. Mode 3 max quality."
model = "gpt-5.6"
model_reasoning_effort = "xhigh"
```

Then:

```bash
git rm codex/agents/plan-implementer.toml
```

- [ ] **Step 5: Update `scripts/validate-codex.sh`**

It hardcodes both the agent count and a per-agent expectation dict. Change the count guard from `4` to `6`:

```python
if len(paths) != 6:
    raise SystemExit(f"expected 6 Codex agents, found {len(paths)}")
```

and replace the single `plan-implementer` entry in `expected` with the three new ones, leaving `explorer`, `plan-reviewer`, and `screenshot-verifier` untouched:

```python
    "plan-implementer-terra-medium": {"model": "gpt-5.6-terra", "model_reasoning_effort": "medium"},
    "plan-implementer-gpt56-medium": {"model": "gpt-5.6", "model_reasoning_effort": "medium"},
    "plan-implementer-gpt56-xhigh": {"model": "gpt-5.6", "model_reasoning_effort": "xhigh"},
```

- [ ] **Step 6: Run the checks**

```bash
./scripts/test-agents.sh
```

Expected at this point: still FAIL, on check 5 only — `plan-exec-modes.md` and `plan-exec-modes-codex.md` do not quote the new names yet. That is Task 2's job. Every other check must pass. If anything other than the six "인용이 없다" lines appears, fix it here.

```bash
claude plugin validate ./woobin-harness
```

Expected: PASS. This is the only thing that catches broken agent frontmatter.

- [ ] **Step 7: Commit**

```bash
git add woobin-harness/agents codex/agents scripts/test-agents.sh scripts/validate-codex.sh
git commit -m "feat(agents): plan-implementer를 model·effort 고정 변이체 3종으로 대체"
```
