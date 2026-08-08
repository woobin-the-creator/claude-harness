#!/usr/bin/env python3
"""
Extract translatable content + media from a claude.com/blog post.

Why this exists: when you translate a blog post, the easy mistakes are (1) missing
media because you only looked for <img> and forgot YouTube <iframe> embeds, and
(2) pulling in site-chrome images (placeholders, related-post cards, the decorative
hero illustration of *other* posts) that aren't part of the article. This script
applies the filtering heuristics that are specific to claude.com's Webflow markup
so you don't have to rediscover them every time.

Usage:
    python extract_media.py <url-or-html-file>

It prints a JSON object to stdout:
    {
      "title": "...",
      "date_published": "Jun 17, 2026",
      "hero": "https://.../...svg",                       # this post's hero illustration (optional)
      "content_images": [{"src": "...", "caption": "..."}],
      "youtube": [{"src": "https://www.youtube.com/embed/ID?start=N", "title": "..."}],
      "videos": ["https://..."],                           # <video>/<source> with a real src
      "links": [{"text": "...", "href": "..."}]            # candidate inline links to preserve
    }

The content_images keep their *document order* and are paired with the <figcaption>
that immediately follows each one, so you can place them under the right section.
Review the output before using it — heuristics are not perfect.
"""
import json
import re
import sys
import urllib.request

# Image classes that are site chrome, never article content.
CHROME_CLASS_HINTS = (
    "placeholder",
    "card_blog_illo",          # related-post cards at the bottom
    "hero_blog_post_illo",     # this post's hero illo (captured separately as `hero`)
    "illustration_light",
    "illustration_dark",
    "u-background-skeleton",
)

# Hosts whose inline links are usually worth preserving in a translation.
LINK_HOST_HINTS = (
    "claude.com/blog",
    "code.claude.com",
    "platform.claude.com",
    "github.com",
    "anthropic.com",
)


def load(src: str) -> str:
    if src.startswith("http://") or src.startswith("https://"):
        req = urllib.request.Request(src, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.read().decode("utf-8", "replace")
    with open(src, encoding="utf-8", errors="replace") as f:
        return f.read()


def strip_tags(s: str) -> str:
    return re.sub(r"<[^>]+>", "", s).strip()


def attr(tag: str, name: str) -> str:
    m = re.search(name + r'="([^"]*)"', tag)
    return m.group(1) if m else ""


def extract(html: str) -> dict:
    out = {
        "title": "",
        "date_published": "",
        "hero": "",
        "content_images": [],
        "youtube": [],
        "videos": [],
        "links": [],
    }

    # Title + date
    m = re.search(r"<title>([^<]*)</title>", html)
    if m:
        out["title"] = m.group(1).replace(" | Claude", "").strip()
    m = re.search(r'"datePublished":\s*"([^"]*)"', html)
    if m:
        out["date_published"] = m.group(1)

    # Hero illustration of THIS post
    for m in re.finditer(r"<img[^>]*>", html):
        tag = m.group(0)
        if "hero_blog_post_illo_img" in tag:
            out["hero"] = attr(tag, "src")
            break

    # Content images in document order, each paired with the following figcaption
    for m in re.finditer(r"<img[^>]*>", html):
        tag = m.group(0)
        cls = attr(tag, "class")
        src = attr(tag, "src")
        if not src:
            continue
        if any(h in cls for h in CHROME_CLASS_HINTS):
            continue
        if any(h in src for h in CHROME_CLASS_HINTS):
            continue
        # Webflow content images live on the same CDN but lack a chrome class.
        following = html[m.end(): m.end() + 800]
        cap_m = re.search(r"<figcaption[^>]*>(.*?)</figcaption>", following, re.S)
        caption = strip_tags(cap_m.group(1)) if cap_m else ""
        out["content_images"].append({"src": src, "caption": caption})

    # YouTube iframe embeds (the easy-to-miss media)
    for m in re.finditer(r"<iframe[^>]*>", html):
        tag = m.group(0)
        src = attr(tag, "src")
        if "youtube.com/embed" in src or "youtu.be" in src:
            out["youtube"].append({"src": src, "title": attr(tag, "title")})

    # Real <video>/<source> (skip empty-src background skeletons)
    for m in re.finditer(r"<(?:video|source)[^>]*>", html):
        tag = m.group(0)
        src = attr(tag, "src")
        if src.strip():
            out["videos"].append(src)

    # Candidate inline links worth preserving
    seen = set()
    for m in re.finditer(r"<a [^>]*href=\"[^\"]*\"[^>]*>.*?</a>", html, re.S):
        a = m.group(0)
        href = attr(a, "href")
        text = strip_tags(a)
        if not text or not href:
            continue
        if href.startswith("#") or href.startswith("/blog/category"):
            continue
        key = (text, href)
        if key in seen:
            continue
        if any(h in href for h in LINK_HOST_HINTS) or href.startswith("http"):
            seen.add(key)
            out["links"].append({"text": text, "href": href})

    return out


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    html = load(sys.argv[1])
    print(json.dumps(extract(html), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
