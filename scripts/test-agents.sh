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

root = pathlib.Path(sys.argv[1])

# 모드 3종 ↔ 에이전트 이름·모델·effort. 여기가 정본이고 plan-exec-modes.md 가 이걸 인용한다.
MODES = {
    "1": ("plan-implementer-sonnet-xhigh", "sonnet", "xhigh"),
    "2b": ("plan-implementer-sonnet-medium", "sonnet", "medium"),
    "3": ("plan-implementer-opus-xhigh", "opus", "xhigh"),
}

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


# 1) 이름이 주장하는 model·effort 가 frontmatter 와 같은가.
#    `plan-implementer-*`(구현자)와 `plan-doc-reviewer-*`(문서 리뷰어) 둘 다 파일명 끝 두 토큰이
#    model·effort 를 주장한다 — Agent 호출에 effort 인자가 없어 frontmatter 가 유일한 운반 수단이라서다.
for glob in ("plan-implementer-*.md", "plan-doc-reviewer-*.md"):
    for path in sorted((root / "woobin-harness/agents").glob(glob)):
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

# 2) 모드 3종이 모두 존재하는가
for mode, (name, model, effort) in MODES.items():
    path = root / "woobin-harness/agents" / f"{name}.md"
    if not path.exists():
        errors.append(f"모드 {mode}: {path} 가 없다")

# 3) 핀 없는 옛 정의가 남아 있으면 실패 — 세션 effort 상속 경로가 살아 있다는 뜻이다
stale = root / "woobin-harness/agents/plan-implementer.md"
if stale.exists():
    errors.append(f"{stale}: model·effort 가 안 박힌 옛 정의가 남아 있다 — 지워라")

# 4) mode 파일이 세 이름을 실제로 인용하는가
modes_doc = (root / "woobin-harness/plan-exec-modes.md").read_text(encoding="utf-8")
for mode, (name, model, effort) in MODES.items():
    if name not in modes_doc:
        errors.append(f"plan-exec-modes.md 에 {name} 인용이 없다")

# 5) 문서 리뷰어 2종이 존재하고, dispatch 소유자(plan-document-reviewer-prompt.md)가 둘을 인용하는가.
#    이 둘은 ③ 트리거 여부로 갈리는 티어라, 이름이 갈라지면 writing-plans 가 옛 이름을 부른다.
REVIEWERS = ("plan-doc-reviewer-opus-medium", "plan-doc-reviewer-opus-xhigh")
prompt_doc_path = root / "woobin-harness/skills/writing-plans/plan-document-reviewer-prompt.md"
prompt_doc = prompt_doc_path.read_text(encoding="utf-8") if prompt_doc_path.exists() else ""
for name in REVIEWERS:
    if not (root / "woobin-harness/agents" / f"{name}.md").exists():
        errors.append(f"문서 리뷰어 {name}.md 가 없다")
    if name not in prompt_doc:
        errors.append(f"plan-document-reviewer-prompt.md 에 {name} 인용이 없다")

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
