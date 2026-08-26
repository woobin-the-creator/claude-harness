### Task 7: 문서 동기화 · 이력 기록 · 전체 검증

Task 1~6이 각자 자기 문서를 고쳤다. 이 태스크는 **레포 전체가 일관된지** 확인하고, 왜 고쳤는지를 이력에 남기고, 검증 4종을 전부 돌린다.

**Files:**
- Modify: `home/HARNESS-LOG.md` (새 항목 추가 — 기존 항목은 건드리지 않는다)
- Modify (필요할 때만): `docs/workflow-spec.md`, `README.md`, `docs/workflow.html`

**Interfaces:**
- Consumes: Task 1~6의 커밋 전부. 버전은 Task 1이 `1.14.0`으로 올려 뒀다.
- Produces: 없음

---

- [ ] **Step 1: 현재 상태를 센다**

```bash
ls woobin-harness/hooks/*.sh | wc -l          # 기대: 12
ls -d woobin-harness/skills/*/ | wc -l        # 기대: 20
ls woobin-harness/agents/*.md | wc -l         # 기대: 4
jq -r '.version' woobin-harness/.claude-plugin/plugin.json   # 기대: 1.14.0
jq -r '.version' woobin-harness/.codex-plugin/plugin.json    # 기대: 1.14.0
```

숫자가 기대와 다르면 어느 태스크가 빠졌는지부터 찾아라. 문서를 실제 값에 맞추지 말고, 실제 값이 왜 다른지를 먼저 밝혀라.

- [ ] **Step 2: `home/HARNESS-LOG.md`에 항목을 추가한다**

파일 끝의 `## 규율 (이 이력에서 반복 확인된 것)` 절 **앞**에 새 항목을 넣는다. 번호는 마지막 항목 +1이다(`grep -n '^## [0-9]' home/HARNESS-LOG.md | tail -1`로 확인).

기존 항목의 서식(`**계기**` / `**조치**` / `**교훈**`)을 그대로 따르고, 아래 사실만 쓴다. **없는 측정치를 지어내지 마라:**

- **계기** — codex-harness가 2026-08-21~08-25에 머지한 PR 6건 중, claude-harness에 값이 있는 것을 골라 이식했다. 6건 중 PR #11은 claude-harness #22·#9·#19의 **역이식**이라 제외했다(원본이 이쪽에 있다).
- **조치** — 훅 1개 신설(`plugin-update-guard.sh`), `pr-demo-video` 검증 프레임 3장 → contact sheet 1장, 서브에이전트 귀속 fixture 추가, `grill-me` 원장 `근거` 열 + 스펙 파일 형식 5줄, `explain` 분리(신설 + `explain-in-html` 개명), 플랜 산출물 영문화.
- **기각** — `spec_contract.py` 검증기·계약 문서·append-only 훅. 파일 저장이 폴백 경로라 값은 가끔인데 유지 비용은 상시고, 게이트를 세우면 미결을 가정 절로 밀어 통과시키는 우회로가 생긴다. 검증기는 형식만 보지 정직함은 못 본다.
- **교훈 1** — 개수 하드코딩이 또 갈라져 있었다. 2026-08-21에 28 → 19로 고쳤는데 `README.md:11,12,110`과 `docs/workflow.html:405`의 "44개"가 남아 있었다. `check-harness-docs.sh`의 정규식이 README에서는 `SKILL\.md +[0-9]+개` 한 패턴만 보기 때문에 그 네 곳은 검사 밖이었다. **미조치 과제가 재발한 두 번째 증거다** — 개수를 세는 방식으로 옮기는 걸 여전히 후속 과제로 남긴다.
- **교훈 2** — 서브에이전트 귀속에서 `waste_scan.py:69`가 자기 쪽 non-recursive glob 버그를 고치고 주석까지 남겼는데, `collect.py:85`에는 같은 패턴이 그대로 남아 있었다. 같은 버그를 두 파일이 공유할 때 한쪽만 고치면 나머지는 **주석이 고쳤다고 말하고 있어서** 더 안 보인다. (Task 3의 실제 판정 결과에 맞춰 이 문단을 조정한다 — 가설이 거짓이었으면 그렇게 적어라.)

Task 3의 결과가 "두 가설 모두 거짓"이었으면 교훈 2를 그 사실로 바꿔 쓴다.

- [ ] **Step 3: 문서 동기화 게이트**

Run: `./scripts/check-harness-docs.sh`
Expected: `동기화됨.`

이제 `⚠ home/HARNESS-LOG.md 에 항목이 없다` 경고도 사라져야 한다(Step 2에서 넣었다). `✗`가 남으면 메시지가 파일과 숫자를 정확히 알려준다.

- [ ] **Step 4: frontmatter 검증**

Run: `claude plugin validate ./woobin-harness`
Expected: 통과.

- [ ] **Step 5: 훅 fixture**

Run: `./scripts/test-hooks.sh`
Expected: `plugin-update-guard drift/healthy/absent branches` 포함 전부 통과.

**예외 1건** — `stale-branch-guard: marker missing` 실패는 이 플랜과 무관한 기존 결함이고 `home/HARNESS-LOG.md` #26에 기록돼 있다. 여기서 고치지 마라. 다만 **실패했다는 사실을 최종 보고에 그대로 적어라** — 통과했다고 말하면 안 된다.

- [ ] **Step 6: 스킬 fixture**

Run: `./scripts/test-skills.sh`
Expected: 전부 통과. `20 packaged skills`가 찍혀야 한다.

- [ ] **Step 7: Codex 검증**

Run: `./scripts/validate-codex.sh`
Expected: 통과.

이 검사는 임시 `CODEX_HOME`에 플러그인을 설치해 실제 `codex debug prompt-input`까지 돈다. `codex` CLI가 없으면 그 사실을 보고에 적고 넘어간다 — 없는 걸 통과했다고 하지 마라.

- [ ] **Step 8: 새 머신 설치 dry-run**

Run:
```bash
DRY_RUN=1 ./bootstrap.sh
DRY_RUN=1 ./bootstrap-codex.sh
```
Expected: 오류 없이 무엇을 건드리는지 나열한다. 새 스킬 `explain`과 개명된 `explain-in-html`이 둘 다 보여야 한다.

- [ ] **Step 9: 커밋**

```bash
git add home/HARNESS-LOG.md docs README.md
git commit -m "docs(harness): codex-harness 0821~0826 이식 이력과 문서 동기화"
```

- [ ] **Step 10: 최종 보고**

무엇을 했고 무엇이 남았는지 사실대로 적는다. 최소한 아래 넷을 포함한다:

1. Task 3의 실제 판정 — 가설 A·B 중 무엇이 참이었나, 수정했나 테스트만 남겼나
2. `stale-branch-guard: marker missing`이 여전히 실패하는지
3. `validate-codex.sh`를 실제로 돌렸는지, 아니면 `codex` CLI가 없어 건너뛰었는지
4. 후속 과제 — 개수 하드코딩을 세는 방식으로 옮기는 것(`HARNESS-LOG` #27에서 미조치, 이번에 재발 확인)

설치본을 실제로 갱신하는 것은 **사용자가 한다.** 이 세션에서 `claude plugin update`를 돌리지 마라. 보고 끝에 절차만 적어라:

```bash
claude plugin marketplace update woobin-harness
claude plugin update woobin-harness@woobin-harness   # 짧은 이름은 not found 로 실패한다
# 그리고 Claude Code 재시작
```
