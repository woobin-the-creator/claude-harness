### Task 3: 서브에이전트 토큰 귀속 검증

codex PR #19의 제목이 "Fix session attribution"이었다 — 중첩 세션의 정체·계보·role 파싱이 틀려서 서브에이전트 비용이 엉뚱한 곳에 잡히고 있었다. codex 쪽 코드(`codex_sessions.py`)는 우리와 공유하는 게 없어서 **같은 버그가 우리에게도 있는지부터 확인**한다.

플랜 작성 중 소스를 읽고 세운 가설 두 개다. **가설이지 확정이 아니다** — 테스트로 판정한다.

**가설 A — `collect.py`는 서브에이전트 트랜스크립트 파일을 아예 안 읽는다.**
`woobin-harness/skills/capability-audit/scripts/collect.py:85`가 `glob.glob(os.path.join(projects_dir, "*", "*.jsonl"))`를 쓴다. 서브에이전트는 `<proj>/<sessionId>/subagents/agent-*.jsonl`에 쌓이므로 이 non-recursive 패턴에 안 걸린다. 같은 파일의 `tool_by_lane["sidechain"]`(`:102`)은 메인 세션 파일 안에 `isSidechain: true`가 붙은 레코드로만 채워진다. 짚어둘 것 — `waste_scan.py:69`의 주석이 **이미 같은 버그를 자기 쪽에서 고쳤다고 기록**하고 있다("예전 `glob('*/*.jsonl')`은 이걸 통째로 놓쳐서 서브에이전트 비용이 0으로 보였다"). 고칠 때 한쪽만 고친 것으로 보인다.

**가설 B — `waste_scan.py`의 lane 판정이 파일 경로를 무시한다.**
`waste_scan.py:97`은 경로로 `subagents/`를 알아보고 `sid`를 만든다. 그런데 lane은 `:181`의 `ag = req_agent.get(rid)` 하나로 갈리고, `req_agent`는 `:123`에서 **레코드의 `isSidechain` 플래그가 참일 때만** 채워진다. 서브에이전트 트랜스크립트의 레코드에 그 플래그가 없으면, 파일 경로가 이미 서브에이전트라고 말했는데도 비용이 `main` lane으로 간다.

**Files:**
- Modify: `scripts/test-skills.sh` (fixture 추가)
- Modify (가설이 참일 때만): `woobin-harness/skills/capability-audit/scripts/collect.py:85`
- Modify (가설이 참일 때만): `woobin-harness/skills/token-waste-audit/scripts/waste_scan.py:104,123,181`

**Interfaces:**
- Consumes: 없음
- Produces: 없음. 이 태스크는 기존 스크립트의 동작을 고정할 뿐 새 인터페이스를 만들지 않는다.

---

- [ ] **Step 1: 판정용 fixture를 쓴다**

`scripts/test-skills.sh`에 추가한다. 가짜 `projects` 트리를 만들어 두 스캐너를 실제로 돌린다.

서브에이전트 레코드에는 **일부러 `isSidechain`을 넣지 않는다.** 파일 위치만으로 서브에이전트임을 알 수 있어야 한다는 게 이 테스트의 주장이다.

```sh
# 세션 귀속: 서브에이전트 트랜스크립트가 sidechain 으로 잡히는지.
attr_root="$TEST_ROOT/attr/projects/proj-a"
mkdir -p "$attr_root/sess0001/subagents"
attr_usage='{"input_tokens":1000,"output_tokens":500,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}'
printf '%s\n' \
  "{\"type\":\"assistant\",\"requestId\":\"r-main\",\"timestamp\":\"2026-08-26T00:00:00Z\",\"message\":{\"model\":\"claude-opus-5\",\"usage\":$attr_usage,\"content\":[{\"type\":\"tool_use\",\"id\":\"t1\",\"name\":\"Read\",\"input\":{\"file_path\":\"/x\"}}]}}" \
  >"$TEST_ROOT/attr/projects/proj-a/sess0001.jsonl"
printf '%s\n' \
  "{\"type\":\"assistant\",\"requestId\":\"r-sub\",\"timestamp\":\"2026-08-26T00:01:00Z\",\"message\":{\"model\":\"claude-sonnet-5\",\"usage\":$attr_usage,\"content\":[{\"type\":\"tool_use\",\"id\":\"t2\",\"name\":\"Grep\",\"input\":{\"pattern\":\"y\"}}]}}" \
  >"$attr_root/sess0001/subagents/agent-abcdef01.jsonl"

attr_out="$TEST_ROOT/attr/waste.json"
python3 "$ROOT/woobin-harness/skills/token-waste-audit/scripts/waste_scan.py" \
  --projects-dir "$TEST_ROOT/attr/projects" --out "$attr_out" >/dev/null \
  || fail "waste_scan.py failed on the attribution fixture"

python3 - "$attr_out" <<'ATTRPY' || fail "waste_scan.py attributes a subagent transcript to the main lane"
import json, sys
r = json.load(open(sys.argv[1]))
lanes = r.get("cost_by_lane") or {}
side = sum((lanes.get("sidechain") or {}).values())
main = sum((lanes.get("main") or {}).values())
assert side > 0, f"sidechain lane is empty; main={main}"
assert r.get("file_count") == 2, f"expected 2 transcripts, got {r.get('file_count')}"
ATTRPY

attr_collect="$TEST_ROOT/attr/collect.json"
python3 "$ROOT/woobin-harness/skills/capability-audit/scripts/collect.py" \
  --repo "$ROOT" --projects-dir "$TEST_ROOT/attr/projects" --days 3650 \
  --out "$attr_collect" >/dev/null 2>&1 \
  || fail "collect.py failed on the attribution fixture"

python3 - "$attr_collect" <<'ATTRPY2' || fail "collect.py never reads subagents/*.jsonl"
import json, sys
r = json.load(open(sys.argv[1]))
blob = json.dumps(r)
assert "Grep" in blob, "the subagent's Grep call is absent from collect.py output"
ATTRPY2

pass "subagent transcripts are attributed to the sidechain lane"
```

**`collect.py`의 실제 CLI 플래그 이름을 먼저 확인해라.** 위 호출은 `--repo`·`--projects-dir`·`--days`·`--out`을 가정한다. 다르면 그 파일의 `argparse` 정의에 맞춰 고쳐 쓴다(`grep -n add_argument woobin-harness/skills/capability-audit/scripts/collect.py`). 플래그가 없어서 실패하는 건 이 테스트가 잡으려는 버그가 아니다.

- [ ] **Step 2: 돌려서 어느 가설이 참인지 본다**

Run: `./scripts/test-skills.sh`
Expected: 세 갈래 중 하나다. **결과를 그대로 기록하고 진행한다** — 통과했다고 이 태스크를 건너뛰지 마라. 테스트 자체가 산출물이다.

| 결과 | 뜻 | 다음 |
|---|---|---|
| `waste_scan.py attributes a subagent transcript to the main lane` | 가설 B 참 | Step 3 |
| `collect.py never reads subagents/*.jsonl` | 가설 A 참 | Step 4 |
| 둘 다 PASS | 두 가설 모두 거짓 | Step 3·4를 건너뛰고 Step 5로 |

- [ ] **Step 3: 가설 B가 참일 때만 — lane을 파일 경로에서도 판정한다**

`waste_scan.py`에서 파일이 서브에이전트 트랜스크립트인지 이미 아는 지점(`:97` 부근)에 플래그를 잡아 두고, `req_agent` 채우는 지점(`:123`)에서 그 플래그를 OR 조건으로 쓴다.

`:97` 근처, `sid`를 정하는 분기를 이렇게 바꾼다:

```python
        if len(rel) >= 4 and rel[2] == 'subagents':   # <proj>/<sessionId>/subagents/agent-*.jsonl
            sid = rel[1][:8] + '/' + os.path.basename(fp)[:14]
            file_is_sidechain = True
        else:
            sid = os.path.basename(fp)[:8]
            file_is_sidechain = False
```

`:123`의 `req_agent[rid]` 대입을 이렇게 바꾼다:

```python
                        req_agent[rid] = (d.get('attributionAgent') or 'unknown-agent') \
                            if (d.get('isSidechain') or file_is_sidechain) else None
```

`:181`의 `ag = req_agent.get(rid)` 이하는 그대로 둔다 — 이미 `ag`가 참이면 sidechain으로 보낸다.

- [ ] **Step 4: 가설 A가 참일 때만 — collect.py가 서브에이전트 파일도 읽게 한다**

`collect.py:85`를 `waste_scan.py:69`와 같은 재귀 glob으로 바꾼다:

```python
    for path in glob.glob(os.path.join(projects_dir, "**", "*.jsonl"), recursive=True):
```

그리고 `:101`의 lane 판정에 파일 경로 신호를 더한다. 루프 진입부(`:91` `acc["files"] += 1` 직전)에서 한 번 계산한다:

```python
        rel_parts = os.path.relpath(path, projects_dir).split(os.sep)
        file_is_sidechain = len(rel_parts) >= 4 and rel_parts[2] == "subagents"
```

`:101-102`를 바꾼다:

```python
                side = bool(d.get("isSidechain")) or file_is_sidechain
                lane = "sidechain" if side else "main"
```

⚠ `:118`의 `if side: continue`가 그 아래 메인 전용 집계를 건너뛰게 돼 있다. 재귀 glob으로 파일이 늘면 이 분기를 타는 레코드가 늘어난다 — **의도한 동작이다**(서브에이전트 활동이 메인 지표를 오염시키면 안 된다). 다만 `sidechain_cost_ratio`(`:330`) 같은 파생 지표의 분모가 달라지므로, `docs/scores/SCORES.md`의 과거 점수와 직접 비교하면 안 된다. Step 6에서 이 사실을 기록한다.

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run: `./scripts/test-skills.sh`
Expected: PASS — `✓ subagent transcripts are attributed to the sidechain lane`

- [ ] **Step 6: 판정 결과를 스킬 본문에 남긴다**

Step 2에서 어느 쪽이 나왔든, `woobin-harness/skills/capability-audit/SKILL.md`의 지표 해석 절에 한 문단을 추가한다. 아래 두 문장 중 **실제로 일어난 쪽만** 쓴다:

- 수정한 경우: `2026-08-26 이전 리포트는 서브에이전트 비용을 메인 lane에 합산했다. 그 이전 점수와 sidechain_cost_ratio를 직접 비교하지 마라 — 분모가 다르다.`
- 수정 안 한 경우: `2026-08-26에 서브에이전트 귀속을 fixture로 검증했다(scripts/test-skills.sh). 파일 경로가 subagents/ 인 트랜스크립트는 레코드에 isSidechain 이 없어도 sidechain 으로 잡힌다.`

`docs/scores/SCORES.md`의 **기존 점수는 고치지 않는다.** 그때의 측정값이다.

- [ ] **Step 7: 커밋**

```bash
git add scripts/test-skills.sh woobin-harness/skills/capability-audit woobin-harness/skills/token-waste-audit
git commit -m "fix(audit): 서브에이전트 트랜스크립트 귀속을 파일 경로로도 판정한다"
```

수정할 게 없었으면 메시지를 `test(audit): 서브에이전트 귀속 동작을 fixture로 고정한다`로 바꾼다.
