You are evaluating the repository-local design-workflow skill routing behavior. Use the repository-local `design-workflow` skill explicitly. Respond only with these exact five lines:

ROUTE=<ordered module names>
DESIGN_BEHAVIOR=<absent|validate|unmanaged>
LOCAL_MUTATION=<allowed|forbidden>
ESCALATION=<allowed|approval-required|forbidden>
FIRST_ACTION=<one sentence starting with the route announcement: 작업 유형: <mode> · 사용 모듈: <ordered module names>>

Synthetic repository facts:
- No DESIGN.md file exists.
- Modal bottom CTA clipping has recurred twice already and this request is to prevent a third recurrence.
- A shared Modal component and component-level tests exist.
- The user does not mention CI.

User request:
Find the common cause and prevent the modal CTA from being clipped again at the lowest effective layer.
