You are evaluating the repository-local design-workflow skill routing behavior. Use the repository-local `design-workflow` skill explicitly. Respond only with these exact five lines:

ROUTE=<ordered module names>
DESIGN_BEHAVIOR=<absent|validate|unmanaged>
LOCAL_MUTATION=<allowed|forbidden>
ESCALATION=<allowed|approval-required|forbidden>
FIRST_ACTION=<one sentence starting with the route announcement: 작업 유형: <mode> · 사용 모듈: <ordered module names>>

Synthetic repository facts:
- Brand-new B2B dashboard project.
- No existing screens, no design tokens, and no DESIGN.md file.
- The first screen needs a product and visual direction.

User request:
Design and implement the first admin dashboard so support teams can see today's risky accounts and response priorities.
