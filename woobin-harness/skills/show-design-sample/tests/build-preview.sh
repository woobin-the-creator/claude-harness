#!/bin/sh
set -eu

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/show-design-build.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM

REPO_ROOT=$(git rev-parse --show-toplevel)
SCRIPT_ROOT=$REPO_ROOT/woobin-harness/skills/show-design-sample
BUILD=$SCRIPT_ROOT/scripts/build-preview.sh
SERVE=$SCRIPT_ROOT/scripts/serve-preview.sh
VERIFY=$SCRIPT_ROOT/scripts/verify-dist.mjs

make_app() {
  app_dir=$1
  mkdir -p "$app_dir/.preview" "$app_dir/node_modules/.bin"
  printf '%s\n' 'export default {}' > "$app_dir/.preview/vite.preview.config.ts"
  cat > "$app_dir/node_modules/.bin/vite" <<'EOF'
#!/bin/sh
set -eu
app_dir=$(pwd)
printf '%s\n' "$*" >> "$app_dir/vite.log"
mode=${1:-}
shift || true
case "$mode" in
  build)
    mkdir -p "$app_dir/.preview/.dist/assets"
    cat > "$app_dir/.preview/.dist/index.html" <<'HTML'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <link rel="stylesheet" href="./assets/site.css?v=1#top" />
  </head>
  <body>
    <script type="module" src="/assets/app.js?cache=1#main"></script>
  </body>
</html>
HTML
    printf '%s\n' 'console.log("preview ok")' > "$app_dir/.preview/.dist/assets/app.js"
    printf '%s\n' 'body{background:#fff;}' > "$app_dir/.preview/.dist/assets/site.css"
    ;;
  preview)
    printf '%s\n' "preview:$*" >> "$app_dir/serve.log"
    ;;
  *)
    echo "unexpected vite mode: $mode" >&2
    exit 91
    ;;
esac
EOF
  chmod +x "$app_dir/node_modules/.bin/vite"
}

mkdir -p "$ROOT/no-npx-bin"
cat > "$ROOT/no-npx-bin/npx" <<'EOF'
#!/bin/sh
echo "NPX_FORBIDDEN $*" >> "${NPX_LOG:?}"
exit 97
EOF
chmod +x "$ROOT/no-npx-bin/npx"

APP=$ROOT/frontend
mkdir -p "$APP"
make_app "$APP"
NPX_LOG=$ROOT/npx.log
export NPX_LOG

PATH="$ROOT/no-npx-bin:$PATH" "$BUILD" "$APP" >"$ROOT/build.out"
grep -Fx 'DIST_OK files=3' "$ROOT/build.out"
test -f "$APP/.preview/.dist/index.html"
test -f "$APP/.preview/.dist/assets/app.js"
test ! -f "$NPX_LOG"
grep -Fqx 'build --config .preview/vite.preview.config.ts' "$APP/vite.log"

rm "$APP/.preview/.dist/assets/app.js"
if node "$VERIFY" "$APP/.preview/.dist" >"$ROOT/verify-missing.out" 2>"$ROOT/verify-missing.err"; then
  echo "expected missing asset failure" >&2
  exit 1
fi
grep -Fx 'assets/app.js' "$ROOT/verify-missing.out"

PATH="$ROOT/no-npx-bin:$PATH" "$SERVE" "$APP" >/dev/null
grep -Fqx 'preview --config .preview/vite.preview.config.ts --host 127.0.0.1' "$APP/vite.log"
grep -Fqx 'preview:--config .preview/vite.preview.config.ts --host 127.0.0.1' "$APP/serve.log"

APP_NO_VITE=$ROOT/no-vite
mkdir -p "$APP_NO_VITE/.preview"
printf '%s\n' 'export default {}' > "$APP_NO_VITE/.preview/vite.preview.config.ts"
if "$BUILD" "$APP_NO_VITE" >"$ROOT/no-vite.out" 2>"$ROOT/no-vite.err"; then
  echo "expected missing vite failure" >&2
  exit 1
fi
grep -Fx 'LOCAL_VITE_REQUIRED' "$ROOT/no-vite.err"

echo ALL-OK
