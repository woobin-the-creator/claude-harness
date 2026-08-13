# Generation record

- Condition: `design-rules`
- Baseline reference: `36a8fe8e54c162f7b77e52c15cc70d649674505c`
- Common input SHA-256: `22f5ac118c1cfb65b21f39e73c91591844dbc1b51b98e531e1e39441cf7f1c62` (SHA-256 of the ordered SHA-256 manifest for product brief, functional contract, types, and fixtures)
- Common file hashes: product brief `71080f8f20d1e76ed980211091e9be37033bbef851164f9729f5b234685c2ecf`; functional contract `9ef978ce2139c53b9707cad540c295969560d123992b76865decc854028d983a`; types `7dcec250fdb35466b606e6e6164467adcaee60d1611c7e96ce2c532b6507d8cf`; fixtures `f3964a74df5d37f5365eb76f60deba4682dd810498084b3b6e1bbf42d6ce14bb`
- Legacy skill SHA-256: `4884f4efa85e91831338dc50a6112d8d15093f6c90b71dbc6a2265944e56b9b3`
- Selected skill: `inputs/design-rules/skill/design-rules/SKILL.md`

## Loaded files

- `inputs/design-rules/PROMPT.md`
- `inputs/design-rules/common/product-brief.md`
- `inputs/design-rules/common/functional-contract.md`
- `inputs/design-rules/common/src/types.ts`
- `inputs/design-rules/common/src/fixtures.ts`
- `inputs/design-rules/skill/design-rules/SKILL.md`
- `inputs/design-rules/CONDITION.json`
- Root `package.json` and lockfile dependency metadata

The optional bundled instance guide was not loaded because no `DESIGN.md` was being created.

## Build

- Command: `npm run build:design-rules`
- Result: passed; TypeScript typecheck and Vite production build completed successfully.

## Implementation assumptions

- The default view represents the active 2026-08-13 day shift and keeps the dashboard in one viewport; the shipment table and right-side detail/notification panels own overflow.
- Filter edits are staged until “필터 적용”; clearing filters and all data changes stay in browser memory.
- Bulk resolution changes selected shipment status to `resolved`; notification resolution cycles `open → acknowledged → resolved → open`.
- Driver selection is searchable across name, ID, phone, and certification. Selecting a candidate preloads their editable name and phone.
- With no sealed `DESIGN.md`, the skill defaults are used: mono-ink hierarchy, restrained teal accent, flat bordered surfaces, content-proportional controls, and a compact KPI strip.
- An unregulated default would have used uniformly large cards and full-width stacked form controls; this implementation instead reserves height for the operational table and sizes controls by their actual values.
