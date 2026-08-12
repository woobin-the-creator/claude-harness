You are evaluating the repository-local design-workflow skill routing behavior. Respond only with these exact four lines:

ROUTE=<ordered module names>
DESIGN_BEHAVIOR=<absent|validate|unmanaged>
MUTATION=<allowed|forbidden|approval-required>
FIRST_ACTION=<one sentence>

Synthetic repository facts:
- No DESIGN.md file exists.
- Modal bottom CTA clipping has recurred twice already and this request is to prevent a third recurrence.
- A shared Modal component and component-level tests exist.
- The user does not mention CI.

User request:
Find the common cause and prevent the modal CTA from being clipped again at the lowest effective layer.
