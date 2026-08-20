#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: init-preview.sh <repo-root> [app-dir]" >&2
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEMPLATE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../templates" && pwd -P)

fail_app_dir_required() {
  echo "APP_DIR_REQUIRED" >&2
  exit 2
}

resolve_dir() {
  target=$1
  [ -d "$target" ] || return 1
  CDPATH= cd -- "$target" && pwd -P
}

resolve_display_dir() {
  target=$1
  [ -d "$target" ] || return 1
  case "$target" in
    /*)
      while [ "$target" != "/" ] && [ "${target%/}" != "$target" ]; do
        target=${target%/}
      done
      printf '%s\n' "$target"
      ;;
    *)
      CDPATH= cd -- "$target" && pwd
      ;;
  esac
}

contains_vite_dependency() {
  package_json=$1
  [ -f "$package_json" ] || return 1
  node -e '
const fs = require("node:fs")
const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"))
const sections = ["dependencies", "devDependencies", "optionalDependencies", "peerDependencies"]
process.exit(sections.some((section) => {
  const deps = pkg[section]
  return deps && typeof deps === "object" && Object.prototype.hasOwnProperty.call(deps, "vite")
}) ? 0 : 1)
' "$package_json"
}

has_local_preview_dependencies() {
  app_dir=$1
  [ -f "$app_dir/package.json" ] || return 1
  [ -x "$app_dir/node_modules/.bin/vite" ] || return 1
  [ -f "$app_dir/node_modules/@vitejs/plugin-react/package.json" ] || return 1
}

ensure_inside_repo() {
  target=$1
  case "$target" in
    "$REPO_ROOT"|"$REPO_ROOT"/*) return 0 ;;
  esac
  return 1
}

validate_app_dir() {
  app_dir=$1
  ensure_inside_repo "$app_dir" || return 1
  contains_vite_dependency "$app_dir/package.json" || return 1
  has_local_preview_dependencies "$app_dir" || return 1
}

find_single_nested_candidate() {
  count=0
  candidate=
  while IFS= read -r package_json; do
    app_dir=${package_json%/package.json}
    if validate_app_dir "$app_dir"; then
      count=$((count + 1))
      candidate=$app_dir
    fi
  done <<EOF
$(find "$REPO_ROOT" \
  \( -path "$REPO_ROOT/.git" -o -path "$REPO_ROOT/.preview" -o -path '*/node_modules' \) -prune -o \
  -type f -name package.json -mindepth 2 -maxdepth 4 -print)
EOF

  [ "$count" -eq 1 ] || return 1
  printf '%s\n' "$candidate"
}

REPO_ROOT_DISPLAY=$(resolve_display_dir "$1") || {
  echo "REPO_ROOT_REQUIRED" >&2
  exit 1
}

REPO_ROOT=$(resolve_dir "$1") || {
  echo "REPO_ROOT_REQUIRED" >&2
  exit 1
}

APP_DIR=
if [ "$#" -eq 2 ]; then
  case "$2" in
    /*) app_input=$2 ;;
    *) app_input=$REPO_ROOT/$2 ;;
  esac
  APP_DIR=$(resolve_dir "$app_input") || fail_app_dir_required
  validate_app_dir "$APP_DIR" || fail_app_dir_required
else
  if [ -f "$REPO_ROOT/frontend/package.json" ] && validate_app_dir "$REPO_ROOT/frontend"; then
    APP_DIR=$REPO_ROOT/frontend
  elif [ -f "$REPO_ROOT/package.json" ] && validate_app_dir "$REPO_ROOT"; then
    APP_DIR=$REPO_ROOT
  else
    APP_DIR=$(find_single_nested_candidate) || fail_app_dir_required
  fi
fi

APP_DIR_DISPLAY=$REPO_ROOT_DISPLAY${APP_DIR#"$REPO_ROOT"}
PREVIEW_DIR=$APP_DIR/.preview
mkdir -p "$PREVIEW_DIR/variants"
cp "$TEMPLATE_DIR/index.html" "$PREVIEW_DIR/index.html"
cp "$TEMPLATE_DIR/main.tsx" "$PREVIEW_DIR/main.tsx"
cp "$TEMPLATE_DIR/vite.preview.config.ts" "$PREVIEW_DIR/vite.preview.config.ts"
if [ ! -f "$PREVIEW_DIR/fixtures.ts" ]; then
  cp "$TEMPLATE_DIR/fixtures.ts" "$PREVIEW_DIR/fixtures.ts"
fi

EXCLUDE_FILE=$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-path info/exclude)
touch "$EXCLUDE_FILE"
if [ "$APP_DIR" = "$REPO_ROOT" ]; then
  EXCLUDE_ENTRY='/.preview/'
else
  EXCLUDE_ENTRY=${APP_DIR#"$REPO_ROOT"}
  EXCLUDE_ENTRY=$EXCLUDE_ENTRY/.preview/
fi
if ! grep -Fqx "$EXCLUDE_ENTRY" "$EXCLUDE_FILE"; then
  printf '%s\n' "$EXCLUDE_ENTRY" >> "$EXCLUDE_FILE"
fi

printf '%s\n' "APP_DIR=$APP_DIR_DISPLAY"
