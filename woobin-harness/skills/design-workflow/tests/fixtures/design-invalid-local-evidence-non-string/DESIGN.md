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
      "id": "non-string-local-evidence",
      "status": "adopted",
      "source": { "type": "user-decision", "references": [] },
      "rule": "Local evidence items are strings.",
      "localEvidence": [42],
      "enforcement": [],
      "waivers": []
    }
  ]
}
```
<!-- design-workflow:data:end -->
