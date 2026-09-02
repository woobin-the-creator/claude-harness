---
name: pr-demo-video
description: Record a demo of a web app feature working, then show it inline in the chat as an animated GIF and/or attach it to a GitHub PR. Covers Playwright browser recording (mocking HTTP/WebSocket so no full backend is needed), ffmpeg conversion to mp4 + GIF, frame-by-frame verification, delivering the GIF into the chat by Reading it, and the GitHub attach method. Use when the user asks to record/capture a demo or 시연, show a feature working as a video/GIF (in the chat or a PR), or attach a demo recording — keywords "데모 영상", "시연 녹화", "동영상/GIF 첨부", "채팅으로 영상/비디오 보여줘", "PR에 영상/비디오 올려", "녹화해서 보여줘/첨부해", "record a demo", "show it working as a video", "attach video/gif to PR".
---

# PR Demo Video

Record a feature working in the browser, then attach it to a GitHub PR as an **inline-playing GIF**.

## The one thing to know first (the gotcha)

GitHub only renders inline video/GIF in a PR/comment when the asset lives on its **`user-attachments` CDN** — and that upload happens **only via browser drag-drop / paste**. There is **no API or `gh` CLI endpoint** for it, so it cannot be fully automated that way.

**The automatable method that works:** commit a GIF into the repo and reference it by `raw.githubusercontent.com` URL in the PR body or comment. It renders inline for **public** repos. Check the repo for an existing convention first (e.g. `docs/demo/*.gif`) and follow it.

> Private repo? The raw URL won't render for viewers. Fall back to: tell the user to drag the file into the comment box (give them the file path + the comment URL), or make the repo's demo asset public another way.

## Show it in the chat (deliver as an animated "video")

The fastest way to **show a demo in the chat as a video** is to produce a **GIF** and `Read demo.gif` so the user sees it inline.

- Trim/lead the GIF with a meaningful frame (skip a blank loading state at the very start) since the first frame is what a static preview shows.
- For portable inline delivery, prefer GIF. An mp4 may not render in terminal clients.
- A single PNG frame `Read`s as a static image (good for one key moment); a tiled montage shows a storyboard. But for "like a video," use the **GIF**.
- **The final media rendering stays in the main session — never delegate it.** The whole point is that the *user* sees it. Verification in step 3 remains delegated.

This is the default when the user wants to *see* the demo here, not (or in addition to) attaching it to a PR.

## Workflow

1. **Record** the feature in a real browser with Playwright. Mock just the deps the component needs (HTTP routes, `routeWebSocket`) so you don't have to boot a full backend. Use the app's *real* code path. See [REFERENCE.md](REFERENCE.md) for a ready template. **By default, make the pointer legible:** inject a synthetic mouse cursor + click ripples (recordVideo captures no cursor otherwise) so viewers see where each click lands, and zoom into small targets (icon buttons, toggles) so they read clearly — both helpers are in REFERENCE.md ("Show the mouse cursor + click ripples", "Zoom to emphasize a small target").
2. **Convert** the `.webm` to `.mp4` (sharable) and a `.gif` (inline-renders) with ffmpeg + palette.
3. **Verify** before claiming success. Extract a first, middle, and final frame, then stack them into **one** image:

   ```bash
   <loaded skill dir>/scripts/contact-sheet.sh FIRST MIDDLE FINAL OUTPUT.png
   ```

   Resolve `scripts/contact-sheet.sh` to the loaded skill directory's **absolute path** before running it — the working directory when this skill fires is the user's repo, not `~/.claude/skills`, so a bare relative path resolves against the wrong directory. The helper preflights `ffmpeg`/`ffprobe` and the `hstack` filter, requires three equal-sized regular files (no symlinks), refuses to overwrite an existing output, accepts only a lowercase `.png` output, and re-validates the result as a single-frame, triple-width `png_pipe` still before publishing it. It fails closed and cleans its temp media.

   Hand **the contact sheet alone** to the `screenshot-verifier` agent — never the three separate frames — along with the shot list and what must be visible as text. It returns a text verdict. Confirm the feature is visible, not a blank/error page. Don't `Read` the sheet here: it is ~170k chars per frame's worth of pixels, and once it's in this session every later request re-pays for it. If stacking or verification fails, don't dispatch partial evidence or claim success.
4. **Attach**: commit the GIF (repo convention path), push, build the `raw.githubusercontent.com/<owner>/<repo>/<sha>/<path>` URL, and put `![desc](rawurl)` in a `gh pr comment`. Curl the raw URL for HTTP 200 to confirm it's reachable.
5. **Clean up** any temp recording script; verify `git status` only has intended changes.

## Quick commands

```bash
# convert webm -> mp4 + palette GIF
ffmpeg -i in.webm -movflags +faststart -pix_fmt yuv420p demo.mp4
ffmpeg -i in.webm -vf "fps=12,scale=1000:-1:flags=lanczos,palettegen" pal.png
ffmpeg -i in.webm -i pal.png -lavfi "fps=12,scale=1000:-1:flags=lanczos[x];[x][1:v]paletteuse" demo.gif

# extract three frames, then stack them into one sheet for the verifier
ffmpeg -ss 1  -i in.webm -frames:v 1 f1.png
ffmpeg -ss 4  -i in.webm -frames:v 1 f2.png
ffmpeg -sseof -1 -i in.webm -frames:v 1 f3.png
<loaded skill dir>/scripts/contact-sheet.sh f1.png f2.png f3.png sheet.png   # hand sheet.png to screenshot-verifier

# attach (public repo)
git add docs/demo/feature.gif && git commit -m "docs(demo): feature demo gif" && git push
SHA=$(git rev-parse HEAD)
RAW="https://raw.githubusercontent.com/<owner>/<repo>/$SHA/docs/demo/feature.gif"
curl -s -o /dev/null -w "%{http_code}\n" "$RAW"   # expect 200
gh pr comment <PR#> --body "![demo]($RAW)"
```

## Full Playwright recording template

HTTP + WebSocket mocking, `recordVideo`, timed interactions, and tooling notes (where to find Playwright if it's not a project dep, browser cache) are in [REFERENCE.md](REFERENCE.md).

## Pitfalls

- Don't claim it works without looking at frames — verify visually (step 3). Delegated looking still counts as looking; skipping it doesn't.
- `gh pr comment --edit-last` edits your most recent comment; use it to swap a placeholder for the real GIF.
- mp4 via a raw link does **not** inline-play — only GIF renders inline. Commit the GIF for the PR; keep the mp4 as the high-quality download.
- Remove temp `__*.mjs` recording scripts after; don't leave them in the worktree.
