#!/bin/sh
set -eu

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/show-design-deploy.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM

REPO_ROOT=$(git rev-parse --show-toplevel)
SCRIPT_ROOT=$REPO_ROOT/woobin-harness/skills/show-design-sample
DEPLOY=$SCRIPT_ROOT/scripts/deploy-preview.sh
REAL_GIT=$(command -v git)

make_fake_vite_app() {
  app_dir=$1
  body_text=$2
  mkdir -p "$app_dir/.preview" "$app_dir/node_modules/.bin"
  printf '%s\n' 'export default {}' > "$app_dir/.preview/vite.preview.config.ts"
  cat > "$app_dir/node_modules/.bin/vite" <<EOF
#!/bin/sh
set -eu
mode=\${1:-}
shift || true
case "\$mode" in
  build)
    mkdir -p "$app_dir/.preview/.dist/assets"
    cat > "$app_dir/.preview/.dist/index.html" <<'HTML'
<!doctype html>
<html>
  <body>
    <main>$body_text</main>
    <script type="module" src="./assets/app.js"></script>
  </body>
</html>
HTML
    printf '%s\n' 'console.log("asset ok")' > "$app_dir/.preview/.dist/assets/app.js"
    ;;
  preview)
    exit 0
    ;;
  *)
    exit 92
    ;;
esac
EOF
  chmod +x "$app_dir/node_modules/.bin/vite"
}

make_fake_gh() {
  gh_bin=$1
  cat > "$gh_bin" <<'EOF'
#!/bin/sh
set -eu
log=${FAKE_GH_LOG:?}
root=${FAKE_GH_ROOT:?}
printf '%s\n' "$*" >> "$log"

repo_path() {
  printf '%s/repos/%s.git\n' "$root" "$1"
}

ensure_repo_exists() {
  path=$(repo_path "$1")
  [ -d "$path" ]
}

command=${1:-}
shift || true

case "$command" in
  repo)
    sub=${1:-}
    shift || true
    case "$sub" in
      view)
        repo_arg=
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --json|--jq)
              shift 2
              ;;
            -*)
              shift
              ;;
            *)
              repo_arg=$1
              shift
              ;;
          esac
        done
        if [ -z "$repo_arg" ]; then
          printf '%s\n' "${FAKE_SOURCE_REPO:?}"
          exit 0
        fi
        ensure_repo_exists "$repo_arg" || exit 1
        printf '%s\n' "$repo_arg"
        ;;
      create)
        repo_arg=$1
        shift || true
        path=$(repo_path "$repo_arg")
        mkdir -p "$(dirname "$path")"
        git init --bare -q "$path"
        printf '0\n' > "$path.pages"
        ;;
      clone)
        repo_arg=$1
        dest=$2
        git clone -q "$(repo_path "$repo_arg")" "$dest"
        ;;
      *)
        echo "unsupported gh repo subcommand: $sub" >&2
        exit 90
        ;;
    esac
    ;;
  api)
    method=GET
    endpoint=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -X)
          method=$2
          shift 2
          ;;
        -f)
          shift 2
          ;;
        *)
          endpoint=$1
          shift
          ;;
      esac
    done
    repo_arg=${endpoint#repos/}
    repo_arg=${repo_arg%/pages}
    pages_flag="$(repo_path "$repo_arg").pages"
    case "$method" in
      GET)
        [ -f "$pages_flag" ] || exit 1
        [ "$(cat "$pages_flag")" = "1" ] || exit 1
        printf '%s\n' '{"status":"built"}'
        ;;
      POST)
        printf '1\n' > "$pages_flag"
        printf '%s\n' '{"status":"enabled"}'
        ;;
      *)
        echo "unsupported gh api method: $method" >&2
        exit 91
        ;;
    esac
    ;;
  *)
    echo "unsupported gh command: $command" >&2
    exit 89
    ;;
esac
EOF
  chmod +x "$gh_bin"
}

make_fake_curl() {
  curl_bin=$1
  cat > "$curl_bin" <<'EOF'
#!/bin/sh
set -eu
log=${FAKE_CURL_LOG:?}
state=${FAKE_CURL_STATE:?}
url=
for arg in "$@"; do
  case "$arg" in
    -*)
      ;;
    *)
      url=$arg
      ;;
  esac
done
printf '%s\n' "$url" >> "$log"
case "$url" in
  *preview-version.txt?marker=*)
    marker=${url##*marker=}
    count_file=$state/count
    count=0
    if [ -f "$count_file" ]; then
      count=$(cat "$count_file")
    fi
    count=$((count + 1))
    printf '%s\n' "$count" > "$count_file"
    if [ "$count" -eq 1 ]; then
      printf '%s\n' "${INITIAL_MARKER:-stale-marker}"
      printf '%s\n' "$marker" > "$state/current-marker"
    else
      cat "$state/current-marker"
    fi
    ;;
  *)
    printf '%s\n' '<!doctype html><title>ok</title>'
    ;;
esac
EOF
  chmod +x "$curl_bin"
}

make_git_wrapper() {
  wrapper_bin=$1
  cat > "$wrapper_bin" <<EOF
#!/bin/sh
set -eu
real_git=\${REAL_GIT:?}
target=\${FAIL_GIT_FETCH_FOR:-}
state_file=\${FAIL_GIT_FETCH_STATE:-}
case "\${2:-}" in
  *"\$target") target_match=1 ;;
  *) target_match=0 ;;
esac
if [ "\${1:-}" = "-C" ] && [ "\$target_match" = "1" ] && [ "\${3:-}" = "fetch" ] && [ -n "\$state_file" ] && [ -f "\$state_file" ]; then
  rm -f "\$state_file"
  exit 88
fi
exec "\$real_git" "\$@"
EOF
  chmod +x "$wrapper_bin"
}

seed_remote_repo() {
  slug=$1
  bare_dir=$2
  work_dir=$3
  initial_marker=$4
  mkdir -p "$(dirname "$bare_dir")"
  git init --bare -q "$bare_dir"
  git init -q "$work_dir"
  git -C "$work_dir" checkout -qb main
  mkdir -p "$work_dir/assets"
  printf '%s\n' '<!doctype html><script src="./assets/app.js"></script>' > "$work_dir/index.html"
  printf '%s\n' 'console.log("old")' > "$work_dir/assets/app.js"
  printf '%s\n' 'old-dotfile' > "$work_dir/.stale-dot"
  printf '%s\n' "$initial_marker" > "$work_dir/preview-version.txt"
  printf '%s\n' '' > "$work_dir/.nojekyll"
  git -C "$work_dir" add -A
  git -C "$work_dir" -c user.name=test -c user.email=test@example.com commit -qm baseline
  git -C "$work_dir" remote add origin "$bare_dir"
  git -C "$work_dir" push -q origin main
  rm -rf "$work_dir"
  printf '1\n' > "$bare_dir.pages"
}

checkout_remote_file() {
  bare_dir=$1
  rel=$2
  dest=$ROOT/inspect-$$
  rm -rf "$dest"
  git clone -q "$bare_dir" "$dest"
  git -C "$dest" checkout -q main
  cat "$dest/$rel"
  rm -rf "$dest"
}

remote_has_path() {
  bare_dir=$1
  rel=$2
  dest=$ROOT/inspect-$$
  rm -rf "$dest"
  git clone -q "$bare_dir" "$dest"
  git -C "$dest" checkout -q main
  test -e "$dest/$rel"
  result=$?
  rm -rf "$dest"
  return "$result"
}

remote_commit_count() {
  bare_dir=$1
  git --git-dir="$bare_dir" rev-list --count main
}

assert_eq() {
  expected=$1
  actual=$2
  label=$3
  if [ "$expected" != "$actual" ]; then
    echo "FAIL $label: expected=$expected actual=$actual" >&2
    exit 1
  fi
}

FAKE_GH_ROOT=$ROOT/fake-gh-root
FAKE_GH_LOG=$ROOT/fake-gh.log
FAKE_CURL_STATE=$ROOT/fake-curl-state
FAKE_CURL_LOG=$ROOT/fake-curl.log
FAKE_SOURCE_REPO=woobin/source-app
INITIAL_MARKER=stale-from-pages
export FAKE_GH_ROOT FAKE_GH_LOG FAKE_CURL_STATE FAKE_CURL_LOG FAKE_SOURCE_REPO INITIAL_MARKER
mkdir -p "$FAKE_GH_ROOT/repos" "$FAKE_CURL_STATE"
GH_BIN=$ROOT/fake-gh-bin
CURL_BIN=$ROOT/fake-curl
GIT_WRAPPER_DIR=$ROOT/git-wrapper
mkdir -p "$GIT_WRAPPER_DIR"
make_fake_gh "$GH_BIN"
make_fake_curl "$CURL_BIN"
make_git_wrapper "$GIT_WRAPPER_DIR/git"
export GH_BIN CURL_BIN REAL_GIT
PATH=$GIT_WRAPPER_DIR:$PATH
export PATH

APP=$ROOT/frontend
make_fake_vite_app "$APP" "changed-build-v1"
TARGET=octo/demo-preview
TARGET_BARE=$FAKE_GH_ROOT/repos/$TARGET.git
seed_remote_repo "$TARGET" "$TARGET_BARE" "$ROOT/seed-work" "oldhash-123"
PREVIEW_URL=https://octo.github.io/demo-preview/
export PREVIEW_URL

"$DEPLOY" "$APP" "$TARGET" >"$ROOT/deploy-first.out" 2>"$ROOT/deploy-first.err"
test ! -s "$ROOT/deploy-first.err"
test "$(wc -l < "$ROOT/deploy-first.out" | tr -d ' ')" -eq 2
grep -Fx "PREVIEW_URL=$PREVIEW_URL" "$ROOT/deploy-first.out"
marker_one=$(sed -n '2s/^PREVIEW_VERSION=//p' "$ROOT/deploy-first.out")
test -n "$marker_one"
grep -Eq '^[0-9a-f]+-[0-9]+$' <<EOF
$marker_one
EOF
remote_marker_one=$(checkout_remote_file "$TARGET_BARE" preview-version.txt)
assert_eq "$marker_one" "$remote_marker_one" "first marker pushed"
test ! -f "$APP/.preview/.deploy/.stale-dot"
test -f "$APP/.preview/.deploy/.nojekyll"
test -e "$APP/.preview/.deploy/.git"
if remote_has_path "$TARGET_BARE" .stale-dot; then
  echo "expected stale dotfile removal" >&2
  exit 1
fi
clone_count_before=$(grep -c '^repo clone octo/demo-preview ' "$FAKE_GH_LOG")
curl_polls=$(grep -c 'preview-version.txt?marker=' "$FAKE_CURL_LOG")
test "$curl_polls" -ge 2
test "$(grep -c 'index.html' "$FAKE_CURL_LOG" || true)" -eq 0
commit_count_after_first=$(remote_commit_count "$TARGET_BARE")

FAIL_GIT_FETCH_FOR=/.preview/.deploy
FAIL_GIT_FETCH_STATE=$ROOT/fail-fetch-once
printf '%s\n' '1' > "$FAIL_GIT_FETCH_STATE"
export FAIL_GIT_FETCH_FOR FAIL_GIT_FETCH_STATE
printf '%s\n' 'should disappear' > "$APP/.preview/.deploy/.leaked-dot"
printf '0\n' > "$FAKE_CURL_STATE/count"
"$DEPLOY" "$APP" "$TARGET" >"$ROOT/deploy-second.out" 2>"$ROOT/deploy-second.err"
test ! -s "$ROOT/deploy-second.err"
test "$(wc -l < "$ROOT/deploy-second.out" | tr -d ' ')" -eq 2
marker_two=$(sed -n '2s/^PREVIEW_VERSION=//p' "$ROOT/deploy-second.out")
assert_eq "$marker_one" "$marker_two" "unchanged marker reused"
clone_count_after=$(grep -c '^repo clone octo/demo-preview ' "$FAKE_GH_LOG")
test "$clone_count_after" -gt "$clone_count_before"
test ! -f "$APP/.preview/.deploy/.leaked-dot"
commit_count_after_second=$(remote_commit_count "$TARGET_BARE")
assert_eq "$commit_count_after_first" "$commit_count_after_second" "unchanged build skipped commit"
commit_count_before_change=$(remote_commit_count "$TARGET_BARE")

make_fake_vite_app "$APP" "changed-build-v2"
printf '0\n' > "$FAKE_CURL_STATE/count"
"$DEPLOY" "$APP" "$TARGET" >"$ROOT/deploy-third.out" 2>"$ROOT/deploy-third.err"
test ! -s "$ROOT/deploy-third.err"
test "$(wc -l < "$ROOT/deploy-third.out" | tr -d ' ')" -eq 2
marker_three=$(sed -n '2s/^PREVIEW_VERSION=//p' "$ROOT/deploy-third.out")
test "$marker_three" != "$marker_two"
commit_count_after_change=$(remote_commit_count "$TARGET_BARE")
test "$commit_count_after_change" -gt "$commit_count_before_change"
remote_marker_three=$(checkout_remote_file "$TARGET_BARE" preview-version.txt)
assert_eq "$marker_three" "$remote_marker_three" "changed marker pushed"

MISSING_APP=$ROOT/missing-app
make_fake_vite_app "$MISSING_APP" "new-app-build"
if "$DEPLOY" "$MISSING_APP" octo/new-preview >"$ROOT/missing.out" 2>"$ROOT/missing.err"; then
  echo "expected missing target failure" >&2
  exit 1
fi
grep -Fx 'NEW_PUBLIC_REPO_REQUIRED=octo/new-preview' "$ROOT/missing.err"
test "$(grep -c '^repo create octo/new-preview ' "$FAKE_GH_LOG" || true)" -eq 0

printf '0\n' > "$FAKE_CURL_STATE/count"
PREVIEW_URL=https://octo.github.io/new-preview/
export PREVIEW_URL
"$DEPLOY" --create-public "$MISSING_APP" octo/new-preview >"$ROOT/create.out" 2>"$ROOT/create.err"
test ! -s "$ROOT/create.err"
test "$(wc -l < "$ROOT/create.out" | tr -d ' ')" -eq 2
grep -Fx 'PREVIEW_URL=https://octo.github.io/new-preview/' "$ROOT/create.out"
created_marker=$(sed -n '2s/^PREVIEW_VERSION=//p' "$ROOT/create.out")
test -n "$created_marker"
test -d "$FAKE_GH_ROOT/repos/octo/new-preview.git"
test "$(cat "$FAKE_GH_ROOT/repos/octo/new-preview.git.pages")" = "1"

echo ALL-OK
