#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: build-preview.sh <app-dir>" >&2
  exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

resolve_dir() {
  target=$1
  [ -d "$target" ] || return 1
  CDPATH= cd -- "$target" && pwd -P
}

APP_DIR=$(resolve_dir "$1") || {
  echo "APP_DIR_REQUIRED" >&2
  exit 1
}

VITE=$APP_DIR/node_modules/.bin/vite
if [ ! -x "$VITE" ]; then
  echo "LOCAL_VITE_REQUIRED" >&2
  exit 2
fi

cd "$APP_DIR"
"$VITE" build --config .preview/vite.preview.config.ts
node "$SCRIPT_DIR/verify-dist.mjs" "$APP_DIR/.preview/.dist"
