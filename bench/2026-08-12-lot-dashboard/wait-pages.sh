#!/usr/bin/env bash
# Pages 첫 배포는 1~2분 걸린다. 200 이 뜰 때까지 기다린다.
URL=https://woobin-the-creator.github.io/claude-harness-preview/
for i in $(seq 1 12); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL")
  echo "시도 $i: HTTP $code"
  [ "$code" = "200" ] && exit 0
  sleep 20
done
exit 1
