---
design_workflow:
  enabled: true
  schema_version: 1
---

# Product direction

The product uses local evidence before adopting durable design rules.

<!-- design-workflow:data:start -->
```json
{
  "schemaVersion": 1,
  "project": { "state": "established", "directionStatus": "adopted" },
  "authorities": [
    { "kind": "components", "path": "src/components" }
  ],
  "decisions": [
    {
      "id": "table-cell-wrapping",
      "status": "component-enforced",
      "source": {
        "type": "local-incident",
        "references": ["evidence/table-density.md"]
      },
      "rule": "Table cells use one line unless an explicit multiline variant is selected.",
      "localEvidence": ["evidence/table-density.md"],
      "enforcement": [
        { "type": "component", "path": "src/components/TableCell.tsx" }
      ],
      "waivers": []
    },
    {
      "id": "measured-overflow",
      "status": "candidate",
      "source": {
        "type": "external-precedent",
        "references": ["carbon-design-system/ibm-products@eeff1e98"]
      },
      "rule": "Visible items are selected from measured widths rather than a fixed count.",
      "localEvidence": [],
      "enforcement": [],
      "waivers": []
    }
  ]
}
```
<!-- design-workflow:data:end -->
