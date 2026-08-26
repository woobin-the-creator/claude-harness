### Task 2: 데모 프레임 contact sheet

`pr-demo-video`는 지금 first/middle/final 프레임을 **각각** `screenshot-verifier`에 넘긴다. 스킬 본문(`SKILL.md:35`)이 스스로 적어 뒀듯 프레임 하나가 ~170k자다 — 3장이면 3배다. codex는 세 장을 ffmpeg `hstack`으로 가로로 이어 붙인 PNG **한 장**만 보내도록 바꿨고, 붙이는 과정 전체를 fail-closed 셸 스크립트로 감쌌다.

이 태스크는 그 스크립트를 그대로 가져오고 스킬 본문을 고친다. **이번 플랜에서 코드를 그대로 복사하는 유일한 항목이다** — 순수 POSIX `sh` + `ffmpeg`/`ffprobe`라 런타임 의존이 없다.

**Files:**
- Create: `woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh`
- Modify: `woobin-harness/skills/pr-demo-video/SKILL.md` (3번 단계 + Common gotchas 줄)
- Modify: `scripts/test-skills.sh` (fixture 추가)

**Interfaces:**
- Consumes: 없음
- Produces: `contact-sheet.sh FIRST MIDDLE FINAL OUTPUT.png` — 성공하면 `OUTPUT.png` 경로를 stdout에 한 줄 찍고 exit 0. 어떤 실패든 stderr에 `contact-sheet.sh: <이유>`를 찍고 non-zero. 인자 개수가 틀리면 exit 2.

---

- [ ] **Step 1: 스크립트를 가져온다**

원본은 codex-harness `origin/main`(`c1622ee19f14844184edbc29a71692b252f26f4f`)의 `plugins/woobin-codex-harness/skills/pr-demo-video/scripts/contact-sheet.sh`다. 이 머신의 클론 경로는 `/Volumes/LinuxVM/mac_wb_data/codespace/codex-harness`다.

```bash
mkdir -p woobin-harness/skills/pr-demo-video/scripts
git -C /Volumes/LinuxVM/mac_wb_data/codespace/codex-harness \
    show c1622ee19f14844184edbc29a71692b252f26f4f:plugins/woobin-codex-harness/skills/pr-demo-video/scripts/contact-sheet.sh \
  > woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh
chmod +x woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh
```

- [ ] **Step 2: 가져온 내용이 원본과 같은지 확인한다**

Run:
```bash
shasum -a 256 woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh
```
Expected: `435a5653210b90f8e8af808f75211565771f38d07d7c787b5d3314bb2048735b`

해시가 다르거나 클론이 없으면 **직접 쓰지 말고 멈춰라.** 이 스크립트의 값은 fail-closed 검사 순서 자체에 있어서 손으로 재현하면 그 값이 사라진다. 사용자에게 codex-harness 클론 경로를 물어라.

문법과 실행 권한을 확인한다:
```bash
sh -n woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh && test -x woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh && echo OK
```
Expected: `OK`

- [ ] **Step 3: 실패하는 fixture를 쓴다**

`scripts/test-skills.sh`의 explain 렌더러 블록(`# render.cjs needs project-provided Playwright ...`) **앞**에 추가한다. `ffmpeg`이 없는 머신에서는 건너뛰되 그 사실을 찍는다 — 조용히 통과하면 게이트가 죽은 걸 모른다.

```sh
# contact-sheet.sh: 3장을 가로로 이어 붙인 단일 PNG만 내보낸다.
sh -n "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" \
  || fail "contact-sheet.sh has a syntax error"
[ -x "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" ] \
  || fail "contact-sheet.sh is not executable"

if command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; then
  cs_dir="$TEST_ROOT/contact-sheet"
  mkdir -p "$cs_dir"
  for cs_n in 1 2 3; do
    ffmpeg -nostdin -hide_banner -loglevel error -y \
      -f lavfi -i "color=c=black:s=64x48:d=1" -frames:v 1 "$cs_dir/f$cs_n.png"
  done
  "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" \
    "$cs_dir/f1.png" "$cs_dir/f2.png" "$cs_dir/f3.png" "$cs_dir/out.png" >/dev/null \
    || fail "contact-sheet.sh failed on three equal-sized frames"
  cs_dim=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
             -of csv=p=0:s=x -i "$cs_dir/out.png")
  [ "$cs_dim" = "192x48" ] || fail "contact sheet is not triple-width: $cs_dim"

  # 기존 출력을 덮어쓰지 않는다.
  if "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" \
       "$cs_dir/f1.png" "$cs_dir/f2.png" "$cs_dir/f3.png" "$cs_dir/out.png" >/dev/null 2>&1; then
    fail "contact-sheet.sh overwrote an existing output"
  fi

  # .png 가 아닌 출력은 거부한다.
  if "$ROOT/woobin-harness/skills/pr-demo-video/scripts/contact-sheet.sh" \
       "$cs_dir/f1.png" "$cs_dir/f2.png" "$cs_dir/f3.png" "$cs_dir/out.mp4" >/dev/null 2>&1; then
    fail "contact-sheet.sh accepted a non-PNG output"
  fi
  pass "contact-sheet.sh stacks three frames and refuses unsafe outputs"
else
  printf 'ℹ contact-sheet.sh: ffmpeg/ffprobe unavailable; only syntax was checked.\n'
fi
```

`scripts/test-skills.sh` 상단에 `ROOT`·`TEST_ROOT`·`fail`·`pass`가 이미 정의돼 있는지 확인하고, 이름이 다르면 그 파일의 기존 관례를 따른다.

- [ ] **Step 4: 테스트를 돌린다**

Run: `./scripts/test-skills.sh`
Expected: PASS — `✓ contact-sheet.sh stacks three frames and refuses unsafe outputs` (또는 ffmpeg이 없으면 `ℹ` 줄)

- [ ] **Step 5: 스킬 본문을 고친다**

`woobin-harness/skills/pr-demo-video/SKILL.md`의 3번 단계를 바꾼다.

바꾸기 전(현재 `SKILL.md:35`):
```
3. **Verify** before claiming success: extract frames at key moments, then **delegate the looking to the `screenshot-verifier` agent** — hand it the frame paths plus what must be visible, and it returns a text verdict. Confirm the feature is visible, not a blank/error page. Don't `Read` the frames here: each one is ~170k chars, and once it's in this session every later request re-pays for it.
```

바꾼 뒤:
```
3. **Verify** before claiming success. Extract a first, middle, and final frame, then stack them into **one** image:

   ```bash
   scripts/contact-sheet.sh FIRST MIDDLE FINAL OUTPUT.png
   ```

   The helper preflights `ffmpeg`/`ffprobe` and the `hstack` filter, requires three equal-sized regular files (no symlinks), refuses to overwrite an existing output, accepts only a lowercase `.png` output, and re-validates the result as a single-frame, triple-width `png_pipe` still before publishing it. It fails closed and cleans its temp media.

   Hand **the contact sheet alone** to the `screenshot-verifier` agent — never the three separate frames — along with the shot list and what must be visible as text. It returns a text verdict. Confirm the feature is visible, not a blank/error page. Don't `Read` the sheet here: it is ~170k chars per frame's worth of pixels, and once it's in this session every later request re-pays for it. If stacking or verification fails, don't dispatch partial evidence or claim success.
```

같은 파일의 `# verify a frame` 예제 줄(`SKILL.md:47-48`)도 세 프레임을 뽑아 잇는 형태로 바꾼다:

```bash
# extract three frames, then stack them into one sheet for the verifier
ffmpeg -ss 1  -i in.webm -frames:v 1 f1.png
ffmpeg -ss 4  -i in.webm -frames:v 1 f2.png
ffmpeg -sseof -1 -i in.webm -frames:v 1 f3.png
scripts/contact-sheet.sh f1.png f2.png f3.png sheet.png   # hand sheet.png to screenshot-verifier
```

- [ ] **Step 6: 스킬 frontmatter가 여전히 파싱되는지 확인한다**

Run: `claude plugin validate ./woobin-harness`
Expected: 통과. (이 명령만이 YAML frontmatter 파싱 실패를 잡는다 — `description:` 안의 콜론+공백이 모든 필드를 조용히 날린다.)

- [ ] **Step 7: 커밋**

```bash
git add woobin-harness/skills/pr-demo-video scripts/test-skills.sh
git commit -m "perf(pr-demo-video): 검증 프레임 3장을 contact sheet 1장으로 합친다"
```
