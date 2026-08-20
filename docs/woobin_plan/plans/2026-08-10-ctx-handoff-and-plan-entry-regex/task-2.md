# Task 2: `handoff` 스킬 신설

**Files:**
- Create: `woobin-harness/skills/handoff/SKILL.md`

**Interfaces:**
- Consumes: 호출자(훅 또는 사용자)가 넘기는 **저장 경로**. 경로가 없으면 스킬이 기본값을 정한다.
- Produces: 지정 경로의 핸드오프 문서 1개. Task 3의 `ctx-handoff-stop.sh`와 기존 `idle-handoff-stop.sh`가 이 스킬을 이름으로 호출한다.

**배경:** `idle-handoff-stop.sh` 80·85행이 `handoff 스킬을 호출해…`라고 두 번 지시하는데 **그 스킬이 존재하지 않는다**(2026-08-10 확인 — 플러그인·`~/.claude/skills/` 양쪽). HARNESS-LOG #16과 같은 드리프트다. 훅이 2개가 되면 문서 계약을 두 곳이 소유하게 되므로, 계약을 스킬 하나에 두고 훅은 이름으로만 부른다.

**공개 스킬을 쓰지 않는 이유:** 조사한 3개([ykdojo](https://github.com/ykdojo/claude-code-tips/blob/main/skills/handoff/SKILL.md) `HANDOFF.md` 루트 / [thepushkarp](https://github.com/thepushkarp/handoff) `docs/handoff/HANDOFF.md` / [REMvisual](https://github.com/REMvisual/claude-handoff) `plans/handoffs/…`) 전부 저장 경로가 **레포 안에 고정**이고 파라미터화되지 않는다. 우리 훅은 `~/.claude/idle-handoffs/<sid>.md`(git 미추적, 세션 id 매핑)를 지정한다. 섹션 설계는 REMvisual이 가장 근접해 그 구성을 참고했다.

- [ ] **Step 1: 스킬 파일을 작성**

`woobin-harness/skills/handoff/SKILL.md`를 아래 내용 그대로 만든다.

````markdown
---
name: handoff
description: 지금 세션의 작업 상태를 다음 세션이 이어받을 수 있는 핸드오프 문서로 쓴다. 컨텍스트가 커져 세션을 끊어야 할 때, 자리를 비울 때, `/clear` 직전에 사용한다. 호출자가 저장 경로를 지정하면 반드시 그 경로에 쓴다. 트리거 — "핸드오프", "handoff", "인수인계 문서", "세션 넘기기", 그리고 훅이 주입하는 자동 핸드오프 지시.
---

# Handoff

다음 세션이 **이 대화를 읽지 않고도** 이어갈 수 있는 문서를 만든다.

## 저장 경로

**호출자가 경로를 지정했으면 그 경로에 쓴다. 다른 곳에 쓰지 않는다.**
훅이 부를 때는 항상 경로를 준다(`~/.claude/idle-handoffs/<session_id>.md`).
경로 지정이 없을 때만 `~/.claude/idle-handoffs/<session_id>.md`를 쓴다.

레포 안에 쓰지 않는다 — 워크트리마다 파일이 갈리고, git에 커밋할 것이 아니다.

## 무엇을 쓰는가

읽는 쪽은 **이 대화를 전혀 못 본** 세션이다. "위에서 정한 대로" 같은 참조는 전부 무의미하다.

1. **목표** — 지금 하려던 일 한 문장과, 그게 왜 필요한지.
2. **끝난 것 / 남은 것** — 각 항목에 파일 경로를 붙인다. 커밋했으면 커밋 해시도.
3. **기각한 대안과 그 사유** — **가장 중요하다.** 이게 없으면 다음 세션이 같은 걸 다시 제안하고,
   당신은 같은 논의를 처음부터 다시 한다. 무엇을 시도했고 무엇이 어떻게 실패했는지도 여기에 쓴다.
4. **다음 세션이 첫 턴에 읽어야 할 파일** — 통독 목록이 아니라 **경로 목록**이다.
   플랜 문서가 이미 있으면 그 내용을 복제하지 말고 경로만 가리킨다.
5. **재현이 필요한 명령 원문** — 테스트·빌드·서버 기동·검증 명령을 그대로.
6. **막힌 것** — 미해결 에러가 있으면 원문(traceback 등)과 지금까지의 판정.

## 규율

- **복제하지 않는다.** 플랜 문서·스펙·런북에 이미 있는 내용은 경로로 가리킨다.
  핸드오프 문서가 플랜을 다시 쓰기 시작하면 소유자가 둘이 되고 갈라진다.
- **대화를 요약하지 않는다.** 결정과 그 근거만 남긴다. 어떤 순서로 논의했는지는 다음 세션에 쓸모가 없다.
- **길이보다 자기완결성.** 다음 세션이 되물어야 하는 항목이 하나라도 있으면 절약분이 날아간다(R1).
- 기존 문서가 같은 경로에 있으면 **덮어쓰지 말고 이어붙인다** — 앞에 `---` 구분선과 날짜를 넣는다.
  같은 작업 흐름의 2차·3차 핸드오프가 체인으로 남아야 한다.

## 마무리

저장 후 사용자에게 **경로 한 줄**만 알린다. 문서 내용을 대화에 다시 풀어놓지 않는다 —
그러면 방금 줄이려던 컨텍스트를 도로 채운다.

훅이 불러서 실행된 경우에는 훅이 지정한 마무리 문장을 그대로 쓰고, 사용자에게 질문하지 않는다.
````

- [ ] **Step 2: frontmatter가 파싱되는지 검증**

`description:` 안의 콜론+공백은 YAML이 스칼라를 매핑으로 파싱하게 만들어 **모든 frontmatter 필드를 조용히 날린다**. 런타임은 더 관대해서 정상으로 보이므로 이 명령이 유일한 탐지 수단이다.

Run: `claude plugin validate ./woobin-harness`
Expected: 통과. 실패하면 `description:`에서 `—`를 `-`로 바꾸거나 전체를 따옴표로 감싼다.

- [ ] **Step 3: 스킬이 목록에 뜨는지 확인**

Run: `ls woobin-harness/skills/handoff/SKILL.md && head -3 woobin-harness/skills/handoff/SKILL.md`
Expected: 파일이 존재하고 `---` / `name: handoff` 로 시작한다.

- [ ] **Step 4: 커밋**

```bash
git add woobin-harness/skills/handoff/SKILL.md
git commit -m "feat(skills): handoff 스킬 신설 — 훅 2개가 참조하던 계약의 단일 소유자"
```
