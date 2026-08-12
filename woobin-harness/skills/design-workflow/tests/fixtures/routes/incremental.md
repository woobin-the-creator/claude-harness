# Context

기존 온보딩 플로우에 관리형 DESIGN.md가 있고 validator가 통과한다. 요청은 한 단계의 빈 상태 UI 개선에 한정된다.

# User request

온보딩 3단계의 “초대할 팀원이 없음” 빈 상태를 더 명확하게 바꿔줘. 다른 온보딩 단계와 어긋나지 않게 해줘.

# Expected route

system-evidence → implementation-contracts → review

# Must do

관리형 DESIGN.md는 validator로 확인하되, absence도 다른 상황에서는 계속 유효하다는 전제를 유지한다. 현재 화면과 인접 온보딩 단계의 증거를 우선하고 blocker/should-fix/note 리뷰로 마무리한다.

# Must not do

Load direction or audit unrelated screens.
