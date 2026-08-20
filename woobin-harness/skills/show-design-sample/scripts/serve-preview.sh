#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: serve-preview.sh <app-dir>" >&2
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

"$SCRIPT_DIR/build-preview.sh" "$APP_DIR" >/dev/null

VITE=$APP_DIR/node_modules/.bin/vite
if [ ! -x "$VITE" ]; then
  echo "LOCAL_VITE_REQUIRED" >&2
  exit 2
fi

cd "$APP_DIR"
exec "$VITE" preview --config .preview/vite.preview.config.ts --host 127.0.0.1
