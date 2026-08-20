---
name: design-rules
description: 이미 확립된 디자인 시스템 안에서 구체적인 UI 구현, 스타일 조정, 컴포넌트 선택, 치수·정보 설계·접근성 결정을 현재 화면과 일관되게 내릴 때 사용한다. 새 페이지·컴포넌트·레이아웃·CSS를 기존 문법에 맞춰 고치거나, 모달·테이블·폼·빈 상태·로딩·버튼 어포던스 같은 렌더 결과를 다듬을 때 직접 호출할 수 있다. 그린필드 방향 설정, 첫 도입, 대규모 리디자인, 리뷰 전용, 반복 실패의 가드 승격은 design-workflow를 사용한다. 로직·API·테스트·리팩터만 바꾸고 렌더 결과가 그대로면 사용하지 않는다.
---

# Compatibility entry

This direct entry preserves existing `$design-rules` calls. For process routing, first adoption,
greenfield direction, redesign, review-only, or guard promotion, use `design-workflow`.

For the requested concrete UI decision, read in order:

1. `../design-workflow/references/system-evidence.md`
2. `../design-workflow/references/implementation-contracts.md`
3. `../design-workflow/references/review.md` when a render or review is in scope
4. `../design-workflow/references/evolution.md` only for a repeated failure

`DESIGN.md` remains optional. Never stop because it is absent.

## Old-to-new owner map

| Old section | New owner |
|---|---|
| §1 tone | `system-evidence.md` |
| §2 dimensions | `system-evidence.md` |
| §3 information design | `system-evidence.md` + `implementation-contracts.md` |
| §4 taste defaults | `system-evidence.md` |
| §5 accessibility | `system-evidence.md` + `review.md` |
| §6 generation/refinement | `direction.md` + `review.md` |
| §7 rule evolution | `evolution.md` |
