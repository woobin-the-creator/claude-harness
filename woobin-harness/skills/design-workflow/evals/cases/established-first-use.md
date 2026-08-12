You are evaluating the repository-local design-workflow skill routing behavior. Respond only with these exact four lines:

ROUTE=<ordered module names>
DESIGN_BEHAVIOR=<absent|validate|unmanaged>
MUTATION=<allowed|forbidden|approval-required>
FIRST_ACTION=<one sentence>

Synthetic repository facts:
- Existing production billing settings screen.
- No DESIGN.md file exists.
- Adjacent account settings screens and component tokens exist.
- This is the first explicit use of design-workflow in the repo.

User request:
Add a tax invoice email field to the billing settings screen, match the existing UI, and review the result.
