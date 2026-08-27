#!/bin/sh
# Deterministic, network-free fixtures for bundled skill assets.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
SKILLS="$ROOT/woobin-harness/skills"
TEST_ROOT=$(mktemp -d)

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() { printf '✗ %s\n' "$*" >&2; exit 1; }
pass() { printf '✓ %s\n' "$*"; }

skill_count=$(find "$SKILLS" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' ';' -print | wc -l | tr -d ' ')
[ "$skill_count" -eq 21 ] || fail "expected 21 skills, found $skill_count"
pass "21 packaged skills"

for script in $(find "$SKILLS" -type f -name '*.sh' -print); do
  case "$(sed -n '1p' "$script")" in
    *bash*) bash -n "$script" ;;
    *) sh -n "$script" ;;
  esac
done
PYTHONPYCACHEPREFIX="$TEST_ROOT/pycache" python3 -m py_compile \
  $(find "$SKILLS" -type f -name '*.py' -print)
for script in $(find "$SKILLS" -type f \( -name '*.js' -o -name '*.cjs' -o -name '*.mjs' \) -print); do
  node --check "$script" >/dev/null
done
for archive in $(find "$SKILLS" -type f -name '*.tar.gz' -print); do
  tar -tzf "$archive" >/dev/null
done
pass "shell, Python, JavaScript, and archive syntax"

python3 - "$SKILLS" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
missing = []
for path in root.rglob("*.md"):
    fenced = False
    for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            continue
        for match in re.finditer(r"(?<!!)\[[^\]]*\]\(([^)]+)\)", line):
            target = match.group(1).strip().split()[0].strip("<>")
            if not target or target.startswith(("http://", "https://", "#", "mailto:", "data:", "/")):
                continue
            if any(char in target for char in "$*{}"):
                continue
            target = target.split("#", 1)[0]
            if target and not (path.parent / target).resolve().exists():
                missing.append(f"{path}:{number}: {target}")
if missing:
    raise SystemExit("missing packaged Markdown targets:\n" + "\n".join(missing))
PY
pass "packaged Markdown references"

mkdir -p "$TEST_ROOT/projects" "$TEST_ROOT/history"
scan="$TEST_ROOT/scan.json"
audit="$TEST_ROOT/audit.json"
python3 "$SKILLS/token-waste-audit/scripts/waste_scan.py" \
  --projects-dir "$TEST_ROOT/projects" --days 1 --out "$scan" >/dev/null 2>&1
python3 "$SKILLS/token-waste-audit/scripts/extract_excerpts.py" --scan "$scan" \
  | grep -q 'TTL 1h' || fail "token-waste excerpt fixture"
python3 "$SKILLS/capability-audit/scripts/collect.py" \
  --repo "$ROOT" --projects-dir "$TEST_ROOT/projects" --history-dir "$TEST_ROOT/history" \
  --days 1 --out "$audit" >/dev/null
python3 - "$audit" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
expected = {"hooks": 13, "agents": 4, "skills": 21}
assert data["A3_hygiene"]["installed"] == expected, data["A3_hygiene"]["installed"]
assert not any("waste_scan.py not found" in error for error in data["errors"]), data["errors"]
PY
pass "token-waste and capability-audit analyzers"

cat >"$TEST_ROOT/source.html" <<'EOF'
<!doctype html><html><head>
<title>Fixture | Claude</title>
<script type="application/ld+json">{"datePublished":"2026-08-12"}</script>
</head><body>
<img class="hero_blog_post_illo_img" src="hero.svg">
<figure><img src="content.png"><figcaption>Fixture caption</figcaption></figure>
<iframe src="https://www.youtube.com/embed/fixture01" title="Fixture video"></iframe>
<video src="clip.mp4"></video>
<a href="https://github.com/example/repo">Repository</a>
</body></html>
EOF
python3 "$SKILLS/claude-blog-translate-ko/scripts/extract_media.py" "$TEST_ROOT/source.html" \
  >"$TEST_ROOT/media.json"
python3 - "$TEST_ROOT/media.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["title"] == "Fixture"
assert data["hero"] == "hero.svg"
assert data["content_images"] == [{"src": "content.png", "caption": "Fixture caption"}]
assert data["youtube"][0]["src"].endswith("/fixture01")
assert data["videos"] == ["clip.mp4"]
assert data["links"][0]["href"] == "https://github.com/example/repo"
PY
pass "blog media extractor"

mkdir -p "$TEST_ROOT/blog/posts/assets"
cat >"$TEST_ROOT/blog/posts/assets/posts.js" <<'EOF'
(function () {
  window.CBK_POSTS = [
  ];
})();
EOF
printf '<p>fixture body</p>\n' >"$TEST_ROOT/body.html"
assemble() {
  python3 "$SKILLS/claude-youtube-to-blog/scripts/assemble_post.py" \
    --repo "$TEST_ROOT/blog" --slug fixture-post --title "Fixture title" --nav "Fixture" \
    --main "Fixture Youtube" --cat "Test" --date 2026-08-12 \
    --video-url "https://www.youtube.com/watch?v=fixture01" \
    --video-title "Fixture video" --body-file "$TEST_ROOT/body.html" >/dev/null
}
assemble
assemble
[ "$(grep -c 'file: "fixture-post.html"' "$TEST_ROOT/blog/posts/assets/posts.js")" -eq 1 ] \
  || fail "post assembler is not idempotent"
grep -q '<p>fixture body</p>' "$TEST_ROOT/blog/posts/fixture-post.html" \
  || fail "post assembler omitted body"
node --check "$TEST_ROOT/blog/posts/assets/posts.js" >/dev/null
pass "YouTube post assembler idempotence"

# 세션 귀속: 서브에이전트 트랜스크립트가 sidechain 으로 잡히는지.
attr_root="$TEST_ROOT/attr/projects/proj-a"
mkdir -p "$attr_root/sess0001/subagents"
attr_usage='{"input_tokens":1000,"output_tokens":500,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}'
printf '%s\n' \
  "{\"type\":\"assistant\",\"requestId\":\"r-main\",\"timestamp\":\"2026-08-26T00:00:00Z\",\"message\":{\"model\":\"claude-opus-5\",\"usage\":$attr_usage,\"content\":[{\"type\":\"tool_use\",\"id\":\"t1\",\"name\":\"Read\",\"input\":{\"file_path\":\"/x\"}}]}}" \
  >"$TEST_ROOT/attr/projects/proj-a/sess0001.jsonl"
printf '%s\n' \
  "{\"type\":\"assistant\",\"requestId\":\"r-sub\",\"timestamp\":\"2026-08-26T00:01:00Z\",\"message\":{\"model\":\"claude-sonnet-5\",\"usage\":$attr_usage,\"content\":[{\"type\":\"tool_use\",\"id\":\"t2\",\"name\":\"Grep\",\"input\":{\"pattern\":\"y\"}}]}}" \
  >"$attr_root/sess0001/subagents/agent-abcdef01.jsonl"

attr_out="$TEST_ROOT/attr/waste.json"
python3 "$ROOT/woobin-harness/skills/token-waste-audit/scripts/waste_scan.py" \
  --projects-dir "$TEST_ROOT/attr/projects" --out "$attr_out" >/dev/null \
  || fail "waste_scan.py failed on the attribution fixture"

python3 - "$attr_out" <<'ATTRPY' || fail "waste_scan.py attributes a subagent transcript to the main lane"
import json, sys
r = json.load(open(sys.argv[1]))
lanes = r.get("cost_by_lane") or {}
side = sum((lanes.get("sidechain") or {}).values())
main = sum((lanes.get("main") or {}).values())
assert side > 0, f"sidechain lane is empty; main={main}"
assert r.get("file_count") == 2, f"expected 2 transcripts, got {r.get('file_count')}"
ATTRPY

attr_collect="$TEST_ROOT/attr/collect.json"
python3 "$ROOT/woobin-harness/skills/capability-audit/scripts/collect.py" \
  --repo "$ROOT" --projects-dir "$TEST_ROOT/attr/projects" --days 3650 \
  --out "$attr_collect" >/dev/null \
  || fail "collect.py failed on the attribution fixture"

python3 - "$attr_collect" <<'ATTRPY2' || fail "collect.py never reads subagents/*.jsonl"
import json, sys
r = json.load(open(sys.argv[1]))
sidechain = r.get("raw", {}).get("tool_by_lane", {}).get("sidechain", {})
assert "Grep" in sidechain, "the subagent's Grep call is not attributed to the sidechain lane"
ATTRPY2

pass "subagent transcripts are attributed to the sidechain lane"

# contact-sheet.sh: 3장을 가로로 이어 붙인 단일 PNG만 내보낸다.
sh -n "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" \
  || fail "contact-sheet.sh has a syntax error"
[ -x "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" ] \
  || fail "contact-sheet.sh is not executable"

if command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; then
  cs_dir="$TEST_ROOT/contact-sheet"
  mkdir -p "$cs_dir"
  for cs_n in 1 2 3; do
    ffmpeg -nostdin -hide_banner -loglevel error -y \
      -f lavfi -i "color=c=black:s=64x48:d=1" -frames:v 1 "$cs_dir/f$cs_n.png"
  done
  "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" \
    "$cs_dir/f1.png" "$cs_dir/f2.png" "$cs_dir/f3.png" "$cs_dir/out.png" >/dev/null \
    || fail "contact-sheet.sh failed on three equal-sized frames"
  cs_dim=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
             -of csv=p=0:s=x -i "$cs_dir/out.png")
  [ "$cs_dim" = "192x48" ] || fail "contact sheet is not triple-width: $cs_dim"

  # 기존 출력을 덮어쓰지 않는다.
  if "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" \
       "$cs_dir/f1.png" "$cs_dir/f2.png" "$cs_dir/f3.png" "$cs_dir/out.png" >/dev/null 2>&1; then
    fail "contact-sheet.sh overwrote an existing output"
  fi

  # .png 가 아닌 출력은 거부한다.
  if "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" \
       "$cs_dir/f1.png" "$cs_dir/f2.png" "$cs_dir/f3.png" "$cs_dir/out.mp4" >/dev/null 2>&1; then
    fail "contact-sheet.sh accepted a non-PNG output"
  fi
  pass "contact-sheet.sh stacks three frames and refuses unsafe outputs"
else
  printf 'ℹ contact-sheet.sh: ffmpeg/ffprobe unavailable; only syntax was checked.\n'
fi

# render.cjs needs project-provided Playwright plus a local Chrome channel. Its
# syntax is covered above; report whether this machine can run the live renderer.
if node -e "require.resolve('playwright', {paths:[process.cwd()]})" >/dev/null 2>&1; then
  printf 'ℹ explain-in-html renderer: Playwright is resolvable; live Chrome launch remains environment-dependent.\n'
else
  printf 'ℹ explain-in-html renderer: optional Playwright dependency is not installed in this repo.\n'
fi

printf 'All network-free bundled skill fixtures passed.\n'
