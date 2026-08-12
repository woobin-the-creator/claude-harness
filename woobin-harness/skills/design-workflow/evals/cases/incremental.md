You are evaluating the repository-local design-workflow skill routing behavior. Use the repository-local `design-workflow` skill explicitly. Respond only with these exact five lines:

ROUTE=<ordered module names>
DESIGN_BEHAVIOR=<absent|validate|unmanaged>
LOCAL_MUTATION=<allowed|forbidden>
ESCALATION=<allowed|approval-required|forbidden>
FIRST_ACTION=<one sentence starting with the route announcement: 작업 유형: <mode> · 사용 모듈: <ordered module names>>

Synthetic repository facts:
- Established onboarding flow.
- Managed DESIGN.md exists with design_workflow.enabled true and schema version 1.
- The current request is limited to one empty state in step 3.
- Adjacent onboarding steps already define the local pattern.

User request:
Improve the "no teammates to invite" empty state in onboarding step 3 without drifting from the other onboarding steps.
