#!/usr/bin/env bash
# site/ 를 프리뷰 레포에 발행한다.
# 클론은 반드시 워크트리 안에 만든다 — /tmp 에 클론하면 git add 가 권한 분류기에 막힌다
# (show-design-sample §4, 2026-08-11 실측).
set -eux
BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE"

REPO=https://github.com/woobin-the-creator/claude-harness-preview.git

rm -rf .deploy
git clone --depth 1 "$REPO" .deploy

cp site/index.html site/X.html site/Y.html .deploy/
touch .deploy/.nojekyll

cd .deploy
git add -A
git -c user.name="정우빈" -c user.email="kodingjeong@gmail.com" \
    commit -m "preview: design-rules 블라인드 비교 — 랏 추적 대시보드"
git push origin HEAD:main
