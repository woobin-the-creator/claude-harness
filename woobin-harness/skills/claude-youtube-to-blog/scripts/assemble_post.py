#!/usr/bin/env python3
"""Assemble a YouTube-derived Korean post and register it in the site's single source.

Fills assets/post-template.html -> <repo>/posts/<slug>.html, then inserts one entry at
the top of window.CBK_POSTS in <repo>/posts/assets/posts.js (newest first). Idempotent
by slug: re-running updates the existing entry instead of duplicating it.

The index category chips, sidebar, and per-post breadcrumb all read from posts.js, so
no other file needs editing.

Usage:
  assemble_post.py --repo ~/claude-blog-kr --slug cursor-rules-deep-dive \
    --title "커서 규칙 심층 분석" --nav "커서 규칙 심층" \
    --main "Cursor Youtube" --cat "세미나" --date 2026-06-25 \
    --video-url "https://www.youtube.com/watch?v=XXXX" \
    --video-title "Cursor Rules Deep Dive" \
    --body-file /tmp/cursor-rules-deep-dive-body.html
"""
import argparse
import json
import os
import re
import sys

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_TEMPLATE = os.path.join(SKILL_DIR, "assets", "post-template.html")


def video_id(url):
    for pat in (r"[?&]v=([\w-]{6,})", r"youtu\.be/([\w-]{6,})",
                r"/embed/([\w-]{6,})", r"/shorts/([\w-]{6,})"):
        m = re.search(pat, url)
        if m:
            return m.group(1)
    return ""


def build_html(args, body):
    with open(args.template, encoding="utf-8") as f:
        tpl = f.read()
    repl = {
        "{{KO_TITLE}}": args.title,
        "{{KO_DATE}}": args.date,
        "{{CATEGORY}}": args.cat,
        "{{VIDEO_URL}}": args.video_url,
        "{{VIDEO_TITLE}}": args.video_title,
        "{{VIDEO_ID}}": video_id(args.video_url),
        "{{BODY}}": body,
    }
    for k, v in repl.items():
        tpl = tpl.replace(k, v)
    # the template's BODY-guidance comment is authoring aid, not content
    tpl = re.sub(r"<!-- BODY guidance.*?-->\n?", "", tpl, flags=re.S)
    return tpl


def register_in_posts_js(posts_js_path, args):
    with open(posts_js_path, encoding="utf-8") as f:
        text = f.read()

    if "window.CBK_POSTS" not in text:
        sys.exit(f"ERROR: {posts_js_path} has no window.CBK_POSTS array")

    file_name = f"{args.slug}.html"
    # drop any existing entry for this slug (object literal has no nested braces)
    dup = re.compile(
        r'\n[ \t]*\{[^{}]*?file:\s*"' + re.escape(file_name) + r'"[^{}]*\}\,?',
        re.S,
    )
    text, removed = dup.subn("", text)

    def j(s):  # proper quoting/escaping, valid JS, keep Korean literal
        return json.dumps(s, ensure_ascii=False)
    entry = (
        f'    {{ file: {j(file_name)}, date: {j(args.date)}, '
        f'main: {j(args.main)}, cat: {j(args.cat)},\n'
        f'      title: {j(args.title)}, nav: {j(args.nav or args.title)} }},\n'
    )
    new_text, n = re.subn(
        r'(window\.CBK_POSTS\s*=\s*\[\n)', r'\1' + entry.replace('\\', '\\\\'),
        text, count=1,
    )
    if n != 1:
        sys.exit("ERROR: could not locate the CBK_POSTS array opening to insert entry")
    with open(posts_js_path, "w", encoding="utf-8") as f:
        f.write(new_text)
    return "updated" if removed else "added"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--slug", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--nav", default="")
    ap.add_argument("--main", required=True, help="출처 (e.g. 'Cursor Youtube')")
    ap.add_argument("--cat", required=True, help="주제 (e.g. '세미나')")
    ap.add_argument("--date", required=True, help="YYYY-MM-DD")
    ap.add_argument("--video-url", required=True)
    ap.add_argument("--video-title", required=True)
    ap.add_argument("--body-file", required=True)
    ap.add_argument("--template", default=DEFAULT_TEMPLATE)
    args = ap.parse_args()

    repo = os.path.abspath(os.path.expanduser(args.repo))
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", args.slug):
        sys.exit("ERROR: --slug must be ascii kebab-case (a-z0-9-)")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.date):
        sys.exit("ERROR: --date must be YYYY-MM-DD")

    with open(os.path.expanduser(args.body_file), encoding="utf-8") as f:
        body = f.read().strip()

    posts_dir = os.path.join(repo, "posts")
    posts_js = os.path.join(posts_dir, "assets", "posts.js")
    if not os.path.isfile(posts_js):
        sys.exit(f"ERROR: {posts_js} not found — is --repo correct?")

    out_html = os.path.join(posts_dir, f"{args.slug}.html")
    with open(out_html, "w", encoding="utf-8") as f:
        f.write(build_html(args, body))

    action = register_in_posts_js(posts_js, args)

    assets_dir = os.path.join(posts_dir, "assets", args.slug)
    frames = []
    if os.path.isdir(assets_dir):
        frames = sorted(x for x in os.listdir(assets_dir)
                        if x.lower().endswith((".jpg", ".jpeg", ".png")))

    print(f"OK: wrote {out_html}")
    print(f"posts.js: {action} entry for {args.slug} (main={args.main!r} cat={args.cat!r})")
    print(f"frames in posts/assets/{args.slug}/: {len(frames)}"
          + (f" — {', '.join(frames[:6])}{'…' if len(frames) > 6 else ''}" if frames else " (none yet)"))
    if not frames:
        print("WARN: no screenshots found — extract them into "
              f"posts/assets/{args.slug}/ before deploying.")


if __name__ == "__main__":
    main()
