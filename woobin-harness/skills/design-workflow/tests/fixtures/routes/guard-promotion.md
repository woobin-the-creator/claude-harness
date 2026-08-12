# Context

최근 세 번, 모달 하단 CTA가 작은 화면에서 가려지는 회귀가 발생했다. 코드에는 모달 컴포넌트와 관련 테스트가 있지만 CI failure gate는 아직 없다.

# User request

모달 CTA가 또 잘리는 일이 없게 막아줘. 이번에는 공통 원인을 찾아서 가장 낮은 레이어에서 막아줘.

# Expected route

system-evidence → implementation-contracts → evolution → review

# Must do

반복 사고의 공통 원인을 찾고 가장 낮은 효과적 레이어의 component/static/unit/a11y/browser guard를 고른다. incident는 promotion signal로만 다루며, external precedent는 로컬 증거 없이는 adopted가 될 수 없다.

# Must not do

Enable CI failure gate without approval.
