#!/usr/bin/env python3
"""토큰 낭비 audit (2단계): 스캔 JSON에서 지목된 세션의 실제 대화 발췌 추출.

waste_scan.py 가 만든 JSON을 읽어, 카테고리별 상위 세션에서
"낭비를 유발한 실제 발화/도구 호출"을 인용문으로 뽑는다.
보고서의 '실제 대화 발췌' 컬럼 재료가 된다.

사용:
  python3 extract_excerpts.py [--scan /tmp/token_waste_scan.json]
"""
import argparse, json, glob, os, re
from datetime import datetime
from collections import Counter

def parse_ts(s):
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00'))
    except Exception:
        return None

def clean(s, n=160):
    return re.sub(r'\s+', ' ', s or '').strip()[:n]

def user_text(d):
    m = d.get('message') or {}
    c = m.get('content')
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        for b in c:
            if isinstance(b, dict) and b.get('type') == 'text':
                return b.get('text', '')
    return ''

def find_file(projects_dir, sid):
    hits = glob.glob(os.path.join(projects_dir, '*', sid + '*.jsonl'))
    return hits[0] if hits else None

def load(fp):
    rows = []
    try:
        with open(fp) as f:
            for line in f:
                try:
                    rows.append(json.loads(line))
                except Exception:
                    pass
    except OSError:
        pass
    return rows


def excerpt_ttl(projects_dir, events, gap_threshold_s, limit=6):
    """긴 공백 직후 세션을 깨운 사용자 메시지 인용."""
    out, seen = [], set()
    for ev in events:
        sid = ev['sid']
        if sid in seen or len(out) >= limit:
            continue
        seen.add(sid)
        fp = find_file(projects_dir, sid)
        if not fp:
            continue
        prev_ts, shown = None, 0
        for d in load(fp):
            if d.get('type') == 'assistant' and (d.get('message') or {}).get('usage'):
                prev_ts = parse_ts(d.get('timestamp', ''))
            elif d.get('type') == 'user' and not d.get('isMeta'):
                txt, ts = user_text(d), parse_ts(d.get('timestamp', ''))
                if txt and ts and prev_ts and (ts - prev_ts).total_seconds() > gap_threshold_s and shown < 2:
                    gap = (ts - prev_ts).total_seconds() / 60
                    out.append(f'[{sid}] {gap:.0f}분 공백 후 → "{clean(txt)}"')
                    shown += 1
    return out


def excerpt_big_reads(projects_dir, big_results, limit=6):
    """이미지/GIF Read 직전 어시스턴트 발화 인용."""
    out, seen = [], set()
    sids = []
    for br in big_results:
        if br['tool'] == 'Read' and br['sid'] not in seen:
            seen.add(br['sid'])
            sids.append(br['sid'])
    for sid in sids[:3]:
        fp = find_file(projects_dir, sid)
        if not fp:
            continue
        last_txt, shown = '', 0
        for d in load(fp):
            if d.get('type') != 'assistant':
                continue
            for b in ((d.get('message') or {}).get('content') or []):
                if not isinstance(b, dict):
                    continue
                if b.get('type') == 'text':
                    last_txt = b.get('text', '')
                elif b.get('type') == 'tool_use' and b.get('name') == 'Read':
                    p = (b.get('input') or {}).get('file_path', '')
                    if p.endswith(('.gif', '.png', '.jpg', '.jpeg', '.mp4')) and shown < 2 and len(out) < limit:
                        out.append(f'[{sid}] Read {os.path.basename(p)} ← 직전 발화: "{clean(last_txt, 100)}"')
                        shown += 1
    return out


def excerpt_session_search(projects_dir, limit=6):
    """세션 아카이브 검색을 메인 루프에서 시킨 첫 메시지 수집."""
    pat = re.compile(r'(세션|대화).{0,12}(찾|불러|리스트|검색)|find.{0,20}session', re.I)
    out = []
    for fp in glob.glob(os.path.join(projects_dir, '*', '*.jsonl')):
        if len(out) >= limit:
            break
        with open(fp) as f:
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                if d.get('type') == 'user' and not d.get('isMeta'):
                    t = user_text(d)
                    if t and pat.search(t[:200]):
                        out.append(f'[{os.path.basename(fp)[:8]}] "{clean(t, 110)}"')
                    break  # 세션 첫 user 메시지만 검사
    return out


def excerpt_errors(projects_dir, error_loops, limit=4):
    """반복 에러 tool_result 원문 샘플."""
    out = []
    for ev in error_loops[:2]:
        fp = find_file(projects_dir, ev['sid'])
        if not fp:
            continue
        shown = 0
        for d in load(fp):
            if d.get('type') != 'user':
                continue
            c = (d.get('message') or {}).get('content')
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get('type') == 'tool_result' and b.get('is_error') and shown < 2 and len(out) < limit:
                        cc = b.get('content')
                        s = cc if isinstance(cc, str) else json.dumps(cc, ensure_ascii=False, default=str)
                        out.append(f'[{ev["sid"]}] "{clean(s, 130)}"')
                        shown += 1
    return out


def excerpt_dup_reads(dup_reads, limit=5):
    out = []
    for ev in dup_reads[:limit]:
        files = ', '.join(os.path.basename(p) for p in ev['files'][:3])
        out.append(f'[{ev["sid"]}] {ev["reads"]}회 반복: {files} (~{ev["est_tokens"]//1000}k tok)')
    return out


def excerpt_short_starts(sessions, limit=5):
    """단문/잡담으로 시작한 세션."""
    out = []
    for s in sessions:
        first = (s.get('first') or '').strip()
        if first and len(first) <= 6 and '<' not in first and len(out) < limit:
            out.append(f'[{s["sid"]}] 첫 메시지 "{first}" → 이후 ${s["cost"]:.2f}, {s["user_turns"]}턴')
    return out


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--scan', default='/tmp/token_waste_scan.json')
    a = ap.parse_args()
    R = json.load(open(a.scan))
    pd = R['projects_dir']

    sections = [
        ('TTL 1h 만료 (방치 후 이어쓰기)', excerpt_ttl(pd, R['ttl1h']['events'], 3900)),
        ('TTL 5m 만료', excerpt_ttl(pd, R['ttl5m']['events'], 330)),
        ('대형 이미지/GIF Read', excerpt_big_reads(pd, R['big_results'])),
        ('세션 아카이브 검색을 메인 루프에서', excerpt_session_search(pd)),
        ('에러 반복 루프', excerpt_errors(pd, R['error_loops'])),
        ('동일 파일 반복 Read', excerpt_dup_reads(R['dup_reads'])),
        ('단문 시작 세션', excerpt_short_starts(R['sessions'])),
    ]
    for title, items in sections:
        print(f'### {title}')
        if items:
            for it in items:
                print(f'  {it}')
        else:
            print('  (해당 없음)')
        print()
