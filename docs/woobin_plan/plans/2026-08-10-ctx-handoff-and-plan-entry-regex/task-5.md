# Task 5: 문서·메타데이터 동기화

**선행:** Task 1~4가 전부 끝나 있어야 한다. 이 태스크는 앞 태스크들의 산출물 이름(훅 파일명·스킬명·환경변수명·발화 조건)을 문서로 옮긴다.

문서가 4종이라 한 곳만 고치면 조용히 갈라진다. **전부 한 커밋**으로 간다.

**Files:**
- Modify: `docs/workflow-spec.md` (§3 R13 신설, §4 훅 표·손잡이·개수, §8 열린 항목)
- Modify: `docs/workflow.html` ("유일한 세션 경계" → "필수" + 자동 경계 절 신설)
- Modify: `README.md:29-31`
- Modify: `woobin-harness/.claude-plugin/plugin.json:3,4`
- Modify: `.claude-plugin/marketplace.json:11`
- Modify: `home/HARNESS-LOG.md`

**Interfaces:**
- Consumes: Task 1~4의 결과물
- Produces: 없음

- [ ] **Step 1: `docs/workflow-spec.md` §3 끝(R12 뒤, `## 4. 구성요소 인벤토리` 앞)에 R13을 추가**

```markdown
### R13 — 300k 초과 세션 자동 핸드오프

**기전** `ctx-handoff-stop.sh` (Stop) — 턴이 `CTX_HANDOFF_THRESHOLD`(기본 300k) 이상에서 끝나면
`exit 2`로 모델을 깨워 `handoff` 스킬로 핸드오프 문서를 `~/.claude/idle-handoffs/<sid>.md`에 쓰게 하고
`/clear`를 안내한다. 세션 1회(마커) + `stop_hook_active` 가드.

**근거** 2026-08-10, 7일 전수(412세션 / $852.97). 300k를 넘긴 뒤에도 요청이 이어진 세션 **10건**,
그 구간이 45k floor 대비 초과로 낸 cache read가 **$88.47 = 주간 총지출의 10.4%**.
상위: `ba72fbd2` $17.32(max 430k) · `1a0a81a5` $13.61 · `c1d660bd` $12.62(max 472k).
`ctx-warn-statusline.sh`가 같은 임계를 이미 **표시**하고 있었다 — #3의 결론("인지 수단만으로는 못 막는다")이
5주 뒤에도 그대로 참인 것을 재확인한 셈이다.

**설계 핵심** 알리지 않고 **대체 경로를 만들어 준다**. 이 하네스에서 ✅로 재측정된 개입(#1·#2)은
전부 이 형태였고, 경고만 넣은 #3은 △였다. 문서 계약은 훅이 아니라 `handoff` 스킬이 단일 소유한다 —
훅이 2개(`idle-handoff-stop.sh`·`ctx-handoff-stop.sh`)라 계약을 인라인하면 한쪽만 고쳐져 갈라진다(#16).

**대가** 깨우는 턴 1회가 300k 컨텍스트에서 돌아 약 $0.15~0.30. 그리고 핸드오프 문서가
자기완결적이지 않으면 새 세션이 되묻느라 절약분이 날아간다(R1과 같은 실패 모드).

**무효화 조건**
- E1이 거짓(캐시 리드 재청구가 없거나 무료)
- **compaction이 무손실이 됨** — R1과 같은 이유로, 이 규칙의 정체도 "compaction이 할 일을 미리 하는 것"이다
- 하네스가 세션 재시작 없이 컨텍스트를 선택적으로 리셋하는 수단을 제공
- 재측정에서 핸드오프 문서가 만들어졌는데도 사용자가 `/clear`하지 않는 비율이 높음
  → 그때는 개입 형태를 block(토큰 0 강제 정지)으로 바꾸는 게 맞다
```

- [ ] **Step 1-bis: §3 R13 뒤에 R14를 추가**

```markdown
### R14 — 하네스 문서 동기화를 기계가 센다

**기전** `scripts/check-harness-docs.sh` — 훅·에이전트·스킬의 **실제 개수**를 세어 README·
`plugin.json`·`marketplace.json`·이 문서(§4)의 선언값과 대조하고, 훅·에이전트 파일이 §4 인벤토리에
등재됐는지 확인하고, `woobin-harness/` 변경 시 문서 동반 수정 여부를 git diff로 판정한다.
짝: `harness-doc-sync-guard.sh` (PostToolUse:Edit|Write|MultiEdit) — 이 레포에서 `woobin-harness/`를
고치면 검사기를 돌려 결과를 additionalContext로 주입한다. 세션 1회, 차단하지 않는다.

**근거** 2026-08-10. `CLAUDE.md`의 "고칠 때 같이 고쳐야 하는 것"은 문서 4종을 **이미 명시하고 있었는데**,
R13 플랜을 쓰는 과정에서 `docs/workflow.html`이 빠졌고 사용자가 물어봐서 발견됐다. 같은 시점에
이 문서의 스킬 개수가 41개(실제 42개)로 이미 갈라져 있었다 — **산문 체크리스트가 이미 두 번 실패한 상태**였다.
R12(`stop-warning-ack-guard.sh`)가 만든 패턴 — "프롬프트로 부탁이 아니라 실제로 검사하는 결정론적 게이트" —
를 문서 동기화에 적용한 것이다(R12 무효화 조건의 "이 패턴은 다른 훅에도 적용 가능한데 안 쓰고 있다"가 이걸로 해소된다).

**설계 핵심** 실패(✗)와 경고(⚠)를 나눈다. 훅을 **추가**하면 사람용 요약의 서술이 바뀌므로
`workflow.html` 누락은 실패, 훅 **내용만** 수정하면 경고다. 모든 수정에 `workflow.html`을 요구하면
오탐이 쌓여 무시당하고, 그게 산문 규칙이 죽은 것과 같은 경로다.

**대가** 서식이 바뀌면 검사기의 정규식도 같이 고쳐야 한다(문구를 못 찾으면 ⚠로 알린다).
그리고 검사기 자체가 새로운 소유자다 — 개수 문구의 서식을 바꿀 때 여기도 봐야 한다.

**무효화 조건**
- 개수·인벤토리 문구가 문서에서 사라짐(자동 생성으로 바뀜) → 검사기의 해당 검사만 제거
- CI가 같은 검사를 돌리게 됨 → PostToolUse 짝은 중복이므로 제거하고 스크립트만 남긴다
- 재측정에서 ⚠ 오탐이 잦아 사용자가 무시하기 시작함 → 경고 항목을 줄이거나 실패로 올린다
```

- [ ] **Step 2: §4 훅 표를 갱신**

- 소제목 `### 훅 9개` → `### 훅 11개`
- 표의 `idle-handoff-stop.sh` 행 **바로 아래**에 추가:

```markdown
| `ctx-handoff-stop.sh` | Stop | 턴 종료 시 ctx ≥300k | `exit 2` 재기동, 세션 1회 | R13 |
```

- 표의 **맨 아래**에 추가:

```markdown
| `harness-doc-sync-guard.sh` | PostToolUse:Edit\|Write\|MultiEdit | 이 레포의 `woobin-harness/` 수정 | additionalContext, 세션 1회 | R14 |
```

- "조정 손잡이" 코드블록의 `IDLE_HANDOFF_POLL=60      IDLE_HANDOFF_FRESH=300` 줄 아래에 추가:

```
CTX_HANDOFF_THRESHOLD=300000
```

- [ ] **Step 3: §4의 스킬 개수를 실제 값으로 정정**

`### 스킬 41개`(드리프트 상태)를 실제 개수로 고친다. Task 2에서 `handoff`를 추가했으므로 먼저 센다.

Run: `ls -d woobin-harness/skills/*/ | wc -l`
Expected: `43`. 다른 숫자가 나오면 **그 숫자**를 쓰고 README·plugin.json·marketplace.json도 같은 값으로 맞춘다.

`### 스킬 41개` → `### 스킬 43개`. 같은 절의 "파이프라인에 직접 물린 것" 목록에 `handoff`를 추가한다(`close-session` 옆).

- [ ] **Step 4: §8 열린 항목에 `[B]` 미수정 사실을 기록**

`docs/workflow-spec.md`의 §8에서 기존 항목 1개의 서식을 먼저 확인한 뒤(3줄이면 충분), 같은 형식으로 추가한다.

```markdown
- **`sdd-orchestrator-edit-guard.sh` [B]는 플랜 문서 비중이 큰 세션에서 발화하지 않는다 — 미수정.**
  카운터 증가가 플랜 경로 제외(`exit 0`) 뒤에 있어 플랜 쓰기가 카운트되지 않는다.
  2026-08-10 7일 전수: ctx ≥150k 세션 41건 중 현행 카운터로 발화 가능 21건, 플랜 문서를 포함시켜야
  발화하는 건 **2건**. 2/41을 위해 카운터를 넓히면 정당한 플랜 세션마다 deny가 뜨는 오탐 비용이 더 크다고
  판단해 그대로 뒀다. 해당 2건 중 하나가 그 주 2위 세션(`c1d660bd` $42.89, max 472k)이지만,
  그 세션의 원가 동인은 편집이 아니라 컨텍스트 자체라 **R13이 겨눈다.**
```

- [ ] **Step 5: `docs/workflow.html`의 "유일한 세션 경계" 서술을 정정**

이건 개수 누락이 아니라 **서술이 거짓이 되는** 항목이다. 현재 이 파일은 「◆ 유일한 세션 경계」 절에서
"플랜 저장 → `/exit` → 모드 플래그로 재런치"가 유일한 경계라고 못박고 있다. R13이 들어가면
300k 초과 시 자동 핸드오프라는 **두 번째 경계**가 생긴다.

먼저 해당 절을 찾는다.

Run: `grep -n "유일한 세션 경계" docs/workflow.html`

그 절의 제목을 `◆ 필수 세션 경계`로 바꾸고, 절 끝(`마무리` 절이 시작하기 전)에 아래 블록을 같은 서식으로 추가한다.
주변 마크업(클래스명·태그 구조)을 그대로 흉내내고, 새 클래스를 만들지 않는다.

```html
<h3>◆ 자동 세션 경계 (300k)</h3>
<p>턴이 <strong>300k 컨텍스트</strong>를 넘겨 끝나면 <code>ctx-handoff-stop.sh</code>가 모델을 깨워
<code>handoff</code> 스킬로 핸드오프 문서를 <code>~/.claude/idle-handoffs/&lt;sid&gt;.md</code>에 쓰게 한다.
그 뒤 <code>/clear</code>하고 그 문서를 읽고 이어가면 된다. 세션당 1회만 발화한다.</p>
<p>계획된 경계는 위의 <em>필수</em> 하나뿐이지만, 이건 <em>넘겼을 때 자동으로</em> 생기는 경계다.
2026-08-10 7일 전수에서 300k를 넘긴 뒤에도 계속 돈 세션이 10건이었고 그 초과분만 $88.47이었다.</p>
```

검증: 브라우저나 `open docs/workflow.html`로 열어 레이아웃이 깨지지 않았는지 눈으로 확인한다.

Run: `grep -c "유일한 세션 경계" docs/workflow.html`
Expected: `0` (제목을 바꿨으므로).

- [ ] **Step 6: README·plugin.json·marketplace.json의 개수와 버전을 맞춘다**

```bash
sed -i '' 's|hooks/\*\.sh                    9개|hooks/*.sh                    11개|' README.md
sed -i '' 's|skills/<name>/SKILL.md        42개|skills/<name>/SKILL.md        43개|' README.md
sed -i '' 's/훅 9개, 에이전트 4개, 스킬 42개/훅 11개, 에이전트 4개, 스킬 43개/' \
  woobin-harness/.claude-plugin/plugin.json .claude-plugin/marketplace.json
sed -i '' 's/"version": "1.1.0"/"version": "1.2.0"/' woobin-harness/.claude-plugin/plugin.json
```

- [ ] **Step 7: 치환이 전부 먹었는지 확인**

Run:
```sh
grep -n "훅 9개\|스킬 42개\|스킬 41개" README.md woobin-harness/.claude-plugin/plugin.json \
  .claude-plugin/marketplace.json docs/workflow-spec.md; \
grep -n '"version"' woobin-harness/.claude-plugin/plugin.json
```
Expected: 첫 `grep`은 출력 없음(종료코드 1). 두 번째는 `"version": "1.2.0"`.

- [ ] **Step 8: `home/HARNESS-LOG.md`에 #17을 추가**

요약 표 마지막 행(`| 16 | ... |`) 아래에 추가:

```markdown
| 17 | 08-10 | 300k 초과 세션이 계속 돎 + 진입 가드가 어구 변형에 죽음 + 훅이 없는 스킬을 부름 + 문서 4종 동기화가 산문이라 샘 | handoff 스킬·ctx 핸드오프 훅 신설, 진입 정규식 확장, 문서 동기화 검사기 | (신규) |
```

문서 맨 끝의 `## 규율` 절 **앞에** 상세 절을 추가한다:

```markdown
## 17. 300k 자동 핸드오프 + 플랜 진입 정규식 + handoff 스킬 실체화 (2026-08-10)

**발단**: PR #219(pholex) 세션 분석 issue #1을 검증하다가, 두 외부 분석 모두 토큰 수로만 순위를 매겨
실제 지출 순위와 어긋났다는 걸 발견했다. `requestId` dedup 후 달러로 환산하니(52.5M tok / **$31.21**)
1위가 서브에이전트가 아니라 **opus로 238k까지 자란 탐색·플랜 세션 MAIN-1($11.89, 38%)** 이었다.
그 세션을 "플랜 문서 작성하자" 프롬프트로 잘라보니 인터뷰·집필은 몇십 센트고, 비싼 건 **138k 잔재 위에서
돌린 39회 Bash 탐색**이었다(#15가 이미 규정한 항목).

**문제 A (정규식 드리프트)**: 그 진입 프롬프트가 `플랜 문서 작성하자`였는데
`plan-session-boundary-guard.sh`의 트리거가 `플랜 작성`(붙어 있어야 매치)이라 발화하지 않았다.
ctx 138k로 임계(120k)는 넘긴 상태였다. **"문서" 두 글자가 훅을 죽였다** — CLAUDE.md가 경고한
"트리거 용어가 바뀌면 훅이 조용히 죽는다"가 자연스러운 어투 변화만으로 발생한 사례.
7일 전수에서 플랜 진입 3건 중 1건 미발화, 그 구간 $7.22(절감 상한 ~$3.6).

**문제 B (인지 수단의 한계 재확인)**: `waste_scan.py --days 7` 전수(412세션 / $852.97)에서
300k를 넘긴 뒤에도 요청이 이어진 세션이 10건, 그 초과분 cache read만 **$88.47(총지출의 10.4%)**.
`ctx-warn-statusline.sh`가 200k/300k를 이미 표시하고 있었다 — #3의 △ 판정이 5주 뒤에도 참이었다.

**문제 C (없는 스킬 호출)**: `idle-handoff-stop.sh`가 80·85행에서 `handoff` 스킬을 두 번 권하는데
그 스킬이 존재하지 않았다(플러그인·`~/.claude/skills/` 양쪽 확인). #16과 같은 드리프트이고
`claude plugin validate`로는 안 잡힌다.

**수단**:
- `handoff` 스킬 신설. 공개 스킬 3종(ykdojo·thepushkarp·REMvisual)을 검토했으나 전부 저장 경로가
  레포 안에 **고정**이라 훅이 지정하는 `~/.claude/idle-handoffs/<sid>.md`와 맞지 않았다.
  섹션 설계는 REMvisual을 참고했다(기각안 필수 — "Failed approaches are the most expensive thing to rediscover").
- `ctx-handoff-stop.sh` 신설(Stop, ctx ≥300k, `exit 2` → handoff 스킬 → `/clear`).
  `idle-handoff-stop.sh`(#1)의 "대체 경로를 만들어 준다" 형태를 재사용하되 asyncRewake·폴링을 빼고
  재주입 방지를 세션 1회 마커 + `stop_hook_active`로 바꿨다(#1의 mtime 방식은 **반복되는** 유휴 국면을
  판정하려고 도입한 것이라 여기엔 과하고, 마커 레이스 사고의 원인도 그 반복성이었다).
- **문서 계약은 스킬이 단일 소유한다.** 훅 2개가 각자 계약을 갖고 있으면 한쪽만 고쳐져 갈라진다 —
  #16의 문제 A와 정확히 같은 구조라 처음부터 피했다.
- `plan-session-boundary-guard.sh` 정규식을 `플랜.{0,8}작성|계획.{0,8}작성` 형태로 확장.
- **`scripts/check-harness-docs.sh` + `harness-doc-sync-guard.sh` 신설(R14).** 이 플랜을 쓰는 도중
  `docs/workflow.html`이 빠진 걸 사용자가 물어봐서 발견했고, 같은 시점에 workflow-spec의 스킬 개수가
  이미 41개(실제 42개)로 갈라져 있었다 — **CLAUDE.md의 산문 체크리스트가 이미 두 번 실패한 상태**였다.
  규율 2에 따라 개수·인벤토리·동반 수정 판정을 스크립트로 옮겼다. R12가 만든 "실제로 검사하는
  결정론적 게이트" 패턴의 두 번째 적용이다(R12 무효화 조건에 적힌 미적용 항목이 이걸로 해소).

**기각**: `[B]` 대량 편집 가드의 카운터 위치 수정 — 7일 전수에서 ctx ≥150k 세션 41건 중 21건은
현행 카운터로도 임계에 도달하고, 플랜 문서를 포함시켜야 달라지는 건 2건뿐이라 오탐 비용이 더 크다고
판단했다(→ workflow-spec §8).

**재측정**: 다음 audit에서 ⓪ `check-harness-docs.sh`가 ✗ 0개인지 ① `ctx-handoff-stop.sh` 발화 건수 ② 발화 후 실제로 `/clear`가 뒤따른 비율
③ 300k 초과 구간 비용을 이번 기준선($88.47/7일)과 비교 ④ 플랜 진입 가드 미발화 건수(기준선 1건/7일).
②가 낮으면 개입을 block으로 올린다.
```

- [ ] **Step 9: 검사기로 동기화를 증명한다 — 이 플랜의 최종 게이트**

Task 4에서 만든 검사기를 돌린다. 사람이 눈으로 세지 않는다.

Run: `sh scripts/check-harness-docs.sh; echo "exit=$?"`
Expected: `✗`가 하나도 없고 `exit=0`.

`✗`가 남아 있으면 그 항목을 고치고 다시 돌린다 — **`exit=0`이 되기 전에는 커밋하지 않는다.**
`⚠`는 판단 항목이라 남아 있어도 되지만, 왜 남겼는지 커밋 메시지에 한 줄 적는다.

- [ ] **Step 10: 커밋**

```bash
git add docs/workflow-spec.md docs/workflow.html README.md home/HARNESS-LOG.md \
        woobin-harness/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "docs: R13·R14 신설 + 훅 11개·스킬 43개 동기화 + HARNESS-LOG #17"
```

- [ ] **Step 11: 설치본에 반영하고 재시작**

```bash
claude plugin marketplace update woobin-harness
claude plugin update woobin-harness@woobin-harness   # 짧은 이름은 "not found"로 실패한다
```
그리고 Claude Code를 재시작한다(`update`가 "Restart to apply"를 알려준다).
**버전을 안 올리면 레포를 고쳐도 설치본은 옛날 그대로다** — Step 5에서 1.2.0으로 올린 이유.

- [ ] **Step 12: 새 훅이 실제로 물렸는지 확인**

재시작 후 아무 세션에서:

Run: `ls ~/.claude/plugins/cache/*/woobin-harness/1.2.0/hooks/ctx-handoff-stop.sh`
Expected: 파일 존재. 없으면 버전 디렉터리를 확인하고 `claude plugin update`를 다시 돌린다.
