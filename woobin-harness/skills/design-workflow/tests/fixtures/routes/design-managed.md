# Context

저장소 루트에 관리형 DESIGN.md가 있고 `design_workflow.enabled: true` 및 schema version 1 marker block을 포함한다. 문서에는 의도와 권위 경로가 있으며 토큰 전체 목록은 없다.

# User request

설정 페이지의 저장 성공 토스트를 제품 방향과 컴포넌트 규칙에 맞게 다듬어줘.

# Expected route

system-evidence → implementation-contracts → review

# Must do

라우팅 전에 validator를 실행하고 통과한 lifecycle data만 신뢰한다. DESIGN.md는 의도와 authority paths를 제공하는 선택적 기억이며, absence remains valid. 구현 후 blocker/should-fix/note 리뷰를 수행한다.

# Must not do

Treat DESIGN.md as raw token inventory.
