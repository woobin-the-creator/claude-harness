#!/usr/bin/env python3
"""agentic 역량 채점용 지표 수집 — 숫자만 낸다. 판정은 하지 않는다.

라우트 A(주간·월간)의 재현성은 전적으로 이 스크립트에 달려 있다.
모델이 눈대중으로 세면 모델마다 다른 숫자가 나오고, 그러면 점수를 비교할 수 없다.
그래서 채점 모델은 이 JSON 밖의 숫자를 만들어내면 안 된다.

측정 불가 항목은 지어내지 않고 null 로 남긴다 — 루브릭이 null 을 별도로 처리한다.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time

HOME = os.path.expanduser("~")
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")
# 탐색성 Bash — 방금 고친 파일 재확인(검증)과 구분이 안 되는 건 알고 있다.
# 비율 지표로만 쓰고 절대값으로 판정하지 않는다(루브릭 A5 주석 참조).
DISCOVER_RE = re.compile(r"\b(grep|rg|ag|find|fd)\b|sed\s+-n|\bls\s+-R\b")
# A1 분모에 넣을 "실질 세션"의 최소 요청 수. 이 값을 바꾸면 과거 점수와 비교 불가다.
SUBSTANTIVE_MIN_REQS = 10


def resolve_repo(explicit):
    for cand in [
        explicit,
        os.environ.get("CLAUDE_HARNESS_REPO"),
        os.path.join(HOME, "codespace", "claude-harness"),
        os.path.join(HOME, "claude-harness"),
    ]:
        if cand and os.path.isdir(os.path.join(cand, "woobin-harness")):
            return os.path.realpath(cand)
    return None


def find_waste_scan():
    bundled = os.path.realpath(os.path.join(
        os.path.dirname(__file__), "..", "..", "token-waste-audit", "scripts", "waste_scan.py"
    ))
    for cand in [
        bundled,
        os.path.join(HOME, ".claude/skills/token-waste-audit/scripts/waste_scan.py"),
        os.path.join(os.environ.get("CLAUDE_PLUGIN_ROOT", ""), "skills/token-waste-audit/scripts/waste_scan.py"),
    ]:
        if cand and os.path.isfile(cand):
            return cand
    return None


def run_waste_scan(days, projects_dir):
    """비용·컨텍스트 지표는 기존 도구를 재사용한다. 재구현하면 두 곳이 소유하게 된다."""
    script = find_waste_scan()
    if not script:
        return None, "waste_scan.py 를 찾지 못했다"
    out = os.path.join(tempfile.mkdtemp(), "scan.json")
    cmd = [sys.executable, script, "--days", str(days), "--out", out]
    if projects_dir:
        cmd += ["--projects-dir", projects_dir]
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=900)
        with open(out) as f:
            return json.load(f), None
    except Exception as e:  # noqa: BLE001 — 실패해도 나머지 지표는 내야 한다
        return None, f"waste_scan 실패: {type(e).__name__}: {e}"


def scan_transcripts(projects_dir, days):
    """레인별 툴 호출·에이전트 스폰·스킬 호출을 센다."""
    cutoff = time.time() - days * 86400
    acc = {
        "files": 0,
        "main_read_code": 0,
        "main_read_image": 0,
        "main_image_files": [],
        "main_discover_bash": 0,
        "agent_spawns": {},
        "skill_calls": {},
        "tool_by_lane": {"main": {}, "sidechain": {}},
    }
    for path in glob.glob(os.path.join(projects_dir, "**", "*.jsonl"), recursive=True):
        try:
            if os.path.getmtime(path) < cutoff:
                continue
        except OSError:
            continue
        acc["files"] += 1
        rel_parts = os.path.relpath(path, projects_dir).split(os.sep)
        file_is_sidechain = len(rel_parts) >= 4 and rel_parts[2] == "subagents"
        with open(path, errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    d = json.loads(line)
                except json.JSONDecodeError:
                    continue
                side = bool(d.get("isSidechain")) or file_is_sidechain
                lane = "sidechain" if side else "main"
                msg = d.get("message") or {}
                content = msg.get("content")
                if not isinstance(content, list):
                    continue
                for b in content:
                    if not isinstance(b, dict) or b.get("type") != "tool_use":
                        continue
                    name = b.get("name") or "?"
                    inp = b.get("input") or {}
                    acc["tool_by_lane"][lane][name] = acc["tool_by_lane"][lane].get(name, 0) + 1
                    if name in ("Agent", "Task"):
                        t = str(inp.get("subagent_type") or "unspecified")
                        acc["agent_spawns"][t] = acc["agent_spawns"].get(t, 0) + 1
                    elif name == "Skill":
                        s = str(inp.get("skill") or "?")
                        acc["skill_calls"][s] = acc["skill_calls"].get(s, 0) + 1
                    if side:
                        continue
                    if name == "Read":
                        fp = str(inp.get("file_path") or "").lower()
                        if fp.endswith(IMAGE_EXT):
                            acc["main_read_image"] += 1
                            # 루브릭 A5가 "어떤 파일이었나"를 묻는다 — 데모 GIF는 규칙상 예외라
                            # 파일명 없이는 보정 판단을 할 수 없다.
                            if len(acc["main_image_files"]) < 30:
                                acc["main_image_files"].append(os.path.basename(fp))
                        else:
                            acc["main_read_code"] += 1
                    elif name == "Bash" and DISCOVER_RE.search(str(inp.get("command") or "")):
                        acc["main_discover_bash"] += 1
    return acc


def parse_harness_log(repo):
    """요약 표에서 재측정 완료율을 뽑는다. '(신규)' = 미재측정."""
    path = os.path.join(repo, "home", "HARNESS-LOG.md")
    if not os.path.isfile(path):
        return {"total": None, "remeasured": None, "rate": None}
    total = done = 0
    with open(path) as f:
        for line in f:
            if not re.match(r"^\|\s*\d+\s*\|", line):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 5:
                continue
            total += 1
            if "신규" not in cells[-1] and cells[-1] not in ("", "—", "-"):
                done += 1
    return {
        "total": total or None,
        "remeasured": done if total else None,
        "rate": round(done / total, 3) if total else None,
    }


def parse_workflow_spec(repo):
    """§7-B 미사용 레버 수, §8 열린 항목 수/해소 수, §9 모순 수."""
    path = os.path.join(repo, "docs", "workflow-spec.md")
    if not os.path.isfile(path):
        return {"unused_levers": None, "open_total": None, "open_resolved": None, "contradictions": None}
    text = open(path).read()

    def section(num):
        m = re.search(rf"^##\s*{num}\.(.*?)(?=^##\s|\Z)", text, re.S | re.M)
        return m.group(1) if m else ""

    s7 = section(7)
    unused = len(re.findall(r"미사용|미평가|대응물이 없다", s7))

    s8 = section(8)
    rows = [ln for ln in s8.splitlines() if re.match(r"^\|\s*O\d+\s*\|", ln)]
    resolved = sum(1 for ln in rows if "해소" in ln or "✅" in ln)

    s9 = section(9)
    contradictions = len(re.findall(r"^\d+\.\s+\*\*", s9, re.M))

    return {
        "unused_levers": unused,
        "open_total": len(rows) or None,
        "open_resolved": resolved,
        "contradictions": contradictions,
    }


def parse_outcome_metrics(hist_dir):
    """산출물 품질 지표 — 기록 파일이 없으면 0/4. 이 축은 '있냐 없냐'가 전부다."""
    keys = ["lead_time_days", "rework_commits", "ci_first_pass_rate", "task_count_drift"]
    path = os.path.join(hist_dir, "outcome-metrics.jsonl")
    if not os.path.isfile(path):
        return {"recorded": 0, "of": len(keys), "latest": None}
    last = None
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    last = json.loads(line)
                except json.JSONDecodeError:
                    pass
    if not isinstance(last, dict):
        return {"recorded": 0, "of": len(keys), "latest": None}
    return {
        "recorded": sum(1 for k in keys if last.get(k) is not None),
        "of": len(keys),
        "latest": last,
    }


def parse_tool_awareness(hist_dir, now):
    path = os.path.join(hist_dir, "tool-awareness.md")
    if not os.path.isfile(path):
        return {"last_check": None, "days_since": None}
    m = re.search(r"(\d{4}-\d{2}-\d{2})", open(path).read())
    if not m:
        return {"last_check": None, "days_since": None}
    try:
        t = time.mktime(time.strptime(m.group(1), "%Y-%m-%d"))
    except ValueError:
        return {"last_check": m.group(1), "days_since": None}
    return {"last_check": m.group(1), "days_since": int((now - t) // 86400)}


def git_self_corrections(repo, days):
    """자기 정정 커밋 수 — 되돌리기·기각·철회를 명시한 커밋."""
    try:
        out = subprocess.run(
            ["git", "-C", repo, "log", f"--since={days}.days", "--pretty=%s%n%b"],
            capture_output=True, text=True, timeout=60, check=True,
        ).stdout
    except Exception:  # noqa: BLE001
        return None
    return len(re.findall(r"정정|철회|기각|되돌|revert|correct", out, re.I))


def count_audit_snapshots(days, now):
    d = os.path.join(HOME, ".claude", "token-waste-audits")
    if not os.path.isdir(d):
        return 0
    cutoff = now - days * 86400
    return sum(1 for p in glob.glob(os.path.join(d, "*.json")) if os.path.getmtime(p) >= cutoff)


def count_installed(repo):
    p = os.path.join(repo, "woobin-harness")
    return {
        "hooks": len(glob.glob(os.path.join(p, "hooks", "*.sh"))),
        "agents": len(glob.glob(os.path.join(p, "agents", "*.md"))),
        "skills": len([x for x in glob.glob(os.path.join(p, "skills", "*")) if os.path.isdir(x)]),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--repo", default=None)
    ap.add_argument("--projects-dir", default=os.path.join(HOME, ".claude", "projects"))
    ap.add_argument("--history-dir", default=None)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()

    now = time.time()
    repo = resolve_repo(a.repo)
    if not repo:
        print("claude-harness 레포를 찾지 못했다. --repo 또는 CLAUDE_HARNESS_REPO 로 지정해라.", file=sys.stderr)
        sys.exit(2)
    hist = a.history_dir or os.environ.get("CAPABILITY_AUDIT_HISTORY_DIR") or os.path.join(repo, "docs", "scores")

    scan, scan_err = run_waste_scan(a.days, a.projects_dir)
    all_sessions = (scan or {}).get("sessions") or []
    # 실질 세션만 센다. 요청 10회 미만은 열자마자 닫은 것·서브에이전트 전용 파일이 대부분이고,
    # 그걸 분모에 넣으면 "200k 초과 비율"이 조용히 희석돼 A1이 실제보다 좋게 나온다.
    sessions = [s for s in all_sessions if (s.get("reqs") or 0) >= SUBSTANTIVE_MIN_REQS]
    ctxs = sorted(s.get("max_ctx") or 0 for s in sessions)
    med = ctxs[len(ctxs) // 2] if ctxs else None
    over = sum(1 for c in ctxs if c >= 200_000)
    # cost_by_lane 은 {lane: {model: cost}} 중첩이다 — 레인별로 합산한다.
    lane_raw = (scan or {}).get("cost_by_lane") or {}
    lane = {k: (sum(v.values()) if isinstance(v, dict) else (v or 0)) for k, v in lane_raw.items()}
    total_cost = (scan or {}).get("total_cost")

    tr = scan_transcripts(a.projects_dir, a.days)
    explore = tr["agent_spawns"].get("Explore", 0)
    discover = tr["main_read_code"] + tr["main_discover_bash"]

    inst = count_installed(repo)
    used_skills = len(tr["skill_calls"])

    result = {
        "schema": 1,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "window_days": a.days,
        "repo": repo,
        "history_dir": hist,
        "errors": [e for e in [scan_err] if e],

        "A1_context": {
            "sessions": len(sessions),
            "sessions_all": len(all_sessions),
            "substantive_min_reqs": SUBSTANTIVE_MIN_REQS,
            "median_max_ctx": med,
            "over200k_sessions": over,
            "over200k_ratio": round(over / len(sessions), 3) if sessions else None,
            "total_cost": total_cost,
        },
        "A2_measurement": {
            "harness_log": parse_harness_log(repo),
            "audit_snapshots_in_window": count_audit_snapshots(a.days, now),
            "open_items": parse_workflow_spec(repo),
        },
        "A3_hygiene": {
            "installed": inst,
            "skills_used": used_skills,
            "skills_unused_ratio": round(1 - used_skills / inst["skills"], 3) if inst["skills"] else None,
            "contradictions": parse_workflow_spec(repo)["contradictions"],
        },
        "A4_tool_awareness": {
            **parse_tool_awareness(hist, now),
            "unused_levers": parse_workflow_spec(repo)["unused_levers"],
        },
        "A5_delegation": {
            "main_discovery_ops": discover,
            "explore_spawns": explore,
            "discovery_per_delegation": round(discover / (explore + 1), 1),
            "main_image_reads": tr["main_read_image"],
            "main_image_files": tr["main_image_files"],
            "agent_spawns": tr["agent_spawns"],
            "sidechain_cost_ratio": (
                round(lane.get("sidechain", 0) / total_cost, 3)
                if total_cost else None
            ),
        },
        "A6_outcome": parse_outcome_metrics(hist),
        "A7_metacognition": {
            "self_correction_commits": git_self_corrections(repo, a.days),
            "prior_actions_started": None,  # 채점 모델이 직전 리포트와 대조해 채운다
        },

        "raw": {"tool_by_lane": tr["tool_by_lane"], "skill_calls": tr["skill_calls"], "transcripts": tr["files"]},
    }

    text = json.dumps(result, ensure_ascii=False, indent=2)
    if a.out:
        with open(a.out, "w") as f:
            f.write(text + "\n")
        print(f"wrote {a.out}")
    else:
        print(text)


if __name__ == "__main__":
    main()
