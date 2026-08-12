# Context

PR에 검색 결과 카드의 hover, focus, empty 상태 변경이 포함되어 있다. 사용자는 수정 권한을 주지 않고 리뷰만 요청한다.

# User request

이 PR의 UI 변경을 리뷰해줘. 수정은 하지 마.

# Expected route

system-evidence → review

# Must do

review-only 모드로 파일을 수정하지 않는다. 필요한 증거만 읽고, 발견 사항은 blocker/should-fix/note 심각도로 보고한다. 관리형 DESIGN.md가 있으면 validator를 먼저 실행하지만 리뷰 전용 계약은 유지한다.

# Must not do

Write files or silently fix findings.
