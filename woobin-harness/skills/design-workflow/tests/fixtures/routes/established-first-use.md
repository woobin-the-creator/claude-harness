# Context

이미 운영 중인 결제 설정 화면이 있고, 이 저장소에서 design-workflow를 명시적으로 처음 사용한다. 기존 버튼, 폼, 토큰, 인접 설정 화면은 있지만 DESIGN.md는 없다.

# User request

결제 설정 화면에 “세금계산서 이메일” 입력 필드를 추가해줘. 기존 UI 톤에 맞추고 완료 후 디자인 리뷰까지 해줘.

# Expected route

principles → system-evidence → implementation-contracts → review

# Must do

현재 작업에 필요한 저장소 읽기로 범위를 제한한다. DESIGN.md 부재는 유효한 상태로 보고, 코드·토큰·인접 UI를 임시 권위로 사용한다. 구현 계약을 확인한 뒤 blocker/should-fix/note 형식으로 렌더 리뷰를 수행한다.

# Must not do

Block on DESIGN.md or reopen product direction.
