# PR Demo Video — Reference

## Playwright recording template (mock deps, no full backend)

Record the app's **real code path**, mocking only the network it depends on. This example mocks REST (`page.route`) and a WebSocket (`page.routeWebSocket`) — drop whichever you don't need.

```js
// __demo_record.mjs  (temp; delete after running)
import pw from 'playwright'           // see "Finding Playwright" if this fails
const { chromium } = pw

const BASE = 'http://localhost:5173/'
const VIDEO_DIR = '/tmp/demo-video'
const pause = (ms) => new Promise((r) => setTimeout(r, ms))

const browser = await chromium.launch()                 // headless is fine for video
const context = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  recordVideo: { dir: VIDEO_DIR, size: { width: 1440, height: 900 } },
})
const page = await context.newPage()

// --- mock REST so the app renders without a backend ---
await page.route('**/api/auth/session', (r) =>
  r.fulfill({ status: 200, contentType: 'application/json',
    body: JSON.stringify({ authenticated: true, user: { id: 1, username: 'demo' } }) }))
await page.route('**/api/some/data**', (r) =>
  r.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ rows: [] }) }))

// --- mock a WebSocket and act as the server, so you can inject events on a timeline ---
let wsResolve; const wsReady = new Promise((res) => (wsResolve = res))
await page.routeWebSocket('**/ws', (ws) => {
  ws.onMessage(() => {})        // ignore client subscribe/etc.
  wsResolve(ws)
})
const sendWs = async (obj) => (await wsReady).send(JSON.stringify(obj))

await page.goto(BASE)
await page.getByText('SOME-ANCHOR-TEXT').first().waitFor({ timeout: 15000 })  // wait for render
await pause(1500)

// --- drive the demo with pauses so the video is watchable ---
await sendWs({ type: 'alert', payload: { /* ... */ } })   // trigger a feature event
await pause(3500)
await page.getByRole('button', { name: /열기|open/ }).click()
await pause(2500)

const video = page.video()
await page.close()
await context.close()
console.log('VIDEO_PATH=' + (await video.path()))
await browser.close()
```

Run it from the frontend dir (so module/browser resolution works), with the dev server already up:

```bash
npm run dev > /tmp/dev.log 2>&1 &     # start app; read log for the port
rm -rf /tmp/demo-video && node __demo_record.mjs
```

### Notes on the mocking approach
- Mock at the boundary the component actually calls. If the app has a `VITE_DEMO_MODE`/offline flag, check whether it *disables* the very transport you need (e.g. demo mode that skips the WebSocket) — if so, run the normal path and mock instead.
- `routeWebSocket` handler with no `connectToServer()` makes you the server: handle `ws.onMessage` for client→server, call `ws.send()` for server→client. Resolve the route object out to an outer variable to send on a timeline.
- Register all routes **before** `page.goto` so the first connections are intercepted.

## Timing traps that cost a re-record

Two failure modes that only show up *after* you have recorded, converted, and looked at the frames. Bake both in before the first take.

- **Make any animated transition ≥400ms.** At a 10fps capture a 320ms transition lands as a single-frame jump — the viewer sees the end state teleport in, not the motion you are trying to demo. If the app's real transition is shorter, override it for the recording rather than re-recording at a higher frame rate.
- **`await page.evaluate(() => document.fonts.ready)` before the first capture.** If an icon font has not loaded yet, its ligatures render as literal words (`unfold_more` instead of the caret glyph) and the whole take is unusable. This is separate from trimming the lead-in: the fonts can still be pending after the page is otherwise interactive.

## Show the mouse cursor + click ripples (do this by default)

`recordVideo` does **not** capture a mouse cursor — headless Chromium has none, so raw recordings look like elements activate by themselves. Inject a synthetic cursor + a click ripple so viewers can follow *where* the pointer goes and *what* gets clicked. This should be the default for any click-driven demo.

Register this via `addInitScript` (runs before page scripts on every navigation), then drive it from small helpers:

```js
// Inject a fake cursor + ripple API on every page (call once, before goto)
async function installCursor(page) {
  await page.addInitScript(() => {
    const ensure = () => {
      let c = document.getElementById('__demo_cursor')
      if (!c) {
        c = document.createElement('div')
        c.id = '__demo_cursor'
        c.style.cssText =
          'position:fixed;left:0;top:0;width:24px;height:24px;z-index:2147483647;' +
          'pointer-events:none;transform:translate(-3px,-3px);transition:left .12s linear,top .12s linear;'
        c.innerHTML =
          '<svg width="24" height="24" viewBox="0 0 24 24" fill="none">' +
          '<path d="M5 3l14 7-6 1.5L10 18 5 3z" fill="#111" stroke="#fff" stroke-width="1.3" stroke-linejoin="round"/></svg>'
        ;(document.body || document.documentElement).appendChild(c)
      }
      return c
    }
    window.__moveCursor = (x, y) => { const c = ensure(); c.style.left = x + 'px'; c.style.top = y + 'px' }
    window.__clickRipple = (x, y) => {
      ensure()
      const r = document.createElement('div')
      // Bold + high-contrast so it reads on both light and dark backgrounds:
      // solid-ish fill, thick dark-blue ring, and a drop shadow to lift it off the page.
      r.style.cssText =
        `position:fixed;left:${x}px;top:${y}px;width:18px;height:18px;border-radius:50%;` +
        'background:rgba(0,117,222,0.65);border:3px solid #005bab;' +
        'box-shadow:0 0 0 2px rgba(255,255,255,0.55),0 2px 10px rgba(0,0,0,0.35);' +
        'transform:translate(-50%,-50%) scale(0.4);z-index:2147483646;pointer-events:none;' +
        'transition:transform .6s ease-out,opacity .6s ease-out;opacity:1;'
      ;(document.body || document.documentElement).appendChild(r)
      // CRITICAL: force a reflow so the browser paints the initial state before the
      // change below — otherwise both styles coalesce into one frame, the transition
      // never plays, and the ripple is invisible (jumps straight to opacity 0).
      void r.offsetWidth
      // Grow to ~2.6× (not 3×) so the ring stays dense rather than thinning out,
      // and hold opacity high until late in the fade so the click reads clearly.
      r.style.transform = 'translate(-50%,-50%) scale(2.6)'
      r.style.opacity = '0'
      setTimeout(() => r.remove(), 660)
    }
  })
}

const pause = (ms) => new Promise((r) => setTimeout(r, ms))

// Move the fake cursor to a point (and let the eye catch up)
async function cursorTo(page, x, y) {
  await page.evaluate(([x, y]) => window.__moveCursor(x, y), [x, y])
  await pause(200)
}

// Move → ripple → click a locator. Cursor/ripple are visual; the click is real.
// Falls back to dispatchEvent when actionability blocks a real click (dropdowns,
// overlay-intercepted targets) so the handler still fires under the ripple.
async function demoClick(page, locator) {
  const b = await locator.boundingBox()
  const x = b.x + b.width / 2, y = b.y + b.height / 2
  await cursorTo(page, x, y)
  await pause(220)
  await page.evaluate(([x, y]) => window.__clickRipple(x, y), [x, y])
  await pause(140)
  try { await locator.click({ timeout: 2500 }) }
  catch { await locator.dispatchEvent('click') }
  await pause(120)
}
```

Usage: `await installCursor(page)` before `page.goto`, then replace every `locator.click()` with `await demoClick(page, locator)`. The cursor glides to each target and a ripple fires at the exact click point.

## Zoom to emphasize a small target

When the thing you're demoing is small (an icon button, a toggle), zoom into it so viewers can see it. Two ways:

- **Element transform (preferred, precise):** scale the specific element with a CSS transform during the recording. Reliable, no post-processing, and layout-local. Set `overflow:visible` on a clipping ancestor (e.g. a modal) so the enlarged element isn't cut off.

```js
// Zoom a single element in/out during recording. scale=1 restores.
async function zoomEl(page, selector, scale, origin = 'right top') {
  await page.evaluate(({ selector, scale, origin }) => {
    const el = document.querySelector(selector); if (!el) return
    el.style.transition = 'transform .48s cubic-bezier(.22,1,.36,1)'
    el.style.transformOrigin = origin
    el.style.transform = `scale(${scale})`
    if (scale > 1) { el.style.zIndex = '999'; el.style.boxShadow = '0 12px 40px rgba(0,0,0,.28)' }
    const clip = el.closest('[class*="modal"]'); if (clip) clip.style.overflow = scale > 1 ? 'visible' : ''
  }, { selector, scale, origin })
}
// e.g. await zoomEl(page, '.kw-presetmenu', 1.9)  // emphasize; ... ; await zoomEl(page, '.kw-presetmenu', 1)
```

- **ffmpeg `zoompan` (post-process):** a Ken-Burns zoom over the whole frame. Harder to time precisely against interactions; prefer the element transform unless you need a full-frame zoom. If you do use it, upscale first for smooth zoom: `scale=2*iw:-1,zoompan=z='...':x='...':y='...':d=1:s=WxH:fps=F`.

## Finding Playwright if it isn't a project dependency

`import 'playwright'` fails when it's not in the project. Options:
- It's often in the npx cache: `find ~/.npm/_npx -maxdepth 3 -name playwright -type d`. Import the absolute path; it's CommonJS, so `import pw from '<abs>/index.js'; const { chromium } = pw`.
- Or use the global `@playwright/test` / `playwright` if installed (`npm root -g`).
- Browsers live in `~/Library/Caches/ms-playwright` (macOS); if missing, `npx playwright install chromium`.

## ffmpeg recipes

```bash
# mp4 (faststart for web playback)
ffmpeg -i in.webm -movflags +faststart -pix_fmt yuv420p demo.mp4

# high-quality GIF via 2-pass palette (smaller + cleaner than 1-pass)
ffmpeg -i in.webm -vf "fps=12,scale=1000:-1:flags=lanczos,palettegen" /tmp/pal.png
ffmpeg -i in.webm -i /tmp/pal.png \
  -lavfi "fps=12,scale=1000:-1:flags=lanczos[x];[x][1:v]paletteuse" demo.gif
```
- Shrink GIF: lower `fps` (10) and `scale` (800). Keep PR GIFs roughly under a few MB.
- `ffprobe -v error -show_entries format=duration -of csv=p=0 in.webm` for duration.

## Verify with frames (don't skip)

```bash
for t in 2 4 8 12; do ffmpeg -v error -ss $t -i in.webm -frames:v 1 frame_$t.png -y; done
```

Then hand the whole set to the **`screenshot-verifier` agent** in one dispatch — give it the
glob plus what must be visible at each mark, and it returns one verdict per frame. Do not
`Read` them here: four frames is ~700k chars, and this session re-pays for all of it on every
request that follows.

## Attaching to the PR

```bash
mkdir -p docs/demo && cp demo.gif docs/demo/feature-demo.gif
git add docs/demo/feature-demo.gif
git commit -m "docs(demo): <feature> 동작 시연 GIF (PR 코멘트용)"
git push
SHA=$(git rev-parse HEAD)
RAW="https://raw.githubusercontent.com/<owner>/<repo>/$SHA/docs/demo/feature-demo.gif"
curl -s -o /dev/null -w "%{http_code} %{size_download}\n" "$RAW"   # want 200

cat > /tmp/c.md <<EOF
## 🎥 동작 시연

![demo]($RAW)

1. … 2. … 3. …
EOF
gh pr comment <PR#> --body-file /tmp/c.md          # or --edit-last to replace a placeholder
```

Pin the URL to the commit **SHA** (not a branch name) so it never breaks if the branch moves.

## Decision table

| Situation | Inline render? | What to do |
|---|---|---|
| Show demo in the chat | ✅ as animated GIF | `Read` the GIF — it plays for the user. mp4 can't be Read (binary). |
| Public repo PR | ✅ | Commit GIF + raw URL (this skill) |
| Private repo PR | ❌ raw won't render | Ask user to drag the file into the comment box; give file path + comment URL |
| True video player inline in a PR | only via CDN | Browser drag-drop only — cannot be done by API/CLI |
