#!/bin/sh
# Normalize Codex apply_patch hook input to Claude Code's tool_input.file_path shape.
# The shared downstream hooks stay host-neutral and retain one implementation.

set -u

target=${1:-}
[ -n "$target" ] && [ -x "$target" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$path" ]; then
  patch=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  path=$(printf '%s\n' "$patch" \
    | sed -nE 's/^\*\*\* (Add|Update|Delete) File: //p' \
    | grep -m1 'woobin-harness/' 2>/dev/null)
  if [ -z "$path" ]; then
    path=$(printf '%s\n' "$patch" \
      | sed -nE 's/^\*\*\* (Add|Update|Delete) File: //p' \
      | head -1)
  fi
fi

[ -n "$path" ] || exit 0
case "$path" in
  /*) ;;
  *)
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    [ -n "$cwd" ] || cwd=$(pwd)
    path="$cwd/$path"
    ;;
esac

normalized=$(printf '%s' "$input" | jq -c --arg path "$path" '.tool_input.file_path = $path' 2>/dev/null)
[ -n "$normalized" ] || exit 0
printf '%s' "$normalized" | "$target"
