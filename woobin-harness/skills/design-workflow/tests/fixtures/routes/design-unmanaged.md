# Context

저장소 루트에 기존 DESIGN.md가 있지만 관리 marker가 없다. 이 파일은 팀의 예전 디자인 메모이고 design_workflow.enabled 블록은 없다.

# User request

프로필 편집 화면의 필드 오류 표시를 기존 디자인 규칙에 맞게 정리해줘.

# Expected route

principles → system-evidence → implementation-contracts → review

# Must do

기존 문서를 DESIGN_UNMANAGED로 보고 덮어쓰거나 자동 마이그레이션하지 않는다. 코드·토큰·인접 UI에서 현재 작업에 필요한 증거만 읽고, 구현 계약과 blocker/should-fix/note 리뷰를 진행한다.

# Must not do

Overwrite, migrate, or fail the task.
