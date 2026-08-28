### Task 2: Re-point routing and kill the dead `diagnose` reference

**Files:**
- Modify: `woobin-harness/skills/kick-off/SKILL.md:31`
- Modify: `woobin-harness/skills/groupchat-debug/SKILL.md:3`
- Modify: `docs/workflow-spec.md:88`
- Modify: `docs/workflow-spec.md:719`

**Interfaces:**
- Consumes: the skill name `repro-loop` produced by Task 1.
- Produces: nothing later tasks depend on, except that Task 4's `check-harness-docs.sh` run must find no stale references.

**Background on the `diagnose` fix:** `groupchat-debug`'s description ends by telling the model to use a skill called `diagnose`. No such skill exists — it never did in this repo. An always-loaded description that recommends a nonexistent skill is the failure recorded in `HARNESS-LOG` #28 (a removed skill kept being recommended five more times). Fix it in the same pass.

- [ ] **Step 1: Re-point the kick-off route**

In `woobin-harness/skills/kick-off/SKILL.md`, line 31 currently reads:

```
- 디버깅 → `systematic-debugging`
```

Replace with:

```
- 디버깅 → `repro-loop`
```

Do not add any explanation of what `repro-loop` does — that file states "**이름만 부른다.**" three lines below and a copy would diverge.

- [ ] **Step 2: Fix the dead `diagnose` reference**

In `woobin-harness/skills/groupchat-debug/SKILL.md`, the `description:` on line 3 ends with:

```
로컬에서 직접 재현 가능한 버그는 `diagnose`, 장애가 아닌 일반 삼자대화는 `groupchat-ai`를 사용한다.
```

Replace that clause with:

```
로컬에서 직접 재현 가능한 버그는 `repro-loop`, 장애가 아닌 일반 삼자대화는 `groupchat-ai`를 사용한다.
```

Change nothing else on that line. It is a single-line YAML scalar; do not reflow it.

- [ ] **Step 3: Update workflow-spec §2 pipeline**

In `docs/workflow-spec.md`, line 88 currently reads:

```
   ├─(C) 디버깅 ────── systematic-debugging 스킬 (재현 절차를 산출물로)
```

Replace with:

```
   ├─(C) 디버깅 ────── repro-loop 스킬 (재현 루프를 먼저, 진단 기록을 산출물로)
```

Keep the box-drawing characters and the column alignment of the surrounding `├─`/`└─` lines exactly as they are.

- [ ] **Step 4: Update workflow-spec §4 inventory**

In `docs/workflow-spec.md`, line 719 is inside the sentence beginning `파이프라인에 직접 물린 것:`. It currently reads:

```
파이프라인에 직접 물린 것: `kick-off` · `interview` · `writing-plans` · `systematic-debugging` ·
```

Replace with:

```
파이프라인에 직접 물린 것: `kick-off` · `interview` · `writing-plans` · `repro-loop` ·
```

- [ ] **Step 5: Add the §4 change note**

Immediately above the `파이프라인에 직접 물린 것:` paragraph in `docs/workflow-spec.md`, insert this paragraph (matching the style of the dated notes already in that section):

```
2026-08-28, `systematic-debugging`을 `repro-loop`으로 교체했다(개수 21 유지). 근거는 실측 둘이다 —
세션 JSONL 1,803개에서 발동 3회, 그리고 재현 산출물을 만든 16세션 중 15세션이 그 스킬을 **한 번도
발동하지 않은** 세션이다(즉 "수정 전 재현"은 스킬이 만든 습관이 아니다). 본문 274줄 중 대부분이
obra/superpowers 사본이었고 보조 파일 3개는 upstream과 바이트 동일이었다. 새 본문은 세 조항만
남긴다 — red 가능한 루프 우선 · 다면적 재현을 런타임 진단 기록으로 · 실패는 다음 시도가 검증할 수
있는 지시로 닫기. 이름을 가른 이유는 `explain`/`explain-in-html` 때와 같다: `mattpocock-skills:
diagnosing-bugs`가 일반 버그 트리거 공간을 이미 갖고 있어 두 description이 경쟁하면 안 된다.
**§3에 규칙을 만들지 않았다** — 표본이 두 달간 실제 디버깅 5건이라 §0이 요구하는 `무효화 조건`을
채울 수 없다. 서사는 `home/HARNESS-LOG.md` #32.
```

Note: the string `mattpocock-skills:\ndiagnosing-bugs` above is split across two lines to respect the file's wrap width. Write it as shown — the surrounding paragraphs in that file wrap the same way.

- [ ] **Step 6: Verify no stale references remain**

```bash
grep -rn 'systematic-debugging' woobin-harness/ docs/workflow-spec.md ; echo "exit=$?"
grep -n '`diagnose`' woobin-harness/skills/groupchat-debug/SKILL.md ; echo "exit=$?"
```

Expected: both greps print nothing and report `exit=1`.

Do **not** run this grep against `home/HARNESS-LOG.md` — historical entries #1–#31 name the old skill and must keep naming it. Renaming history detaches past measurements from their subject, which is the rule `HARNESS-LOG` #31 already applied to `grill-me`.

- [ ] **Step 7: Commit**

```bash
git add woobin-harness/skills/kick-off/SKILL.md woobin-harness/skills/groupchat-debug/SKILL.md docs/workflow-spec.md
git commit -m "docs(harness): 디버깅 문을 repro-loop으로 재배선 + groupchat-debug의 죽은 \`diagnose\` 참조 제거

kick-off 문 목록 · workflow-spec §2 파이프라인 · §4 인벤토리 + 변경 노트.
groupchat-debug description이 존재한 적 없는 \`diagnose\`를 권하고 있었다 (#28의 전례).
HARNESS-LOG #1~#31의 옛 이름은 그대로 둔다 — 그 시점 실측의 대상이다."
```
