#!/bin/bash

set -u

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$command" ] || exit 0

dangerous_patterns=(
  '(^|[;&|][[:space:]]*)git[[:space:]]+push([[:space:]]|$)'
  '(^|[;&|][[:space:]]*)git[[:space:]]+reset[[:space:]]+--hard([[:space:]]|$)'
  '(^|[;&|][[:space:]]*)git[[:space:]]+clean[[:space:]]+[^;&|]*-f'
  '(^|[;&|][[:space:]]*)git[[:space:]]+branch[[:space:]]+[^;&|]*-D([[:space:]]|$)'
  '(^|[;&|][[:space:]]*)git[[:space:]]+checkout[[:space:]]+\.([[:space:]]|$)'
  '(^|[;&|][[:space:]]*)git[[:space:]]+restore[[:space:]]+\.([[:space:]]|$)'
)

for pattern in "${dangerous_patterns[@]}"; do
  if printf '%s' "$command" | grep -qE -- "$pattern"; then
    printf "BLOCKED: '%s' matches a Git command disabled by the user's Codex hook.\n" "$command" >&2
    exit 2
  fi
done

exit 0
