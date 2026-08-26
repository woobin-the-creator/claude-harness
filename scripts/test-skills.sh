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
[ "$skill_count" -eq 19 ] || fail "expected 19 skills, found $skill_count"
pass "19 packaged skills"

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
expected = {"hooks": 12, "agents": 4, "skills": 19}
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

# render.cjs needs project-provided Playwright plus a local Chrome channel. Its
# syntax is covered above; report whether this machine can run the live renderer.
if node -e "require.resolve('playwright', {paths:[process.cwd()]})" >/dev/null 2>&1; then
  printf 'ℹ explain renderer: Playwright is resolvable; live Chrome launch remains environment-dependent.\n'
else
  printf 'ℹ explain renderer: optional Playwright dependency is not installed in this repo.\n'
fi

printf 'All network-free bundled skill fixtures passed.\n'
