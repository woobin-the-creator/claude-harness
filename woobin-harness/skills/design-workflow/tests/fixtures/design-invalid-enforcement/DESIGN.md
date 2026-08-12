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
      "id": "missing-component-enforcement",
      "status": "component-enforced",
      "source": { "type": "local-code", "references": ["src/components/TableCell.tsx"] },
      "rule": "Component-enforced records name the enforcing component.",
      "localEvidence": [],
      "enforcement": [],
      "waivers": []
    }
  ]
}
```
<!-- design-workflow:data:end -->
