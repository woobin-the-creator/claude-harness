#!/bin/sh
set -eu

usage() {
  echo "usage: deploy-preview.sh [--create-public] <app-dir> [owner/repo]" >&2
  exit 1
}

resolve_dir() {
  target=$1
  [ -d "$target" ] || return 1
  CDPATH= cd -- "$target" && pwd -P
}

repo_exists() {
  "$GH" repo view "$1" --json nameWithOwner --jq .nameWithOwner >/dev/null 2>&1
}

clone_repo() {
  repo=$1
  dest=$2
  rm -rf "$dest"
  "$GH" repo clone "$repo" "$dest" >/dev/null 2>/dev/null
}

ensure_pages_enabled() {
  repo=$1
  if ! "$GH" api "repos/$repo/pages" >/dev/null 2>&1; then
    "$GH" api -X POST "repos/$repo/pages" -f 'source[branch]=main' -f 'source[path]=/' >/dev/null
  fi
}

copy_tree() {
  src=$1
  dest=$2
  (
    cd "$src"
    tar cf - .
  ) | (
    cd "$dest"
    tar xpf -
  )
}

clean_deploy_dir() {
  dir=$1
  expected=$2
  [ "$dir" = "$expected" ] || {
    echo "DEPLOY_DIR_MISMATCH" >&2
    exit 1
  }

  for entry in "$dir"/.[!.]* "$dir"/..?* "$dir"/*; do
    if [ ! -e "$entry" ] && [ ! -L "$entry" ]; then
      continue
    fi
    case "$entry" in
      "$dir/.git") continue ;;
    esac
    rm -rf "$entry"
  done
}

list_relative_files() {
  dir=$1
  if [ ! -d "$dir" ]; then
    return 0
  fi
  (
    cd "$dir"
    find . -type f ! -path './.git/*' ! -name preview-version.txt | LC_ALL=C sort
  )
}

stage_matches_deploy() {
  stage=$1
  deploy=$2
  stage_files=$(list_relative_files "$stage")
  deploy_files=$(list_relative_files "$deploy")

  [ "$stage_files" = "$deploy_files" ] || return 1

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    cmp -s "$stage/$rel" "$deploy/$rel" || return 1
  done <<EOF
$stage_files
EOF
}

derive_target_repo() {
  source_repo=$("$GH" repo view --json nameWithOwner --jq .nameWithOwner)
  owner=${source_repo%/*}
  project=${source_repo##*/}
  printf '%s/%s-preview\n' "$owner" "$project"
}

derive_preview_url() {
  repo=$1
  if [ -n "${PREVIEW_URL:-}" ]; then
    printf '%s\n' "$PREVIEW_URL"
    return 0
  fi

  owner=${repo%/*}
  name=${repo##*/}
  printf 'https://%s.github.io/%s/\n' "$owner" "$name"
}

refresh_cached_clone() {
  deploy_dir=$1

  git -C "$deploy_dir" fetch -q origin main >/dev/null 2>&1 &&
    git -C "$deploy_dir" reset -q --hard FETCH_HEAD >/dev/null 2>&1 &&
    git -C "$deploy_dir" clean -fdq >/dev/null 2>&1
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
GH=${GH_BIN:-gh}
CURL=${CURL_BIN:-curl}
CREATE_PUBLIC=0

case "${1:-}" in
  --create-public)
    CREATE_PUBLIC=1
    shift
    ;;
esac

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage

APP_DIR=$(resolve_dir "$1") || {
  echo "APP_DIR_REQUIRED" >&2
  exit 1
}

TARGET_REPO=${2:-$(derive_target_repo)}
PAGES_URL=$(derive_preview_url "$TARGET_REPO")

"$SCRIPT_DIR/build-preview.sh" "$APP_DIR" >/dev/null

if ! repo_exists "$TARGET_REPO"; then
  if [ "$CREATE_PUBLIC" -ne 1 ]; then
    echo "NEW_PUBLIC_REPO_REQUIRED=$TARGET_REPO" >&2
    exit 3
  fi
  "$GH" repo create "$TARGET_REPO" --public >/dev/null
fi

ensure_pages_enabled "$TARGET_REPO"

DIST=$APP_DIR/.preview/.dist
DEPLOY=$APP_DIR/.preview/.deploy
EXPECTED_DEPLOY=$APP_DIR/.preview/.deploy
STAGE=

cleanup() {
  if [ -n "$STAGE" ] && [ -d "$STAGE" ]; then
    rm -rf "$STAGE"
  fi
}

trap cleanup EXIT HUP INT TERM

mkdir -p "$APP_DIR/.preview"

if [ -e "$DEPLOY/.git" ]; then
  if ! refresh_cached_clone "$DEPLOY"; then
    clone_repo "$TARGET_REPO" "$DEPLOY"
  fi
else
  clone_repo "$TARGET_REPO" "$DEPLOY"
fi

git -C "$DEPLOY" checkout -q -B main >/dev/null 2>&1 || true

STAGE=$(mktemp -d "$APP_DIR/.preview/.deploy-stage.XXXXXX")
copy_tree "$DIST" "$STAGE"
touch "$STAGE/.nojekyll"

EXISTING_MARKER=
if [ -f "$DEPLOY/preview-version.txt" ]; then
  EXISTING_MARKER=$(sed -n '1p' "$DEPLOY/preview-version.txt")
fi

if [ -n "$EXISTING_MARKER" ] && stage_matches_deploy "$STAGE" "$DEPLOY"; then
  printf 'PREVIEW_URL=%s\n' "$PAGES_URL"
  printf 'PREVIEW_VERSION=%s\n' "$EXISTING_MARKER"
  exit 0
fi

clean_deploy_dir "$DEPLOY" "$EXPECTED_DEPLOY"
copy_tree "$STAGE" "$DEPLOY"

HASH=$(shasum "$DIST/index.html" | awk '{print $1}')
MARKER="${HASH}-$(date +%s)"
printf '%s\n' "$MARKER" > "$DEPLOY/preview-version.txt"

git -C "$DEPLOY" config user.name >/dev/null 2>&1 || git -C "$DEPLOY" config user.name preview-bot
git -C "$DEPLOY" config user.email >/dev/null 2>&1 || git -C "$DEPLOY" config user.email preview-bot@example.com
git -C "$DEPLOY" add -A

if git -C "$DEPLOY" diff --cached --quiet; then
  printf 'PREVIEW_URL=%s\n' "$PAGES_URL"
  printf 'PREVIEW_VERSION=%s\n' "$MARKER"
  exit 0
fi

git -C "$DEPLOY" commit -qm "preview: update static sample"
git -C "$DEPLOY" push -q origin main >/dev/null

deadline=$(( $(date +%s) + 120 ))
poll_url=${PAGES_URL%/}/preview-version.txt?marker=$MARKER
while :; do
  current=$("$CURL" -fsSL "$poll_url" 2>/dev/null || true)
  if [ "$current" = "$MARKER" ]; then
    printf 'PREVIEW_URL=%s\n' "$PAGES_URL"
    printf 'PREVIEW_VERSION=%s\n' "$MARKER"
    exit 0
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "PREVIEW_POLL_TIMEOUT=$poll_url" >&2
    exit 1
  fi
  sleep 2
done
