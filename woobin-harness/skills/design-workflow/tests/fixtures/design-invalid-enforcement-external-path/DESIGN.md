---
design_workflow:
  enabled: true
  schema_version: 1
---

# Product direction

<!-- design-workflow:data:start -->
```json
{
  "schemaVersion": 1,
  "project": { "state": "established", "directionStatus": "adopted" },
  "authorities": [],
  "decisions": [
    {
      "id": "external-looking-enforcement-path",
      "status": "component-enforced",
      "source": { "type": "user-decision", "references": [] },
      "rule": "Enforcement records point to local enforcing files.",
      "localEvidence": [],
      "enforcement": [
        { "type": "component", "path": "vendor/repo@abc123" }
      ],
      "waivers": []
    }
  ]
}
```
<!-- design-workflow:data:end -->
