#!/usr/bin/env python3
"""Claude Code 세션 토큰 낭비 스캔 (1단계).

~/.claude/projects/*/*.jsonl 전수를 읽어 낭비 카테고리별로 정량화하고,
사람용 요약(stdout) + 기계용 JSON(--out)을 출력한다.
2단계(extract_excerpts.py)가 이 JSON을 읽어 대화 발췌를 뽑는다.

사용:
  python3 waste_scan.py [--projects-dir ~/.claude/projects] [--days 60] \
                        [--out /tmp/token_waste_scan.json]

낭비 카테고리 (references/checklist.md 항목 번호와 대응):
  ttl5m / ttl1h  : 캐시 TTL 만료 후 이어쓰기로 인한 재캐싱
  invalidation   : 짧은 간격인데 대량 재캐싱 = prefix 무효화(모델 전환·툴셋 변경·병렬 요청)
  excess200k     : 200k 초과 컨텍스트 유지비 (cache read)
  big_results    : 40k chars 이상 tool_result (GIF/이미지/로그 유입)
  dup_reads      : 동일 파일 3회+ Read
  error_loops    : is_error tool_result 8회+ 세션
  overhead       : 세션 첫 요청 컨텍스트 크기 (MCP/스킬 고정 오버헤드)
  lanes/agents   : 메인 루프 vs 서브에이전트(sidechain) 분리 + agent type별 비용
  w2/w3          : 모델 과대/과소 선택 후보
  w4             : 서브에이전트 과대 모델 후보 (탐색/검증 agent가 opus·fable로 도는 경우)

주의: 가격표는 작성 시점(2026-06) 기준. 모델 추가·가격 변동 시 PRICE 갱신 필요.
"""
import argparse, json, glob, os, sys, time
from datetime import datetime
from collections import defaultdict

# $/MTok (input, output). cache read = 0.1x input, write 5m = 1.25x, 1h = 2x
PRICE = {
    'claude-fable-5': (10, 50),
    'claude-mythos-5': (10, 50),
    'claude-opus-4-8': (5, 25), 'claude-opus-4-7': (5, 25),
    'claude-opus-4-6': (5, 25), 'claude-opus-4-5': (5, 25),
    'claude-opus-4-1': (15, 75), 'claude-opus-4-0': (15, 75),
    'claude-sonnet-4-6': (3, 15), 'claude-sonnet-4-5': (3, 15),
    'claude-sonnet-5': (3, 15),
    'claude-haiku-4-5': (1, 5),
}

def price_of(model):
    for k, v in PRICE.items():
        if model and model.startswith(k):
            return v
    if model and 'opus' in model: return (5, 25)
    if model and 'sonnet' in model: return (3, 15)
    if model and 'haiku' in model: return (1, 5)
    return (5, 25)

def parse_ts(s):
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00'))
    except Exception:
        return None

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

def scan(projects_dir, days=None):
    # 서브에이전트 트랜스크립트는 <proj>/<sessionId>/subagents/agent-*.jsonl 에 따로 쌓인다.
    # 예전 glob('*/*.jsonl')은 이걸 통째로 놓쳐서 서브에이전트 비용이 0으로 보였다.
    files = sorted(glob.glob(os.path.join(projects_dir, '**', '*.jsonl'), recursive=True))
    if days:
        cutoff = time.time() - days * 86400
        files = [f for f in files if os.path.getmtime(f) >= cutoff]

    R = {
        'generated_at': datetime.now().isoformat(),
        'projects_dir': projects_dir, 'file_count': len(files),
        'total_cost': 0.0, 'cost_by_model': defaultdict(float),
        'tok_by_model': defaultdict(lambda: defaultdict(int)),
        'ttl5m': {'total': 0.0, 'events': []},
        'ttl1h': {'total': 0.0, 'events': []},
        'invalidation': {'total': 0.0, 'events': []},
        'excess200k': {'total': 0.0, 'by_session': []},
        'big_results': [], 'dup_reads': [], 'error_loops': [],
        'overhead': {}, 'sessions': [],
        'cost_by_lane': {'main': defaultdict(float), 'sidechain': defaultdict(float)},
        'agent_costs': defaultdict(lambda: defaultdict(float)),
        'agent_reqs': defaultdict(int),
        'w2_candidates': [], 'w3_candidates': [], 'w4_candidates': [],
    }
    overheads = []

    for fp in files:
        rel = os.path.relpath(fp, projects_dir).split(os.sep)
        proj = rel[0]
        if len(rel) >= 4 and rel[2] == 'subagents':   # <proj>/<sessionId>/subagents/agent-*.jsonl
            sid = rel[1][:8] + '/' + os.path.basename(fp)[:14]
        else:
            sid = os.path.basename(fp)[:8]
        reqs = {}; order = []
        reads = defaultdict(int); read_ids = {}; tool_results = {}
        tools = {}
        req_agent = {}       # requestId -> agent type (sidechain일 때만), 메인은 None
        err = 0; user_turns = 0; first_user = ''
        big_here = []
        try:
            f = open(fp)
        except OSError:
            continue
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = d.get('type')
            if t == 'assistant':
                m = d.get('message', {})
                u = m.get('usage'); rid = d.get('requestId'); model = m.get('model', '')
                if u and rid and model and not model.startswith('<'):
                    if rid not in reqs:
                        order.append(rid)
                        req_agent[rid] = (d.get('attributionAgent') or 'unknown-agent') \
                            if d.get('isSidechain') else None
                    reqs[rid] = (parse_ts(d.get('timestamp', '')), model, u)
                for b in (m.get('content') or []):
                    if isinstance(b, dict) and b.get('type') == 'tool_use':
                        inp = b.get('input') or {}
                        hint = inp.get('command') or inp.get('file_path') or inp.get('pattern') or ''
                        tools[b.get('id')] = (b.get('name', ''), str(hint)[:120])
                        if b.get('name') == 'Read' and inp.get('file_path'):
                            reads[inp['file_path']] += 1
                            read_ids[b.get('id')] = inp['file_path']
            elif t == 'user':
                c = (d.get('message') or {}).get('content')
                if isinstance(c, str):
                    if not d.get('isMeta') and not d.get('isSidechain'):
                        user_turns += 1
                        first_user = first_user or c[:120]
                elif isinstance(c, list):
                    for b in c:
                        if not isinstance(b, dict):
                            continue
                        if b.get('type') == 'tool_result':
                            cc = b.get('content')
                            ln = len(cc) if isinstance(cc, str) else len(json.dumps(cc, ensure_ascii=False, default=str))
                            tool_results[b.get('tool_use_id')] = ln
                            if b.get('is_error'):
                                err += 1
                            if ln > 40000:
                                nm, hint = tools.get(b.get('tool_use_id'), ('?', ''))
                                big_here.append((ln, nm, hint))
                        elif b.get('type') == 'text' and not d.get('isMeta') and not d.get('isSidechain'):
                            user_turns += 1
                            first_user = first_user or (b.get('text') or '')[:120]
        f.close()
        if not reqs:
            continue

        s_cost = 0.0; s_out = 0; max_ctx = 0; first_ctx = None
        models = defaultdict(float); prev = None
        s_excess = 0.0
        side_cost = 0.0
        agent_here = defaultdict(lambda: defaultdict(float))
        for rid in order:
            ts, model, u = reqs[rid]
            pin, pout = price_of(model)
            it = u.get('input_tokens', 0); ot = u.get('output_tokens', 0)
            cr = u.get('cache_read_input_tokens', 0)
            cc = u.get('cache_creation') or {}
            c5 = cc.get('ephemeral_5m_input_tokens', 0)
            c1 = cc.get('ephemeral_1h_input_tokens', 0)
            if not cc:
                c5 = u.get('cache_creation_input_tokens', 0)
            cost = (it * pin + cr * 0.1 * pin + c5 * 1.25 * pin + c1 * 2 * pin + ot * pout) / 1e6
            s_cost += cost; s_out += ot
            models[model] += cost
            R['cost_by_model'][model] += cost
            tb = R['tok_by_model'][model]
            tb['in'] += it; tb['out'] += ot; tb['cread'] += cr; tb['cwrite'] += c5 + c1
            ag = req_agent.get(rid)
            if ag:
                R['cost_by_lane']['sidechain'][model] += cost
                side_cost += cost
                R['agent_costs'][ag][model] += cost
                R['agent_reqs'][ag] += 1
                agent_here[ag][model] += cost
            else:
                R['cost_by_lane']['main'][model] += cost
            ctx = it + cr + c5 + c1
            if first_ctx is None:
                first_ctx = ctx
            max_ctx = max(max_ctx, ctx)
            if ctx > 200_000:
                s_excess += (ctx - 200_000) * 0.1 * pin / 1e6
            if prev:
                pts_, pmodel = prev
                gap = (ts - pts_).total_seconds() if (ts and pts_) else 0
                recre = c5 + c1
                if gap > 3900 and recre > 20000:      # 1h TTL 만료
                    w = recre * pin * (2 - 0.1) / 1e6
                    R['ttl1h']['total'] += w
                    R['ttl1h']['events'].append(
                        {'proj': proj, 'sid': sid, 'gap_min': round(gap / 60),
                         'tokens': recre, 'waste': round(w, 2),
                         'ts': ts.isoformat() if ts else None})
                elif 330 < gap <= 3900 and c5 > 5000:  # 5m TTL 만료 (5m 캐시 사용 시)
                    w = c5 * pin * (1.25 - 0.1) / 1e6
                    R['ttl5m']['total'] += w
                    R['ttl5m']['events'].append(
                        {'proj': proj, 'sid': sid, 'gap_min': round(gap / 60),
                         'tokens': c5, 'waste': round(w, 2)})
                elif gap < 330 and recre > 50000:      # prefix 무효화
                    w = recre * pin * (2 - 0.1) / 1e6
                    R['invalidation']['total'] += w
                    R['invalidation']['events'].append(
                        {'proj': proj, 'sid': sid, 'model_switch': pmodel != model,
                         'tokens': recre, 'waste': round(w, 2),
                         'ts': ts.isoformat() if ts else None})
            prev = (ts, model)

        if s_excess > 0:
            R['excess200k']['total'] += s_excess
            R['excess200k']['by_session'].append(
                {'proj': proj, 'sid': sid, 'cost': round(s_excess, 2), 'max_ctx': max_ctx})
        if first_ctx:
            overheads.append(first_ctx)
        dups = {p: c for p, c in reads.items() if c >= 3}
        if dups:
            wt = 0
            for p, c in dups.items():
                sizes = [ln for tid, ln in tool_results.items() if read_ids.get(tid) == p]
                avg = (sum(sizes) / len(sizes) / 4) if sizes else 500
                wt += (c - 1) * avg
            R['dup_reads'].append(
                {'proj': proj, 'sid': sid, 'files': sorted(dups, key=dups.get, reverse=True)[:5],
                 'reads': sum(dups.values()), 'est_tokens': int(wt)})
        if err >= 8:
            R['error_loops'].append({'proj': proj, 'sid': sid, 'errors': err, 'reqs': len(reqs)})
        for ln, nm, hint in sorted(big_here, reverse=True)[:5]:
            R['big_results'].append({'chars': ln, 'tool': nm, 'hint': hint, 'proj': proj, 'sid': sid})

        R['total_cost'] += s_cost
        sess = {'proj': proj, 'sid': sid, 'cost': round(s_cost, 2), 'reqs': len(reqs),
                'user_turns': user_turns, 'out_tok': s_out, 'max_ctx': max_ctx,
                'models': {k: round(v, 2) for k, v in models.items()}, 'first': first_user,
                'side_cost': round(side_cost, 2)}
        R['sessions'].append(sess)
        for ag, mm in agent_here.items():
            over = sum(c for m, c in mm.items() if ('opus' in m or 'fable' in m or 'mythos' in m))
            if over >= 0.5:
                R['w4_candidates'].append(
                    {'proj': proj, 'sid': sid, 'agent': ag, 'cost': round(over, 2),
                     'models': {k: round(v, 2) for k, v in mm.items()}})
        if len(reqs) <= 6 and s_out < 3000 and any(('fable' in m or 'opus' in m) for m in models):
            R['w2_candidates'].append(sess)
        if user_turns >= 25 and models and all(('haiku' in m or 'sonnet' in m) for m in models):
            R['w3_candidates'].append(sess)

    if overheads:
        so = sorted(overheads)
        R['overhead'] = {'n': len(so), 'avg': int(sum(so) / len(so)), 'median': so[len(so) // 2]}
    R['sessions'].sort(key=lambda x: -x['cost'])
    R['big_results'].sort(key=lambda x: -x['chars'])
    for key in ('ttl1h', 'ttl5m', 'invalidation'):
        R[key]['events'].sort(key=lambda x: -x['waste'])
    R['excess200k']['by_session'].sort(key=lambda x: -x['cost'])
    R['cost_by_model'] = dict(sorted(R['cost_by_model'].items(), key=lambda x: -x[1]))
    R['tok_by_model'] = {k: dict(v) for k, v in R['tok_by_model'].items()}
    R['cost_by_lane'] = {lane: dict(sorted(mm.items(), key=lambda x: -x[1]))
                         for lane, mm in R['cost_by_lane'].items()}
    R['agent_costs'] = {ag: dict(sorted(mm.items(), key=lambda x: -x[1]))
                        for ag, mm in sorted(R['agent_costs'].items(),
                                             key=lambda x: -sum(x[1].values()))}
    R['agent_reqs'] = dict(R['agent_reqs'])
    R['w4_candidates'].sort(key=lambda x: -x['cost'])
    return R


def summary(R):
    L = []
    L.append(f"세션 {len(R['sessions'])}개 / 총 추정 비용 ${R['total_cost']:.2f}")
    L.append('--- 모델별 ---')
    for m, c in R['cost_by_model'].items():
        tb = R['tok_by_model'][m]
        L.append(f"  {m}: ${c:.2f} (cread {tb.get('cread',0)/1e6:.1f}M, out {tb.get('out',0)/1e6:.2f}M)")
    lanes = R.get('cost_by_lane') or {}
    if lanes:
        mt = sum(lanes.get('main', {}).values()); st = sum(lanes.get('sidechain', {}).values())
        tot = mt + st
        L.append(f"--- 레인별 (메인 루프 vs 서브에이전트) ---")
        L.append(f"  메인 루프:     ${mt:.2f} ({mt/tot*100 if tot else 0:.0f}%)")
        L.append(f"  서브에이전트:  ${st:.2f} ({st/tot*100 if tot else 0:.0f}%)")
        for m, c in list(lanes.get('sidechain', {}).items())[:6]:
            L.append(f"      {m}: ${c:.2f}")
    ac = R.get('agent_costs') or {}
    if ac:
        L.append('--- agent type별 (서브에이전트) ---')
        for ag, mm in list(ac.items())[:10]:
            ms = ', '.join(f'{m.replace("claude-","")} ${c:.2f}' for m, c in mm.items())
            L.append(f"  {ag}: ${sum(mm.values()):.2f} ({R['agent_reqs'].get(ag,0)} reqs) | {ms}")
    if R.get('w4_candidates'):
        w4 = R['w4_candidates']
        L.append(f"[W4] 서브에이전트 과대 모델 후보: {len(w4)}건 / ${sum(x['cost'] for x in w4):.2f}")
        for x in w4[:5]:
            L.append(f"      ${x['cost']:6.2f} | {x['agent']} | {x['proj'][-20:]}/{x['sid']}")
    L.append(f"TTL 5m 만료: ${R['ttl5m']['total']:.2f} ({len(R['ttl5m']['events'])}건)")
    L.append(f"TTL 1h 만료: ${R['ttl1h']['total']:.2f} ({len(R['ttl1h']['events'])}건)")
    L.append(f"캐시 무효화: ${R['invalidation']['total']:.2f} ({len(R['invalidation']['events'])}건)")
    L.append(f"200k 초과 유지비: ${R['excess200k']['total']:.2f}")
    ov = R.get('overhead') or {}
    if ov:
        L.append(f"세션 시작 오버헤드: 평균 {ov['avg']/1000:.0f}k tok × {ov['n']}세션")
    L.append(f"대형 tool_result: {len(R['big_results'])}건, 중복Read 세션: {len(R['dup_reads'])}, 에러다발: {len(R['error_loops'])}")
    L.append('--- 비용 TOP 10 세션 ---')
    for x in R['sessions'][:10]:
        L.append(f"  ${x['cost']:7.2f} | {x['proj'][-25:]}/{x['sid']} | req {x['reqs']} turns {x['user_turns']} maxctx {x['max_ctx']//1000}k | {x['first'][:50]!r}")
    return '\n'.join(L)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--projects-dir', default=os.path.expanduser('~/.claude/projects'))
    ap.add_argument('--days', type=int, default=None, help='최근 N일 세션만 (파일 mtime 기준)')
    ap.add_argument('--out', default='/tmp/token_waste_scan.json')
    a = ap.parse_args()
    R = scan(a.projects_dir, a.days)
    with open(a.out, 'w') as f:
        json.dump(R, f, ensure_ascii=False, default=str)
    print(summary(R))
    print(f'\n[기계용 JSON] {a.out}', file=sys.stderr)
