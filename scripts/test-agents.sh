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
