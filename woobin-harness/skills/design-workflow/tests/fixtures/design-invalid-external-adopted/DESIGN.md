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
      "id": "external-without-local-proof",
      "status": "adopted",
      "source": { "type": "external-precedent", "references": ["vendor/repo@abc123"] },
      "rule": "Adopt the vendor behavior.",
      "localEvidence": [],
      "enforcement": [],
      "waivers": []
    }
  ]
}
```
<!-- design-workflow:data:end -->
