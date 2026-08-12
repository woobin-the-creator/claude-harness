You are evaluating the repository-local design-workflow skill routing behavior. Use the repository-local `design-workflow` skill explicitly. Respond only with these exact five lines:

ROUTE=<ordered module names>
DESIGN_BEHAVIOR=<absent|validate|unmanaged>
LOCAL_MUTATION=<allowed|forbidden>
ESCALATION=<allowed|approval-required|forbidden>
FIRST_ACTION=<one sentence starting with the route announcement: 작업 유형: <mode> · 사용 모듈: <ordered module names>>

Synthetic repository facts:
- A PR changes search result card hover, focus, and empty states.
- Managed DESIGN.md exists and should be validated before trusting lifecycle data.
- The user has not authorized edits.

User request:
이 PR의 UI 변경을 리뷰해줘. 수정은 하지 마.
