# Pipeline reference — yt-analysis MCP, strategy, setup

Verified facts from inspecting `Legorobotdude/yt-analysis-mcp` (cloned at
`~/codespace/yt-analysis-mcp`) + smoke tests on 2026-06-25. Where this differs from
the original design handoff, the verified column wins.

## MCP tool surface (actual)

| Tool | Signature | Notes |
|---|---|---|
| `summarize_video` | `(youtube_url, detail_level: "brief"\|"medium"\|"detailed")` | `detailed` = timestamped breakdown. The post's section spine. |
| `ask_about_video` | `(youtube_url, question)` | Use for **exact quotes** (no transcript tool exists). Ask for ≤15-word verbatim. |
| `get_video_timestamps` | `(youtube_url, count≤20, focus)` | Preview important moments WITHOUT extracting. Cheap; use before a big extract. |
| `extract_screenshots` | `(youtube_url, count≤20, focus, output_dir, resolution)` | AI picks moments → ffmpeg to disk. `resolution:"large"` (1080p) for legible slides. |
| `extract_frames` | `(youtube_url, timestamps:[seconds], output_dir, resolution)` | **Timestamps in SECONDS** (4:12 → `252`). For precise re-pulls. |

Deltas from the handoff: tools are `*_video` named; **no `get_transcript`**, **no
`search`**; `extract_frames` takes **seconds not MM:SS**; **max 20 frames per call**.

### Token economy (important)

`extract_screenshots`/`extract_frames` natively return base64 images **and** save to
disk. The server is registered with `SCREENSHOT_RETURN_BASE64=false` (a local patch to
`src/index.ts`) so the MCP response carries only **text (paths + descriptions)** — the
agent never ingests image tokens. This is what keeps architecture "A" cheap. If you
re-clone/rebuild the server, re-apply that patch (gate the `// Add images` loops on
`process.env.SCREENSHOT_RETURN_BASE64 !== "false"`) and `npm run build`.

Frames go to disk at full resolution regardless; only the *response* drops base64.

## Length strategy

Get duration from `summarize_video` output or `yt-dlp --get-duration <url>`.

| Length | Approach |
|---|---|
| ≤ ~30 min | Whole video, one `summarize_video(detail_level:"detailed")`. |
| ~40–50 min+ | Split into 15–20 min windows via `ask_about_video` ("…summarize 20:00–40:00 in detail with timestamps"), then merge. |

Avoid low-resolution whole-video passes for lectures — slide/code text becomes
illegible. Prefer **default-resolution split**. The risk in long whole-video passes is
"analysis truncation": the video occupies most of the context window, so scattered
details get dropped.

## Billing / model

- Key = **AI Studio developer key** (`GEMINI_API_KEY`), separate from any Gemini app
  subscription. Free tier (Flash/Flash-Lite) is enough for video.
- Default model `gemini-3-flash-preview` (override with `GEMINI_MODEL`). ~50-min video
  ≈ a few cents on Flash-Lite. Public videos only.
- Rate limits: Flash RPD ~1,500; on 429 back off and space split calls out.

## MCP setup (if not already connected)

```bash
cd ~/codespace
git clone https://github.com/Legorobotdude/yt-analysis-mcp.git   # if missing
cd yt-analysis-mcp && npm install && npm run build
# re-apply the base64 patch if this is a fresh clone (see Token economy above), rebuild

# register (name FIRST — -e is variadic and will otherwise eat the name)
KEY=$(grep -E '^GEMINI_API_KEY=' ~/claude-blog-kr/.env | cut -d= -f2- | tr -d '"'"'"' ')
claude mcp add yt-analysis -s user \
  -e GEMINI_API_KEY="$KEY" -e SCREENSHOT_RETURN_BASE64=false \
  -- node ~/codespace/yt-analysis-mcp/dist/index.js
claude mcp list | grep yt-analysis     # expect ✔ Connected
```

`-s user` = global; new MCP tools appear **after a Claude Code session restart**.

## Headless verify snippet (post + index)

Playwright lives at `~/codespace/pholex/node_modules`; use system Chrome channel.

```js
// NODE_PATH=~/codespace/pholex/node_modules node check.cjs
const { chromium } = require('playwright');
const base = 'file://' + process.env.HOME + '/claude-blog-kr';
(async () => {
  const b = await chromium.launch({channel:'chrome'});
  const pg = await b.newPage();
  await pg.goto(base + '/posts/<slug>.html'); await pg.waitForTimeout(150);
  console.log('crumb:', await pg.$eval('.post-crumb', e=>e.textContent.replace(/\s+/g,' ').trim()));
  console.log('sidebar:', await pg.$$eval('#site-nav .nav-link', e=>e.length));
  await pg.goto(base + '/index.html'); await pg.waitForTimeout(150);
  console.log('main chips:', await pg.$$eval('#cat-main .chip', e=>e.map(x=>x.textContent)));
  await b.close();
})();
```

## Decision ledger (grill, 2026-06-25 — do not relitigate)

- Integrate into existing `claude-blog-kr` (not a standalone tool).
- Architecture A: Gemini watches the URL; frames extracted to disk; no full download to context.
- MCP: `yt-analysis-mcp` (discrete tools, control over frame timing).
- Korean body; key quotes = English original ≤15 words + Korean rendering.
- Taxonomy: 2-level — `main` (출처, e.g. "Cursor Youtube") + `cat` (주제). Single source = posts.js.
- On-demand skill, single URL (you pick which videos are worth a post). Batch deferred.
