# Hosting on GitHub Pages

This is the deploy half of the skill: take the generated HTML and serve it at a public
URL so the user can read it anywhere. Skip this whole file if the user only wants local HTML.

## Repository layout

```
<repo>/
├── index.html                 # landing page: lists all translated posts
└── posts/
    ├── <slug>.html            # one file per translated post
    └── assets/
        ├── nav.css            # shared sidebar styles
        ├── nav.js             # shared sidebar (POSTS array lives here)
        └── <slug>/            # one folder per post for its downloaded media
            ├── hero.svg
            └── ...
```

Per-post media goes in its own `assets/<slug>/` folder so posts never collide.

## First-time setup (only if the repo doesn't exist yet)

1. Confirm the GitHub account: `gh auth status`
2. Create the working dir, copy in `assets/nav.css` and `assets/nav.js` from this skill,
   write `index.html` (see template below).
3. Commit, then create a **public** repo and push (free Pages needs public):
   ```bash
   gh repo create <name> --public --source=. --remote=origin --push
   ```
4. Enable Pages on the main branch root:
   ```bash
   gh api -X POST repos/<owner>/<name>/pages -f 'source[branch]=main' -f 'source[path]=/'
   ```
   The page URL is `https://<owner>.github.io/<name>/`.

## Routine deploy (repo already exists)

```bash
git add -A && git commit -m "Add Korean translation of <post>" && git push origin main
```

## Verifying the deploy — IMPORTANT GOTCHA

Do **not** trust the build-status API to know when your change is live. The
`repos/<owner>/<name>/pages/builds/latest` endpoint often returns `built`
immediately because it's reporting the *previous* build, not the one your push
just triggered. If you poll that, you'll "confirm" success before the new content
is actually served.

Instead, **poll the live URL for your new content** until it appears:

```bash
base="https://<owner>.github.io/<name>"
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$base/posts/<slug>.html")
  echo "poll $i: $code"; [ "$code" = "200" ] && break; sleep 8
done
# then confirm media resolves too:
curl -s -o /dev/null -w "%{http_code}\n" "$base/posts/assets/<slug>/hero.svg"
```

For client-side rendered pieces (the sidebar is injected by nav.js), `curl` shows
only static HTML — the sidebar won't appear in curl output even when it's working.
Verify those with a headless browser instead (see "Visual check" below).

## Visual check with headless Chrome (optional but recommended)

The sidebar and responsive layout are worth eyeballing across widths. macOS Chrome:

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --disable-gpu --window-size=1400,900 \
  --screenshot=/tmp/check.png "https://<owner>.github.io/<name>/posts/<slug>.html"
```

If Playwright (`channel: 'chrome'`) is available, prefer it — you can set the
viewport, scroll, and assert `getComputedStyle(nav).position` is `fixed` (wide)
or `sticky` (narrow), and that the nav stays in view after scrolling. That's how
you catch a sidebar that renders but scrolls away.

## index.html template

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Claude 블로그 한글 번역</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Apple SD Gothic Neo",
    "Malgun Gothic", sans-serif; color:#1a1a1a; line-height:1.7; max-width:760px;
    margin:0 auto; padding:48px 24px 96px; background:#fff; }
  h1 { font-size:1.7rem; margin:0 0 8px; }
  .sub { color:#666; font-size:0.92rem; margin:0 0 32px; }
  .sub a { color:#c96442; text-decoration:none; }
  ul { list-style:none; padding:0; margin:0; }
  li { border-bottom:1px solid #eee; padding:16px 0; }
  li a { color:#1a1a1a; text-decoration:none; font-size:1.1rem; font-weight:600; }
  li a:hover { color:#c96442; }
  .date { display:block; color:#888; font-size:0.82rem; margin-top:4px; }
  footer { margin-top:48px; color:#888; font-size:0.8rem; }
</style>
</head>
<body>
  <h1>Claude 블로그 한글 번역</h1>
  <p class="sub"><a href="https://claude.com/blog">claude.com/blog</a>의 글을 한국어로 옮긴 비공식 번역 모음입니다.</p>
  <ul>
    <!-- newest first; one <li> per post -->
    <li><a href="posts/<slug>.html">한글 제목</a><span class="date">2026-06-18 · Claude Code</span></li>
  </ul>
  <footer>비공식 번역본 · 정확한 의미는 각 글의 원문 링크를 함께 참고하세요.</footer>
</body>
</html>
```

When you add a post, update **two** places: a new `<li>` in `index.html` and a new
entry in the `POSTS` array in `posts/assets/nav.js`.
