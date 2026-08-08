---
name: claude-youtube-to-blog
description: >-
  Turn a YouTube video (lecture, seminar, talk, demo) into a self-contained Korean
  HTML blog post for the claude-blog-kr site — understanding the actual video
  (slides, code, diagrams + speech) via Gemini, embedding extracted screenshots,
  paraphrasing in Korean with short verbatim quotes, and registering it in the
  site's single-source catalog (posts.js) so the category chips, sidebar, and
  breadcrumb pick it up automatically. Use whenever the user pastes a YouTube URL
  and wants it as a blog post / 한글 글로 정리, asks to "이 영상 블로그로 만들어줘",
  "유튜브 영상 포스트로", "세미나 영상 정리해서 올려줘", or "youtube video to blog post".
  Requires the yt-analysis MCP server (registered) + a GEMINI_API_KEY.
---

# YouTube 영상 → 한글 HTML 블로그 포스트

## What this does

Take one **public** YouTube URL and produce a clean Korean blog post under
`posts/<slug>.html` in the claude-blog-kr repo: faithful Korean write-up of what the
video actually says **and shows**, with key slides/code/diagrams embedded as
screenshots, short verbatim quotes for the speaker's important lines, and code blocks
reconstructed. Then it's wired into the site catalog so it appears in the index with
its source/topic category, in the sidebar, and gets a breadcrumb — all automatically.

The heavy multimodal work happens on Google's side (Gemini watches the URL); this
agent only receives **text summaries + screenshot file paths** and assembles HTML.
Frames are written to disk, never streamed into context (the MCP server is registered
with `SCREENSHOT_RETURN_BASE64=false`).

## Prerequisites (verify once)

- `yt-analysis` MCP server connected: `claude mcp list | grep yt-analysis` → ✔ Connected.
  If missing, see `references/pipeline.md` § Setup.
- `GEMINI_API_KEY` set on that server (AI Studio developer key; **not** an app subscription).
- `yt-dlp` + `ffmpeg` on PATH (used by the screenshot tools).
- Public video only. Private/unlisted won't work (Gemini can't fetch them).

## Architecture (decided — do not relitigate)

Gemini watches the URL and returns timestamped analysis (cheap, stays out of Claude's
context). ffmpeg (via the MCP server) extracts only the chosen frames to disk. Claude
assembles HTML from descriptions + file paths. The post integrates into the EXISTING
site template + `posts.js` single source — it is **not** a standalone inline-style
file. See `references/pipeline.md` for the full decision ledger and tool-surface facts.

## Workflow

### 1. Confirm scope + categories

- Get the YouTube URL. Confirm it's public.
- Decide the slug: a short ascii-kebab id (e.g. `cursor-rules-deep-dive`).
- Decide the two-level category (matches the site's taxonomy):
  - **main (출처)** = the source, channel-form, e.g. `Cursor Youtube`, `AI Explained`.
    Get the channel from the video; suggest `"<Channel> Youtube"` and confirm.
  - **cat (주제)** = the topic, e.g. `세미나`, `튜토리얼`, `Agents`. Reuse an existing
    topic from `posts/assets/posts.js` when it fits.

### 2. Check length → pick a strategy

Get the duration (the summary tool reports it, or `yt-dlp --get-duration <url>`).

- **≤ ~30 min**: process whole. One `summarize_video(detail_level:"detailed")`.
- **~40 min+**: split into 15–20 min windows to avoid "analysis truncation" (the video
  eating the context window). Ask `ask_about_video` for each window
  ("Summarize 00:00–20:00 in detail with timestamps…"), then merge. Prefer
  **default-resolution split** over low-res whole — slide/code text must stay legible.

### 3. Get the narrative (Gemini, via MCP)

- **Chapter skeleton first (deterministic).** `yt-dlp --dump-json <url> | jq .chapters`
  — if the video has creator-set chapters, they are the authoritative table of
  contents: the post must have a section per chapter (merging trivial neighbors is
  fine, silently dropping one is not).
- `summarize_video(youtube_url, detail_level:"detailed")` → timestamped breakdown.
  This is the spine of the post's `<h2>` sections.
- **Topic inventory (separate call, coverage insurance).** Summaries compress and can
  drop later topics — especially after the 40min+ window-merge. So also ask:
  `ask_about_video(youtube_url, "List EVERY distinct topic/section this video covers,
  in order, with MM:SS-MM:SS ranges. A bare checklist — no elaboration, no omissions;
  include short segments like anti-patterns, caveats, Q&A, and closing advice.")`
  Keep this list — step 5 gates on it.
- **Per-section detail checklist (the depth layer).** The global summary compresses:
  sub-points inside a covered topic (a warning, a gotcha, a number) silently vanish.
  So for EACH chapter/inventory topic, make one range-scoped call:
  `ask_about_video(youtube_url, "Between MM:SS and MM:SS, list EVERY distinct point
  the speaker makes — claims, tips, warnings, gotchas, numbers, examples, and asides
  with practical value. Flat checklist, one line each, no omissions.")`
  **Write each section from its own checklist**, not from the global summary (the
  summary is orientation only). If a video has 12+ topics, merge adjacent trivial
  ranges into one call — but never skip a range.
- For exact speaker quotes (there is **no** transcript tool), use
  `ask_about_video(youtube_url, "Quote verbatim, ≤15 words, what the speaker says
  about X around MM:SS")`. Keep direct quotes **≤ 15 words**; paraphrase the rest in
  Korean. Never reproduce long verbatim captions.

### 4. Extract screenshots (frames → disk)

- `extract_screenshots(youtube_url, count, focus, output_dir, resolution)`:
  - `output_dir` = `posts/assets/<slug>/` (absolute path).
  - `focus` = `"infographics, slides, code, diagrams, charts, on-screen graphics —
    NOT people, faces, or talking heads"`.
  - `count` ≤ **20 per call** (hard cap). For slide-heavy talks, prefer
    `get_video_timestamps` first to preview, then extract.
  - `resolution:"large"` (1080p) so slide/code text is readable.
- **Capture informational visuals, not people.** A frame earns its place only if a
  reader can study something in it (infographic, slide, code, chart, demo UI). Drop
  frames that are just speakers/hosts on camera. Podcast/interview-format videos may
  legitimately yield **zero** stills — a text-only post beats filler shots of people
  talking. Verify by Reading each frame before embedding.
- Missed a slide? Read its time from the summary and pull it precisely:
  `extract_frames(youtube_url, timestamps:[<seconds>], output_dir, resolution:"large")`.
  **Timestamps are in SECONDS** (e.g. `[252]` for 4:12), not MM:SS.
- The tool returns text lines `N. [MM:SS] <description> — Saved to: <path>`. You get
  paths + descriptions, no images. Map each frame to the section it illustrates.

### 4b. Animated graphics → short looping clips (mp4)

A still can't carry an animated infographic, motion diagram, or live demo. Capture
those as short clips instead (yt-dlp + ffmpeg are on PATH; no MCP tool for this):

1. Find the moments: `ask_about_video(youtube_url, "List moments where an animated
   infographic, motion diagram, animated chart, or on-screen demo is IN MOTION
   (not a static slide, not people talking). For each give start-end as MM:SS-MM:SS,
   max 15 seconds each, and one line on what the animation shows.")`
2. Extract each segment (keep clips **≤ 15s**, video-only, no audio):
   ```bash
   yt-dlp -f "bv*[height<=1080]" --download-sections "*<MM:SS>-<MM:SS>" \
     -o "/tmp/<slug>-clip%(autonumber)s.%(ext)s" "<youtube url>"
   ffmpeg -y -i /tmp/<slug>-clipNNNNN.* -an -vf "scale=960:-2" \
     -c:v libx264 -crf 28 -preset veryfast -movflags +faststart \
     posts/assets/<slug>/<descriptive-name>.mp4
   ```
3. Sanity-check each clip before embedding: duration/size (`ffprobe`; aim < 3 MB —
   raise `-crf` or trim if bigger) and that it actually shows the animation (extract
   one mid-clip frame with ffmpeg and Read it).
4. Embed with the `<video>` pattern in step 5 — mp4 loop behaves like a GIF at a
   fraction of the size, so prefer it over actual `.gif`.

### 5. Write the Korean post body

- Korean throughout, faithful to the video — no inventing. Technical terms: Korean +
  English in parens on first use.
- Structure (HTML fragment, fills the template's body slot):
  - Intro: 2–3 sentences on why the video matters.
  - `<h2>` per summary section + explanatory paragraphs.
  - Embed the relevant frame under its section. Every caption starts with the
    frame's timestamp **as a link into the original video at that moment**
    (`?t=<seconds>` — the seconds are already in the frame filename):
    ```html
    <figure>
      <img src="assets/<slug>/<frame>.jpg" alt="…">
      <figcaption><a href="https://youtu.be/<id>?t=1360" target="_blank">[22:40]</a> 설명</figcaption>
    </figure>
    ```
    (relative `assets/<slug>/…` path — never base64-inline).
  - Animated clip (from step 4b) under its section — same timestamped-link caption,
    pointing at the clip's start time:
    ```html
    <figure>
      <video autoplay loop muted playsinline preload="metadata" style="max-width:100%">
        <source src="assets/<slug>/<name>.mp4" type="video/mp4">
      </video>
      <figcaption><a href="https://youtu.be/<id>?t=<start-sec>" target="_blank">[MM:SS]</a> 설명</figcaption>
    </figure>
    ```
  - Speaker's key line: `<blockquote>` with the **English original (≤15 words)** then a
    Korean rendering below. (Quote guard — see step 3.)
  - Code shown on screen: reconstruct in `<pre><code>`.
  - Close with 3–5 핵심 takeaway as a `<ul>`.
- **Coverage gate (blocking — run before step 6), two levels:**
  - *Breadth*: line up the draft's `<h2>` list against BOTH the chapter skeleton and
    the topic inventory from step 3. Every inventory topic must be traceable to a
    section (or an explicit merge). Missing topic → `ask_about_video` that range and
    write the section.
  - *Depth*: for each section, walk its per-section detail checklist item by item —
    every point must appear in the section's text or be consciously dropped as truly
    trivial. **Practical warnings, gotchas, and cost/number claims are never
    droppable** (e.g. "switching models mid-conversation invalidates the entire
    prompt cache" is exactly the kind of aside this gate exists to save).
  - **A longer post is acceptable; a dropped topic or dropped gotcha is not.**
    Only then assemble.
- Save the fragment to `/tmp/<slug>-body.html`.
- **Archive the raw materials** to `posts/assets/<slug>/notes.md` (committed with the
  post; not linked from the site). Include: video URL/title/date, chapter list, the
  global summary, the topic inventory, every per-section detail checklist, and the
  extracted quotes. This is the reusable source — a later regeneration can work from
  notes.md without re-watching the video, and site-wide search/wiki batches get a
  denser input than the post itself.

### 6. Assemble + register (use the script)

```bash
python3 scripts/assemble_post.py \
  --repo ~/claude-blog-kr --slug <slug> \
  --title "<전체 한글 제목>" --nav "<짧은 사이드바 제목>" \
  --main "<출처>" --cat "<주제>" --date YYYY-MM-DD \
  --video-url "<youtube url>" --video-title "<원본 영상 제목>" \
  --body-file /tmp/<slug>-body.html
```

This fills `assets/post-template.html` → `posts/<slug>.html` AND inserts one entry at
the top of `window.CBK_POSTS` in `posts/assets/posts.js` (the single source). The
index chips, sidebar, and breadcrumb all read from posts.js, so **no other file needs
editing**. (Re-running with the same slug updates the entry instead of duplicating.)

Make sure the post loads `assets/posts.js` before `assets/nav.js` — the template
already does; nav.js injects the breadcrumb (`메인 › 서브 › 제목`) from posts.js.

### 7. Verify + deploy

- Frames present: `ls posts/assets/<slug>/` returns the jpgs the body references.
- Render check (sidebar + breadcrumb are JS-injected — curl won't show them). If
  Playwright is available, load `file://…/posts/<slug>.html` headless and assert
  `.post-crumb` and `#site-nav .nav-link` exist; also load `index.html` and assert the
  new `main` chip appears. (See the headless pattern in `references/pipeline.md`.)
- Deploy: commit the new post + `posts/assets/<slug>/` + `posts/assets/posts.js` on a
  branch, open a PR to `main` (Pages deploys from main). Do **not** push the API key —
  `.env`/`.env.*` are gitignored; keep it that way. After merge, poll the live URL for
  the new post (not the Pages build API).

## Output

`posts/<slug>.html` (Korean post on the existing template) + screenshots/clips and
`notes.md` (raw Gemini materials, reusable for regeneration) in `posts/assets/<slug>/`
+ one entry in `posts/assets/posts.js`, served at
`https://woobin-the-creator.github.io/claude-blog-kr/posts/<slug>.html`.

## Bundled resources

- `scripts/assemble_post.py` — fill the template + register in posts.js (idempotent by slug).
- `assets/post-template.html` — the post skeleton (matches the site; loads store.js +
  posts.js + nav.js; meta links the source video).
- `references/pipeline.md` — MCP tool surface (verified), length strategy, billing
  notes, MCP setup, decision ledger, headless-verify snippet.
- `assets/nav.css`, `assets/nav.js`, `assets/posts.js` — snapshots of the shared site
  assets for reference (the live ones live in the repo under `posts/assets/`).
