#!/bin/sh
# 에이전트 정의 fixture — 리뷰어 2종의 frontmatter 계약과 호출 지점 인용을 기계가 센다.
#
# 왜: 리뷰 2회(spec-reviewer·code-reviewer)는 둘 다 frontmatter 가 model·effort·tools 를 소유하는
# 전용 프로필이다(issue #41). Agent 호출에 effort 인자가 없어 frontmatter 가 유일한 운반 수단이고,
# 누가 frontmatter 만 고치면 "opus 리뷰"가 조용히 다른 모델로 돌거나, tools 에 Edit 가 섞여
# "리뷰만 하는" 독립 컨텍스트가 코드를 고치기 시작해도 증상이 없다.
# 호출 지점(interview 스킬·spec-reviewer-prompt.md)이 옛 이름을 부르면 리뷰가 아예 안 돈다 —
# 그래서 인용도 함께 센다.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)

fail() { printf '✗ %s\n' "$*" >&2; exit 1; }
pass() { printf '✓ %s\n' "$*"; }

python3 - "$ROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])

# 리뷰어 2종 ↔ model·effort. 여기가 정본이다.
REVIEWERS = {
    "spec-reviewer": ("opus", "medium"),
    "code-reviewer": ("opus", "medium"),
}
REQUIRED_TOOLS = {"Read", "Grep", "Glob", "Bash"}
FORBIDDEN_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

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


# 1) 리뷰어 2종이 존재하고 frontmatter 계약(name·model·effort·읽기 전용 tools)을 지키는가.
for name, (model, effort) in REVIEWERS.items():
    path = root / "woobin-harness/agents" / f"{name}.md"
    if not path.exists():
        errors.append(f"{path} 가 없다")
        continue
    data = frontmatter(path)
    if data.get("name") != name:
        errors.append(f"{path}: name={data.get('name')!r} != filename {name!r}")
    if data.get("model") != model:
        errors.append(f"{path}: model={data.get('model')!r}, 기대값 {model!r}")
    if data.get("effort") != effort:
        errors.append(f"{path}: effort={data.get('effort')!r}, 기대값 {effort!r}")
    tools = {t.strip() for t in data.get("tools", "").split(",") if t.strip()}
    missing = REQUIRED_TOOLS - tools
    if missing:
        errors.append(f"{path}: tools 에 {sorted(missing)} 가 없다")
    leaked = FORBIDDEN_TOOLS & tools
    if leaked:
        errors.append(f"{path}: 리뷰어인데 tools 에 편집 도구 {sorted(leaked)} 가 있다")

# 2) 호출 지점이 네임스페이스 이름으로 리뷰어를 인용하는가.
CITES = {
    "woobin-harness/skills/interview/spec-reviewer-prompt.md": "woobin-harness:spec-reviewer",
    "woobin-harness/skills/interview/SKILL.md": "woobin-harness:code-reviewer",
}
for rel, needle in CITES.items():
    path = root / rel
    if not path.exists():
        errors.append(f"{rel} 가 없다")
    elif needle not in path.read_text(encoding="utf-8"):
        errors.append(f"{rel} 에 {needle} 인용이 없다")

if errors:
    for line in errors:
        print(f"  ✗ {line}")
    raise SystemExit(1)
PY

pass "리뷰어 2종 frontmatter 계약 + 호출 지점 인용"

for f in "$ROOT"/woobin-harness/agents/*.md; do
  head -1 "$f" | grep -q '^---$' || fail "$f: frontmatter 가 --- 로 시작하지 않는다"
done
pass "에이전트 frontmatter 구분자"
