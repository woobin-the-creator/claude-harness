#!/bin/sh
set -eu

SCRIPT=$(git rev-parse --show-toplevel)/woobin-harness/skills/show-design-sample/scripts/init-preview.sh

make_local_vite_app() {
  app_dir=$1
  mkdir -p \
    "$app_dir/node_modules/.bin" \
    "$app_dir/node_modules/@vitejs/plugin-react" \
    "$app_dir/src"
  printf '%s\n' '{"devDependencies":{"vite":"7.3.2","@vitejs/plugin-react":"5.2.0"}}' > "$app_dir/package.json"
  printf '%s\n' '/node_modules/' > "$app_dir/.gitignore"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$app_dir/node_modules/.bin/vite"
  chmod +x "$app_dir/node_modules/.bin/vite"
  printf '%s\n' '{"name":"@vitejs/plugin-react"}' > "$app_dir/node_modules/@vitejs/plugin-react/package.json"
}

assert_preview_initialized() {
  root=$1
  app_dir=$2
  output=$("$SCRIPT" "$root")
  printf '%s\n' "$output" | grep -F "APP_DIR=$app_dir"
  test -f "$app_dir/.preview/index.html"
  test -f "$app_dir/.preview/main.tsx"
  test -f "$app_dir/.preview/vite.preview.config.ts"
  test -f "$app_dir/.preview/fixtures.ts"
  git -C "$root" check-ignore -q "${app_dir#"$root"/}/.preview/index.html"
  test -z "$(git -C "$root" status --short)"
  "$SCRIPT" "$root" >/dev/null
  test "$(grep -Fc '/.preview/' "$(git -C "$root" rev-parse --path-format=absolute --git-path info/exclude)")" -ge 1
}

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/show-design-init.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM

git -C "$ROOT" init -q
make_local_vite_app "$ROOT/frontend"
git -C "$ROOT" add frontend/package.json frontend/.gitignore
git -C "$ROOT" -c user.name=test -c user.email=test@example.com commit -qm baseline

assert_preview_initialized "$ROOT" "$ROOT/frontend"
test "$(grep -Fc '/frontend/.preview/' "$(git -C "$ROOT" rev-parse --path-format=absolute --git-path info/exclude)")" -eq 1

ROOT_WITH_SCRIPT=$(mktemp -d "${TMPDIR:-/tmp}/show-design-init-root-script.XXXXXX")
trap 'rm -rf "$ROOT" "$ROOT_WITH_SCRIPT"' EXIT HUP INT TERM

git -C "$ROOT_WITH_SCRIPT" init -q
printf '%s\n' '{"scripts":{"vite":"vite --host 0.0.0.0"}}' > "$ROOT_WITH_SCRIPT/package.json"
make_local_vite_app "$ROOT_WITH_SCRIPT/apps/web"
git -C "$ROOT_WITH_SCRIPT" add package.json apps/web/package.json apps/web/.gitignore
git -C "$ROOT_WITH_SCRIPT" -c user.name=test -c user.email=test@example.com commit -qm baseline

assert_preview_initialized "$ROOT_WITH_SCRIPT" "$ROOT_WITH_SCRIPT/apps/web"
test "$(grep -Fc '/apps/web/.preview/' "$(git -C "$ROOT_WITH_SCRIPT" rev-parse --path-format=absolute --git-path info/exclude)")" -eq 1

echo ALL-OK
