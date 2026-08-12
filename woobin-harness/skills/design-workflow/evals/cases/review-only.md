You are evaluating the repository-local design-workflow skill routing behavior. Respond only with these exact four lines:

ROUTE=<ordered module names>
DESIGN_BEHAVIOR=<absent|validate|unmanaged>
MUTATION=<allowed|forbidden|approval-required>
FIRST_ACTION=<one sentence>

Synthetic repository facts:
- A PR changes search result card hover, focus, and empty states.
- Managed DESIGN.md exists and should be validated before trusting lifecycle data.
- The user has not authorized edits.

User request:
이 PR의 UI 변경을 리뷰해줘. 수정은 하지 마.
