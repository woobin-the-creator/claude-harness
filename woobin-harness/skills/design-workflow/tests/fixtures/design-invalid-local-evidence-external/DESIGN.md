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
      "id": "external-looking-local-evidence",
      "status": "adopted",
      "source": { "type": "user-decision", "references": ["vendor/repo@abc123"] },
      "rule": "Local evidence is always a local project path.",
      "localEvidence": ["vendor/repo@abc123"],
      "enforcement": [],
      "waivers": []
    }
  ]
}
```
<!-- design-workflow:data:end -->
