### Task 5: explain 개명 + 텍스트 explain 신설

codex는 `explain`을 둘로 쪼갰다 — 시각 산출물(`explain-with-html`)과 독자 수준에 맞춘 텍스트 설명(`explain`). 우리 레포에는 시각 쪽만 `explain`이라는 이름으로 있다. 사용자 결정에 따라 **기존을 `explain-in-html`로 개명하고, `explain`은 새 텍스트 스킬이 가져간다.**

이름을 반드시 갈라야 하는 이유: 두 스킬의 `description`은 **둘 다 상시 로드**된다. 같은 이름이면 하나가 다른 하나를 가리고, 어느 쪽이 라우팅되는지 알 수 없다. `docs/workflow-spec.md` §4가 "제거 사유가 되는 건 프롬프트 충돌이다"라고 한 게 이거고, 2026-08-21에 `~/.claude/skills/` 사본 22개를 지운 이유도 같다.

스킬 개수가 **19 → 20**이 된다.

**Files:**
- Rename: `woobin-harness/skills/explain/` → `woobin-harness/skills/explain-in-html/`
- Modify: `woobin-harness/skills/explain-in-html/SKILL.md` (`name`, description의 `/explain` 문구)
- Create: `woobin-harness/skills/explain/SKILL.md`
- Modify: `docs/workflow-spec.md:513`, `woobin-harness/output-styles/ATTRIBUTION.md:24`, `scripts/test-skills.sh:143,145`
- Modify (개수): `scripts/test-skills.sh:19,20,82`, `scripts/validate-codex.sh:144,145`, `README.md`, `.claude-plugin/marketplace.json`, `woobin-harness/.claude-plugin/plugin.json`, `docs/workflow-spec.md:620`, `docs/workflow.html`

**Interfaces:**
- Consumes: Task 1이 이미 `plugin.json` version을 `1.14.0`으로 올려 뒀다. **다시 올리지 마라.**
- Produces: 스킬 디렉터리 20개. Task 7의 `check-harness-docs.sh`가 이 숫자를 센다.

---

- [ ] **Step 1: 기존 스킬을 개명한다**

```bash
git mv woobin-harness/skills/explain woobin-harness/skills/explain-in-html
```

`woobin-harness/skills/explain-in-html/SKILL.md`의 frontmatter를 고친다.

`name:`을 바꾼다:
```yaml
name: explain-in-html
```

`description:`에서 `/explain` 호출 문구를 뺀다. 현재:
```
Use when 사용자가 /explain을 호출하거나, 방금 논의한 내용을 "그림/인포그래픽/시각화해서 gh issue에 올려달라"고 할 때.
```
바꾼 뒤:
```
Use when 사용자가 방금 논의한 내용을 "그림/인포그래픽/시각화해서 gh issue에 올려달라"고 하거나 /explain-in-html을 호출할 때.
```

⚠ `description:` 값 안에 **콜론+공백(`: `)을 넣지 마라.** YAML이 스칼라를 매핑으로 파싱해 모든 frontmatter 필드가 조용히 날아간다(2026-08-08 `Explore.md`에서 실제 발생). 본문 첫 `# explain` 제목도 `# explain-in-html`로 바꾼다.

- [ ] **Step 2: 새 텍스트 explain 스킬을 만든다**

Create `woobin-harness/skills/explain/SKILL.md`. 본문은 영어로 쓴다 — `writing-plans/SKILL.md`가 이미 영어이고 Task 6이 플랜 산출물을 영어로 옮기는 것과 방향이 같다. description에는 한국어 트리거를 포함한다.

```markdown
---
name: explain
description: Write a self-contained explanation of a result, decision, status, cause, or next step for a reader who may lack thread or project context. Use when the reader asks for a simpler explanation, says they did not understand, or when the answer must survive outside this conversation. Korean triggers — "더 쉽게 설명해줘", "초등학생 수준으로", "무슨 말인지 모르겠어", "상위 맥락부터", "쉽게 풀어줘".
---

# Explain

Write the final user-facing answer so it stands on its own at the reader's
demonstrated level of familiarity. Restore missing context only where it helps
the reader understand the answer or act on it.

## Calibrate the reader's starting point

Infer the lowest missing layer from the user's wording and prior feedback. Do
not ask a calibration question when the prompt already gives a usable signal.

- **Direct** — The reader uses the relevant identifiers and domain vocabulary
  confidently. Answer first; define only thread-local names.
- **Situated** — The reader knows the domain but not this project or thread.
  Briefly establish the system's purpose and the named components' roles before
  explaining the result.
- **Foundation-first** — The reader asks for a simple explanation, lacks the
  underlying background, or did not understand the previous answer. Start with
  purpose and actors, then introduce the mechanism and the exact identifiers.

Default to situated when there is no reliable signal. A request for more
context asks for a higher-level frame; a request for simpler language asks for
fewer assumed prerequisites.

**If an explanation did not land, change its entry point and vocabulary rather
than repeating it with more detail.** Restating the same frame at greater
length is the common failure — the reader did not need more words, they needed
a different starting layer.

## Make the answer self-contained

- Lead with the outcome or central point. Name the subject before using "it",
  "this", or "the change".
- Define unfamiliar acronyms, local labels, files, or options on first use when
  the name alone would not orient a new reader.
- Supply the minimum background and causal chain that shows why the result
  matters and how the conclusion follows.
- Separate verified facts and completed work from assumptions, proposals,
  limitations, and pending work. Include evidence when it affects confidence.
- Preserve exact identifiers when they let the reader verify or continue the
  work, but introduce them after the conceptual model when the reader needs
  that foundation first.
- Do not replay the conversation, the tool calls, or the search process unless
  that history is itself the subject.

For a foundation-first explanation: establish the purpose, introduce the few
necessary actors, show the event as simple causal steps, and finish with the
current state. Use an analogy or a compact mapping table only when it makes a
relationship materially clearer, and map it back to the real system.

## Use proportionate structure

Keep a short, single-topic answer to one or two paragraphs. For multiple
workstreams, decisions, or mixed completion states, use descriptive headings
and organize by subject rather than by conversation chronology. Integrate
status, verification, limitations, and remaining work instead of repeating the
same facts in an overview and again in detail.

End with the concrete next action and its owner, or state that no action
remains. Distinguish states with different consequences — created versus
committed, committed versus pushed, an open pull request versus a merged one.
Never invent a clean state, a verification result, a blocker, or a next step to
make the ending sound decisive.

## Handle missing context

Never invent context to make an answer feel complete. If an unresolved detail
would materially change the answer, name the exact gap and ask only for what is
needed. Otherwise state the bounded assumption and continue.

Before sending, cold-read the answer as if it had been pasted into a fresh
thread. Revise if the subject, a local term, the conclusion, the evidence, the
current state, or the next action would be unclear there — or if the answer
assumes a prerequisite the reader has not shown.

Output formatting and answer density follow the active output style and the
global `CLAUDE.md` density rules. This skill decides **which layer to start
from**, not how long the answer is.
```

마지막 문단이 중요하다. 사용자 전역 `~/.claude/CLAUDE.md`에 이미 "답변 밀도(질문 크기에 비례)" 규칙이 있어서, 이 스킬이 길이까지 규정하면 소유자가 둘이 된다. **이 스킬은 진입 층위만 정하고 길이는 안 건드린다**고 명시해 충돌을 없앤다.

- [ ] **Step 3: 옛 이름을 참조하는 3곳을 고친다**

```bash
grep -rn "explain" --include="*.md" --include="*.sh" --include="*.json" . | grep -v "^./woobin-harness/skills/explain" | grep -v "^./docs/woobin_plan/plans/" | grep -vi "explanation\|explains\|explaining"
```

**고칠 것 3곳:**

| 파일:행 | 내용 | 바꿀 값 |
|---|---|---|
| `docs/workflow-spec.md:513` | 한국어 산출물 스킬 목록의 `explain` | `explain-in-html` |
| `woobin-harness/output-styles/ATTRIBUTION.md:24` | 같은 목록 | `explain-in-html` |
| `scripts/test-skills.sh:143,145` | `ℹ explain renderer: …` 메시지 | `explain-in-html renderer` |

**고치지 않을 것** — 전부 과거 이력이라 소급하면 그때의 사실이 거짓이 된다:
`home/HARNESS-LOG.md:442,512` · `docs/codex-compatibility-audit-2026-08-12.md:58` · `history/woobin-harness-untriggered-skills.html:72` · `docs/woobin_plan/plans/` 아래 전부.

`scripts/test-skills.sh`가 렌더러를 찾을 때 **경로**를 쓰면 그 경로도 `explain-in-html`로 바꿔야 한다. 메시지 문자열만이면 문구만 고친다.

- [ ] **Step 4: 스킬 개수 19 → 20 을 단언하는 5곳을 고친다**

| 파일 | 현재 | 바꿀 값 |
|---|---|---|
| `scripts/test-skills.sh:19` (`-eq 19`) · `:20` (`pass "19 packaged skills"`) | 19 | 20 |
| `scripts/test-skills.sh:82` (`"skills": 19`) | 19 | 20 |
| `scripts/validate-codex.sh:144` (`-eq 19`) · `:145` (실패 메시지) | 19 | 20 |
| `.claude-plugin/marketplace.json:11` (`스킬 19개`) | 19 | 20 |
| `woobin-harness/.claude-plugin/plugin.json` (`description`의 `스킬 19개`) | 19 | 20 |
| `docs/workflow-spec.md:620` (`### 스킬 19개`) | 19 | 20 |
| `README.md:39` (`skills/<name>/SKILL.md   19개`) | 19 | 20 |

- [ ] **Step 5: 이미 갈라져 있던 "44개"를 같이 고친다**

2026-08-21의 28 → 19 정리 때 안 고쳐진 곳이 남아 있다. `check-harness-docs.sh`의 정규식에 안 걸려서 살아남았다:

| 파일:행 | 현재 | 바꿀 값 |
|---|---|---|
| `README.md:11` (`스킬 44개·에이전트 4개·훅 11개를 붙인다`) | 44 | 20 (훅은 Task 1이 12로 고쳤다) |
| `README.md:12` (`스킬 44개와 검증된 훅 4개`) | 44 | 20 |
| `README.md:110` (`실제 codex debug prompt-input에서 스킬 44개`) | 44 | 20 |
| `docs/workflow.html:405` (`공통 스킬 44개`) | 44 | 20 |

Task 7이 이 사실을 `HARNESS-LOG.md`에 기록한다 — 개수 하드코딩이 재발원이라는 미조치 과제의 두 번째 증거다.

- [ ] **Step 6: §4 스킬 인벤토리에 두 스킬을 등재한다**

`docs/workflow-spec.md`의 `### 스킬 20개` 절에서 `explain` 항목을 찾아 `explain-in-html`로 바꾸고, 새 `explain` 항목을 한 줄 추가한다. 그 절의 기존 서식을 그대로 따른다.

- [ ] **Step 7: frontmatter와 개수 게이트를 통과시킨다**

Run:
```bash
claude plugin validate ./woobin-harness
./scripts/test-skills.sh
./scripts/check-harness-docs.sh
```
Expected: 셋 다 통과. `check-harness-docs.sh`는 `동기화됨` (⚠ HARNESS-LOG 경고는 무시).

`claude plugin validate`를 건너뛰지 마라 — Step 1·2에서 frontmatter를 두 번 건드렸다.

`./scripts/validate-codex.sh`는 Codex 홈 설치까지 도는 무거운 검사다. Task 7에서 한 번만 돌린다.

- [ ] **Step 8: 커밋**

```bash
git add -A woobin-harness/skills scripts README.md docs .claude-plugin woobin-harness/output-styles woobin-harness/.claude-plugin
git commit -m "feat(explain): 텍스트 설명 스킬 신설, 기존 인포그래픽을 explain-in-html로 개명"
```

`git mv`로 옮긴 파일이 rename으로 잡혔는지 확인한다:
```bash
git show --stat --find-renames HEAD | grep -i explain
```
