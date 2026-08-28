---
name: kick-off
description: 이 하네스의 작업 워크플로우로 들어가는 단일 진입점.
disable-model-invocation: true
---

# kick-off

이 하네스에서 무언가를 만들 때 여는 문이다. 어느 스킬을 어떤 순서로 부를지는 **여기서만** 안다 —
사용자는 `/kick-off` 하나만 기억하면 된다.

## 시작할 때

1. `.claude/kickoff.local.md`가 있고 `active: true`면 읽고, 적힌 `stage`부터 이어간다.
2. 없으면 **파일을 먼저 보고** 진입 지점을 정한다. 사용자에게 묻는 건 파일로 판정이 안 될 때뿐이다.

| 레포에 있는 것 | 진입 지점 |
|---|---|
| 이 주제의 `docs/woobin_plan/plans/<slug>/00-overview.md` | 구현 — 그 경로를 그대로 쓴다 |
| `docs/woobin_plan/specs/` 아래 확정 스펙 | `writing-plans` |
| 둘 다 없음 | `interview` |

3. 정한 것을 **한 줄로 선언**한다: `진입: <단계> · 경로: <이어질 스킬 이름들>`
   틀렸으면 사용자가 그 자리에서 잡는다.
4. `.claude/kickoff.local.md`를 쓴다(형식은 아래).

## 문 목록

- 기능 개발 → `interview` → `writing-plans`
- 제품 UI·디자인 → `design-workflow`
- 디버깅 → `debug`

**이름만 부른다.** 각 스킬이 무엇을 어떻게 하는지 여기서 설명하지 않는다 — 사본이 갈라진다.

## 난이도는 판정하지 않는다

`/kick-off`가 눌렸다는 것 자체가 "이건 워크플로우를 태울 일이다"라는 사용자의 판정이다.
크기에 맞춰 산출물을 줄이는 건 `interview`와 `writing-plans`가 각자 이미 한다.

## 상태 파일

`.claude/kickoff.local.md`:

```markdown
---
active: true
stage: spec
topic: <한 줄>
session_id: <세션 id>
started_at: <ISO 8601>
---
<사용자가 처음 준 요구사항 원문>
```

- `stage`는 `spec` → `plan` → `impl` 순으로만 간다. 스펙이 확정되면 `plan`, 플랜이 저장되면 `impl`.
- 훅이 이 파일을 읽는다. `active: false`면 훅은 조용해진다.

## 끝내기

`done` 인자로 불리면(`/kick-off done`) `active: false`만 쓰고 끝낸다. 다른 일은 하지 않는다.
