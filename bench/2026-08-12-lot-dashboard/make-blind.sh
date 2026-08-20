#!/usr/bin/env bash
# 두 팔을 X / Y 로 무작위 배정한다. 정답(.mapping.json)은 로컬에만 두고 사이트에 올리지 않는다.
set -eu
BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE"

mkdir -p blind site

if [ $((RANDOM % 2)) -eq 0 ]; then
  X_ARM=no-skill;   Y_ARM=with-skill
else
  X_ARM=with-skill; Y_ARM=no-skill
fi

cp "$X_ARM/index.html" blind/X.html
cp "$Y_ARM/index.html" blind/Y.html
printf '{"X":"%s","Y":"%s"}\n' "$X_ARM" "$Y_ARM" > .mapping.json

# 파일 크기가 어느 팔인지 알려주면 블라인드가 아니다 — 큰 쪽에 맞춰 주석으로 패딩한다.
python3 - <<'PY'
import pathlib
xs = pathlib.Path('blind/X.html'); ys = pathlib.Path('blind/Y.html')
bx, by = xs.read_bytes(), ys.read_bytes()
target = max(len(bx), len(by))
for path, data in ((xs, bx), (ys, by)):
    gap = target - len(data)
    if gap:
        path.write_bytes(data + b'\n<!--' + b'x' * max(0, gap - 8) + b'-->')
print('패딩 후 크기:', len(xs.read_bytes()), len(ys.read_bytes()))
PY

cp blind/X.html site/X.html
cp blind/Y.html site/Y.html

echo "배정 완료 — 정답은 $BASE/.mapping.json (사이트 미포함)"
