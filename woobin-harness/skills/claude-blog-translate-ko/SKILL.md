---
name: claude-blog-translate-ko
description: >-
  Translate posts from the Claude blog (claude.com/blog) into self-contained Korean
  HTML — preserving every image, YouTube video, diagram, and hyperlink — and optionally
  publish them to a GitHub Pages site with a sticky sidebar for navigating between posts.
  Use this whenever the user wants a claude.com/blog article (or several, e.g. "all the
  hackathon posts from the last 6 months") turned into Korean, asks to "번역해서 받아보고
  싶다 / 한글로 번역한 html", wants to host translated Claude blog posts on the web, or
  asks to add another translated post to an existing translation site. Trigger even if
  they just paste a claude.com/blog URL and say they want to read it in Korean.
---

# Claude 블로그 한글 번역 (claude.com/blog → Korean HTML)

## What this does

Turn one or more claude.com/blog posts into clean, **self-contained** Korean HTML
pages — text faithfully translated, and every piece of original media (photos,
diagrams, YouTube videos) and every hyperlink carried over — then optionally deploy
them to a GitHub Pages site with a shared sticky sidebar so the reader can hop
between translated posts.

The hard part isn't the translation; it's not *losing* anything. Past runs lost
YouTube embeds (only `<img>` was checked, not `<iframe>`), pulled in unrelated
site-chrome images, and "confirmed" deploys that weren't actually live. The
workflow and bundled script below exist to prevent exactly those mistakes.

## When NOT to use

This is tuned to claude.com's Webflow markup (CDN paths, image class names). For a
different site the discovery and media-filtering heuristics may misfire — say so and
adapt rather than trusting the script's filtering blindly.

## Workflow

### 1. Identify the target post(s)

- Single post: the user gives a URL, or names a post. Good.
- A set ("all hackathon posts in the last 6 months", "everything about X"): discover them.
  - Fetch the blog index `https://claude.com/blog` and the relevant category page
    (e.g. `https://claude.com/blog/category/claude-code`) and grep for matching slugs.
  - Cross-check with `WebSearch` (`allowed_domains: ["claude.com"]`) so you don't miss any.
  - For each candidate, read `"datePublished"` from the page HTML and filter by the
    requested date window. Convert relative windows ("last 6 months") to an absolute
    cutoff before filtering.
  - List what you found (title + date) and proceed.

### 2. Fetch each post two ways

You need both the readable text and the raw markup:

- **Content**: `WebFetch` the post URL asking for the *full* article verbatim — title,
  date, every heading, paragraph, list, quote, and code block, in order. Explicitly
  say "do not summarize or omit." (WebFetch's markdown conversion drops media and some
  links — that's why you also need the raw HTML.)
- **Raw HTML**: `curl -sL "<url>" -o /tmp/<slug>.html` for media + link extraction.

### 3. Extract media + links (use the script)

Run the bundled extractor on the raw HTML:

```bash
python3 scripts/extract_media.py /tmp/<slug>.html
```

It returns JSON: `title`, `date_published`, `hero`, `content_images` (each with the
`<figcaption>` that followed it, in document order), `youtube` (embed URL + title),
`videos`, and candidate `links`. It already filters out site-chrome images
(placeholders, related-post cards, other posts' hero illos) and catches the
easy-to-miss YouTube `<iframe>` embeds. Skim the output and sanity-check it against
the article — heuristics aren't perfect.

### 4. Download the media (self-host, don't hotlink)

CDN URLs can change or block hotlinks, so pull every content image / hero into the
repo under `posts/assets/<slug>/`. Give files readable names (e.g. `tekton.jpg`,
`hooks.png`, `hero.svg`). YouTube videos are embedded by URL, not downloaded.

```bash
curl -sL "<cdn-url>" -o posts/assets/<slug>/<name> -w "%{http_code}\n"
```

### 5. Build the Korean HTML

Start from `assets/post-template.html` and fill it in:

- **Translate faithfully** — no summarizing, no dropping sections. Natural Korean,
  technical terms kept precise (often Korean + the English term in parentheses on
  first use). Translate figure captions too.
- **Place media where it belongs.** Put each content image as a `<figure>` under the
  section it illustrates, using the document order from the extractor. Embed each
  YouTube video with the responsive `<div class="video">` wrapper from the template,
  keeping any `?start=` parameter from the original embed URL.
- **Restore hyperlinks.** Re-create the inline body links AND links inside captions
  (these get stripped by WebFetch's text conversion — recover them from the extractor
  output / raw HTML). A caption like "the interactive timeline here" must stay linked.
- **Note interactive widgets.** Some diagrams are interactive on the original site and
  only capture as a static image. Translate the caption and note that the original is
  interactive, with a link to it.
- Use `<blockquote>` for pulled quotes and `<div class="callout">` for tip/best-practice boxes.

### 6. Wire it into the site

- Copy `assets/nav.css` and `assets/nav.js` into `posts/assets/` if not already there.
- Add **one** entry to the top of `window.CBK_POSTS` in `posts/assets/posts.js`
  (the single source of truth): `{ file, date, main: "Claude blog", cat: "<topic>",
  title, nav: "<short sidebar title>" }`. The index category chips, sidebar, and the
  per-post breadcrumb all read from posts.js — do NOT hand-edit `index.html` or a
  `POSTS` array in `nav.js` (those no longer exist; the site renders from posts.js).
- The post template already loads `assets/store.js`, `assets/posts.js`, then
  `assets/nav.js`, and links `assets/nav.css` — keep that order so the breadcrumb works.

The sidebar (from nav.css) is a fixed left column on wide screens and a **sticky**
top bar on narrow ones — sticky, not static, so it follows the reader on scroll. If
you ever change it, keep that property; a static bar that scrolls away is the bug we
already fixed.

### 7. Deploy + verify

Follow `references/deploy.md`. The critical gotcha: **poll the live URL for your new
content**, not the Pages build-status API (it reports the previous build and will lie
that you're done). Confirm the post and its media return `200`, and for the
JS-injected sidebar use a headless browser (curl won't show it).

## Output format

Per post: `posts/<slug>.html` (self-contained Korean translation) + downloaded media
in `posts/assets/<slug>/`, linked from `index.html` and the sidebar, served at
`https://<owner>.github.io/<repo>/posts/<slug>.html`.

## Bundled resources

- `scripts/extract_media.py` — pull title/date/images/captions/YouTube/videos/links
  from raw post HTML with claude.com-specific chrome filtering. Run it; don't
  re-derive the filtering by hand.
- `assets/post-template.html` — the post page skeleton (styles + structure + inline guidance).
- `assets/nav.css`, `assets/nav.js` — the shared sticky sidebar. Copy into the repo.
- `references/deploy.md` — GitHub Pages setup, routine deploy, the live-URL polling
  gotcha, headless verification, and the `index.html` template. Read when deploying.
