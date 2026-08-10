### Task 5: 사람용 요약 · 이력 · 버전 동기화

**Files:**
- Modify: `docs/workflow.html` — §01 흐름에 스텝 1개 추가 + §03 "어느 모드에서도 지키는 것"에 카드 1개 추가
- Modify: `home/HARNESS-LOG.md` — `## 20.` 항목 추가 + 의존 관계 표에 `gh` 행 추가
- Modify: `woobin-harness/.claude-plugin/plugin.json` — `version` `1.3.0` → `1.4.0`

**Interfaces:**
- Consumes: task-1의 `R15`, task-2의 `O14`.
- Produces: 없음. task-6이 이 파일들의 변경 사실만 검사한다.

**왜 세 파일이 한 태스크인가:** `scripts/check-harness-docs.sh`가 이 셋을 **하나의 동반 수정 묶음**으로 판정한다. 따로 쪼개면 중간 상태가 항상 검사 실패다.

- [ ] **Step 1: `plugin.json` version 올리기**

```bash
grep -n '"version"' woobin-harness/.claude-plugin/plugin.json
```
`"version": "1.3.0"` → `"version": "1.4.0"`으로 바꾼다. **`description`의 개수 문구(훅 11개, 에이전트 4개, 스킬 25개)는 건드리지 마라** — 개수가 안 바뀌었다.

```bash
jq -r '.version' woobin-harness/.claude-plugin/plugin.json
```
기대: `1.4.0`

- [ ] **Step 2: `workflow.html` §01에 스텝 추가**

`<h3>구현 <span class="tag">모드대로</span></h3>`가 있는 `<li class="step">` **앞**에 아래 `<li>`를 넣는다(킥오프 다음, 구현 앞):

```html
  <li class="step">
    <div class="step-card">
      <h3>구현 시작 = 브랜치 + draft PR <span class="tag">R15</span></h3>
      <p>첫 턴에 <code>plan/&lt;name&gt;</code> 브랜치를 만들고 <b>플랜 문서를 첫 커밋</b>으로 올려 <code>plan-wip</code> 라벨이 붙은 <b>draft PR</b>을 연다. 레이어가 끝날 때마다 <b>커밋 → 리뷰 → push</b>.</p>
      <p class="why">겨누는 건 컨텍스트가 아니라 <b>사용량 하드 컷</b>이다. 그 순간엔 모델이 도구를 못 쓰니 방어가 미리 배치돼 있어야 한다. 하드 컷은 파일을 지우지 않는다 — 잃는 건 <b>"어디까지 했는지"라는 기록</b>이라 커밋은 보존이 아니라 <b>라벨링</b>이고 레이어 해상도로 충분하다. 핸드오프 문서는 세션 id로 저장돼 컷 뒤엔 못 찾지만, PR은 <code>gh pr list --label plan-wip</code>로 찾힌다.</p>
    </div>
  </li>
```

- [ ] **Step 3: `workflow.html` §03에 카드 추가**

`<div class="rules">` 안, `<div class="rule info">`(“확인이 필요하면 서브에이전트는 못 묻는다”) **앞**에 넣는다:

```html
  <div class="rule yes">
    <h4>✓ 커밋은 리뷰 전, push는 리뷰 후</h4>
    <p>레이어 끝의 리뷰가 그 세션에서 <b>토큰을 가장 많이 쓰는 단계</b>라 하드 컷 확률이 가장 높다. 커밋을 리뷰 뒤로 미루면 레이어 전체가 가장 위험한 순간에 무기록으로 노출된다. 머지는 <b><code>--squash</code></b> — 레이어 커밋은 개별로 테스트를 통과하지 않을 수 있어 merge commit이면 <code>git bisect</code>가 못 믿을 것이 된다.</p>
  </div>
```

- [ ] **Step 4: `workflow.html` 구조 검증**

```bash
grep -c "plan-wip" docs/workflow.html
python3 -c "import html.parser,sys
class P(html.parser.HTMLParser):
    def __init__(s): super().__init__(); s.st=[]
    def handle_starttag(s,t,a):
        if t not in ('meta','br','hr','img','link','input'): s.st.append(t)
    def handle_endtag(s,t):
        if s.st and s.st[-1]==t: s.st.pop()
        elif t in s.st: print('불일치:',t,'열린 태그:',s.st[-3:]); s.st.remove(t)
p=P(); p.feed(open('docs/workflow.html').read()); print('남은 열린 태그:',p.st[-5:] if p.st else '없음')"
```
기대: 첫째 → **2 이상**. 둘째 → `불일치:` 줄이 없고 `남은 열린 태그: 없음`. 불일치가 나오면 `<li>`/`<div>` 짝을 다시 세라.

- [ ] **Step 5: `HARNESS-LOG.md`에 `## 20.` 항목 추가**

`## 19. 미사용 스킬 18개 삭제 — 다운로드 출처만 (2026-08-10)` 절의 **끝**, `## 규율 (이 이력에서 반복 확인된 것)` **앞**에 넣는다:

```markdown
## 20. 사용량 하드 컷은 R13이 못 덮는다 (2026-08-10)

**발단**: 플랜 구현 중 세션이 끊기는 일이 반복됐다. 처음엔 R13(300k 자동 핸드오프)이 겨누는 것과
같은 문제로 보였는데, 확인해보니 **컨텍스트 창이 아니라 사용량 하드 컷**이었다. 둘은 커버가 갈린다 —
R13은 Stop 훅이라 **턴이 끝날 때만** 발화하고, 하드 컷은 턴 도중에 온다.

**문제 A (사전 경고가 불가능)**: `statusline/ctx-warn-statusline.sh`는 컨텍스트만 센다.
훅 입력에도 사용량 잔량이 없다. 즉 R13이 쓴 수단(임계에서 깨워 대체 경로를 만들어 준다)을
**여기서는 쓸 수 없다.** 그래서 이 규칙은 조건부가 아니라 무조건 절차다.

**문제 B (핸드오프 문서를 못 찾는다)**: R13은 문서를 `~/.claude/idle-handoffs/<session_id>.md`에
저장한다. 하드 컷당한 세션의 id를 새 세션은 모르므로 **컷 뒤엔 그 문서에 도달할 수 없다.**
회복 진입점이 사전지식 없이 찾히는 곳에 있어야 한다는 요구가 여기서 나왔다.

**수단**: R15 신설. `plan/<name>` 브랜치 + 플랜 문서 첫 커밋 + `plan-wip` draft PR을 구현 첫 턴에
만들고, 레이어마다 **커밋 → 리뷰 → push**. 훅은 **하나도 추가하지 않았다** — 전달 경로가 이미 있다
(모드 파일은 킥오프 훅이 읽게 만든다). 기존 훅 수정 1건: `stale-branch-guard.sh`가 플랜 브랜치에서
문구를 하향한다(면제가 아니라 등급 하향 — 경고·마커·ack 게이트 유지).

**설계 판단 — 하드 컷은 파일을 지우지 않는다.** 워킹 트리는 디스크에 남는다. 처음엔 task 단위 커밋을
생각했는데(손실 상한 = 커밋 간격), 그건 파일이 날아가는 실패를 가정한 것이었다. 실제로 잃는 건
**"어디까지 했는지"라는 기록**이라 커밋의 역할은 보존이 아니라 **라벨링**이고 레이어 해상도로 충분하다.
task 단위는 ②a에서 git 출력이 오케스트레이터 floor에 쌓여 매 요청에 재청구되는 대가까지 있었다.

**대가**: 버리기가 되돌리기로 바뀐다(§3 R15 참조). 이 교환의 판정은 **하드 컷 빈도 vs 방향 오류 빈도**이고
아직 세지 않았다 — §8 O14. 그리고 R13의 유인을 약화시킬 수 있다: 끊겨도 안 아프면 `/clear`를 미룬다.
재측정에서 "핸드오프 문서를 썼는데도 `/clear` 안 함" 비율이 오르면 **원인 후보로 이 규칙을 먼저 보라.**

**재측정**: 아직. O14를 먼저 세야 판정 기준선이 생긴다.
```

- [ ] **Step 6: 의존 관계 표에 `gh` 행 추가**

`## ⚠️ 훅 ↔ superpowers 의존 관계 (제거 시 주의)` 절의 표 — 마지막 행(`| \`subagent-model-default.sh\` / ...`)** 아래**에 붙인다:

```markdown
| `stale-branch-guard.sh` (R15 하향 분기) | **`gh` CLI + `plan-wip` 라벨 이름** | 무관. 단 `gh`가 없거나 미인증이면 조용히 **기존(하향 전) 문구**로 돌아간다 — 라벨 이름을 바꾸면 하향이 영구히 안 걸린다 |
```

- [ ] **Step 7: 검증**

```bash
grep -c "^## 20\." home/HARNESS-LOG.md
grep -c "plan-wip" home/HARNESS-LOG.md
jq -r '.version' woobin-harness/.claude-plugin/plugin.json
```
기대: `1` / **2 이상** / `1.4.0`

- [ ] **Step 8: 커밋하지 않는다**

task-6이 같은 레이어(L3)다. 검사기를 통과시킨 뒤 한 번에 커밋한다.
