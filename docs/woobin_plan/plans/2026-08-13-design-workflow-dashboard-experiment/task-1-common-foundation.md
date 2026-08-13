# Task 1: Common Runtime, Domain Types, and Deterministic Fixture Pressure

**Files:**
- Create: `experiments/design-workflow-dashboard/package.json`
- Create: `experiments/design-workflow-dashboard/package-lock.json`
- Create: `experiments/design-workflow-dashboard/tsconfig.base.json`
- Create: `experiments/design-workflow-dashboard/.gitignore`
- Create: `experiments/design-workflow-dashboard/common/product-brief.md`
- Create: `experiments/design-workflow-dashboard/common/functional-contract.md`
- Create: `experiments/design-workflow-dashboard/common/src/types.ts`
- Create: `experiments/design-workflow-dashboard/common/src/fixtures.ts`
- Create: `experiments/design-workflow-dashboard/common/tests/fixtures.test.ts`

**Interfaces:**
- Consumes: the approved design spec only.
- Produces: `createExperimentData(): ExperimentData`, exact package versions, common product/behavior input, the demo query contract, and neutral hook names.
- Tasks 2–5 consume these files byte-for-byte. Tasks 6–8 consume the root scripts and fixture IDs.

- [ ] **Step 1: Create the root package and strict compiler contract**

Write `package.json` exactly as follows. Do not use caret or tilde ranges; all conditions must resolve the same versions.

```json
{
  "name": "design-workflow-dashboard-experiment",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=22.12.0"
  },
  "scripts": {
    "prepare:inputs": "node scripts/prepare-inputs.mjs",
    "audit:inputs": "node scripts/audit-inputs.mjs",
    "test:common": "vitest run common/tests/fixtures.test.ts",
    "typecheck:baseline": "tsc -p variants/baseline/tsconfig.json",
    "typecheck:design-rules": "tsc -p variants/design-rules/tsconfig.json",
    "typecheck:design-workflow": "tsc -p variants/design-workflow/tsconfig.json",
    "build:baseline": "npm run typecheck:baseline && vite build --config variants/baseline/vite.config.ts",
    "build:design-rules": "npm run typecheck:design-rules && vite build --config variants/design-rules/vite.config.ts",
    "build:design-workflow": "npm run typecheck:design-workflow && vite build --config variants/design-workflow/vite.config.ts",
    "build:variants": "npm run build:baseline && npm run build:design-rules && npm run build:design-workflow",
    "test:functional": "playwright test -c evaluation/playwright.config.ts evaluation/functional.spec.ts",
    "blind-map": "node scripts/create-blind-map.mjs",
    "build:launcher": "tsc -p launcher/tsconfig.json && vite build --config launcher/vite.config.ts",
    "test:blind": "vitest run evaluation/blind-map.test.ts && EXPERIMENT_SERVER_MODE=blind playwright test -c evaluation/playwright.config.ts evaluation/blind-launcher.spec.ts",
    "serve": "node scripts/serve-built.mjs --mode blind --port 4173",
    "capture": "node evaluation/capture-scenes.mjs",
    "measure": "node evaluation/collect-measurements.mjs",
    "audit:experiment": "node scripts/audit-experiment.mjs",
    "reveal": "node scripts/reveal-map.mjs"
  },
  "dependencies": {
    "lucide-react": "1.28.0",
    "react": "19.2.8",
    "react-dom": "19.2.8"
  },
  "devDependencies": {
    "@playwright/test": "1.61.1",
    "@types/react": "19.2.17",
    "@types/react-dom": "19.2.3",
    "@vitejs/plugin-react": "6.0.4",
    "typescript": "7.0.2",
    "vite": "8.1.5",
    "vitest": "4.1.10"
  }
}
```

Write `tsconfig.base.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "skipLibCheck": true
  }
}
```

Write `.gitignore`:

```gitignore
node_modules/
variants/*/dist/
launcher/dist/
playwright-report/
test-results/
evaluation/private/
evaluation/artifacts/
```

Generate and verify the single lockfile:

```bash
cd experiments/design-workflow-dashboard
npm install --package-lock-only
npm ci
npx playwright install chromium
npm ls --depth=0
```

Expected: npm exits `0`; every top-level package version matches `package.json` exactly.

- [ ] **Step 2: Define the exact domain model**

Create `common/src/types.ts`:

```ts
export type ShipmentStatus =
  | 'normal'
  | 'temperature-excursion'
  | 'delayed'
  | 'sensor-offline'
  | 'resolved'

export type TemperatureState = 'normal' | 'warning' | 'critical' | 'unavailable'
export type AlertSeverity = 'info' | 'warning' | 'critical'
export type AlertResolution = 'open' | 'acknowledged' | 'resolved'
export type TimelineKind = 'temperature' | 'location' | 'sensor' | 'action'

export interface Hub {
  id: string
  name: string
  city: string
  address: string
}

export interface Driver {
  id: string
  name: string
  phone: string
  homeHubId: string
  certifications: string[]
  active: boolean
}

export interface Vehicle {
  id: string
  plate: string
  model: string
  temperatureClass: 'frozen' | 'chilled' | 'dual'
  homeHubId: string
  active: boolean
}

export interface Shipment {
  id: string
  trackingCode: string
  cargoName: string
  originHubId: string
  destinationHubId: string
  originAddress: string
  destinationAddress: string
  driverId: string
  vehicleId: string
  status: ShipmentStatus
  temperatureState: TemperatureState
  currentTemperature: number | null
  minTemperature: number
  maxTemperature: number
  eta: string
  alertCount: number
  notes: string
}

export interface Alert {
  id: string
  shipmentId: string
  severity: AlertSeverity
  title: string
  message: string
  createdAt: string
  read: boolean
  resolution: AlertResolution
}

export interface TimelineEvent {
  id: string
  shipmentId: string
  kind: TimelineKind
  occurredAt: string
  title: string
  detail: string
  temperature: number | null
}

export interface AnomalyPoint {
  hour: string
  warning: number
  critical: number
}

export interface ExperimentData {
  shipments: Shipment[]
  drivers: Driver[]
  vehicles: Vehicle[]
  hubs: Hub[]
  alerts: Alert[]
  eventsByShipment: Record<string, TimelineEvent[]>
  anomalySeries: AnomalyPoint[]
}
```

- [ ] **Step 3: Write fixture tests before the generator**

Create `common/tests/fixtures.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { createExperimentData } from '../src/fixtures'

describe('cold-chain experiment fixtures', () => {
  const data = createExperimentData()

  it('keeps every condition on the exact same data volume', () => {
    expect(data.shipments).toHaveLength(64)
    expect(data.drivers).toHaveLength(96)
    expect(data.vehicles).toHaveLength(42)
    expect(data.hubs).toHaveLength(12)
    expect(data.alerts).toHaveLength(30)
    expect(Object.keys(data.eventsByShipment)).toHaveLength(64)
  })

  it('contains every required operational state', () => {
    expect(new Set(data.shipments.map((item) => item.status))).toEqual(
      new Set(['normal', 'temperature-excursion', 'delayed', 'sensor-offline', 'resolved']),
    )
    expect(new Set(data.shipments.map((item) => item.temperatureState))).toEqual(
      new Set(['normal', 'warning', 'critical', 'unavailable']),
    )
  })

  it('creates real content pressure without prescribing a UI remedy', () => {
    const names = data.drivers.map((item) => item.name.length)
    const cargo = data.shipments.map((item) => item.cargoName.length)
    const addresses = data.shipments.flatMap((item) => [item.originAddress.length, item.destinationAddress.length])
    expect(Math.min(...names)).toBeLessThanOrEqual(2)
    expect(Math.max(...names)).toBeGreaterThanOrEqual(4)
    expect(Math.max(...cargo)).toBeGreaterThanOrEqual(24)
    expect(Math.max(...addresses)).toBeGreaterThanOrEqual(28)
    expect(data.shipments.some((item) => item.notes === '')).toBe(true)
    expect(data.shipments.some((item) => item.notes.includes('\n'))).toBe(true)
    expect(data.shipments.some((item) => item.currentTemperature === null)).toBe(true)
    expect(data.shipments.some((item) => item.minTemperature < 0)).toBe(true)
  })

  it('provides stable neutral browser-test targets', () => {
    expect(data.shipments.some((item) => item.id === 'SHP-001')).toBe(true)
    expect(data.drivers.some((item) => item.id === 'DRV-096')).toBe(true)
    expect(data.alerts.some((item) => item.id === 'ALT-030' && item.shipmentId === 'SHP-001')).toBe(true)
  })

  it('forces every detail surface to scroll through 12 to 40 events', () => {
    const counts = Object.values(data.eventsByShipment).map((events) => events.length)
    expect(Math.min(...counts)).toBe(12)
    expect(Math.max(...counts)).toBe(40)
  })

  it('is deterministic across calls', () => {
    expect(createExperimentData()).toEqual(data)
  })
})
```

Run:

```bash
cd experiments/design-workflow-dashboard
npm run test:common
```

Expected: FAIL because `common/src/fixtures.ts` does not exist.

- [ ] **Step 4: Implement the deterministic generator**

Create `common/src/fixtures.ts` with the following exact construction. Keep every loop pure and time-independent.

```ts
import type {
  Alert,
  AnomalyPoint,
  Driver,
  ExperimentData,
  Hub,
  Shipment,
  ShipmentStatus,
  TemperatureState,
  TimelineEvent,
  Vehicle,
} from './types'

const hubs: Hub[] = [
  ['HUB-01', '김포 바이오 허브', '김포', '경기도 김포시 고촌읍 아라육로 152번길 210'],
  ['HUB-02', '송파 동남권 센터', '서울', '서울특별시 송파구 송파대로 55 동남권물류단지 B동'],
  ['HUB-03', '인천 공항 저온센터', '인천', '인천광역시 중구 공항동로 296번길 98-114'],
  ['HUB-04', '용인 의약품 센터', '용인', '경기도 용인시 처인구 백암면 죽양대로 904번길 18'],
  ['HUB-05', '대전 중부 허브', '대전', '대전광역시 대덕구 신일서로 68번길 12'],
  ['HUB-06', '오송 바이오 물류센터', '청주', '충청북도 청주시 흥덕구 오송읍 오송생명11로 186'],
  ['HUB-07', '원주 의료기기 센터', '원주', '강원특별자치도 원주시 지정면 기업도시로 200'],
  ['HUB-08', '대구 경북 저온허브', '대구', '대구광역시 달서구 성서공단북로 132'],
  ['HUB-09', '부산 신항 콜드센터', '부산', '부산광역시 강서구 신항남로 330'],
  ['HUB-10', '광주 호남 신선센터', '광주', '광주광역시 광산구 평동산단7번로 93'],
  ['HUB-11', '전주 식품안전 센터', '전주', '전북특별자치도 전주시 덕진구 혁신로 463'],
  ['HUB-12', '제주 생물자원 센터', '제주', '제주특별자치도 제주시 첨단로 213-3'],
].map(([id, name, city, address]) => ({ id, name, city, address }))

const surnames = ['김', '이', '박', '최', '정', '강', '조', '윤', '장', '임', '남궁', '황보']
const givenNames = ['준', '서연', '민수', '지우', '현우', '수빈', '도윤', '하늘']
const cargoNames = [
  '인슐린 주사제',
  '신선 딸기',
  '임상 검체',
  '냉동 연어 필렛',
  '세포치료제 연구용 배치',
  '저온 유통 생백신 2차 국가예방접종 공급분',
  '프리미엄 제주산 생갈치 산지직송 포장세트',
  '희귀질환 유전자 분석용 전혈 및 혈장 혼합 검체',
]
const notes = [
  '',
  '도착 30분 전 담당자 연락',
  '충격 주의',
  '병원 하역장 진입 전 보안실 확인\n수령 담당자 서명 필수',
  '온도 이탈 시 즉시 운행을 중단하고 관제센터에 연락한 뒤 예비 냉매 상태를 확인할 것',
]
const statuses: ShipmentStatus[] = ['normal', 'temperature-excursion', 'delayed', 'sensor-offline', 'resolved']
const temperatureStates: TemperatureState[] = ['normal', 'warning', 'critical', 'unavailable']

function pad(value: number, width = 3): string {
  return String(value).padStart(width, '0')
}

function atHour(offset: number): string {
  return new Date(Date.UTC(2026, 7, 13, 0, offset, 0)).toISOString()
}

function createDrivers(): Driver[] {
  return surnames.flatMap((surname, surnameIndex) =>
    givenNames.map((givenName, givenIndex) => {
      const index = surnameIndex * givenNames.length + givenIndex + 1
      return {
        id: `DRV-${pad(index)}`,
        name: `${surname}${givenName}`,
        phone: `010-${pad(1200 + index, 4)}-${pad(4300 + index, 4)}`,
        homeHubId: hubs[(index - 1) % hubs.length].id,
        certifications: index % 3 === 0 ? ['의약품', '냉동'] : index % 2 === 0 ? ['신선식품'] : ['의약품'],
        active: index % 11 !== 0,
      }
    }),
  )
}

function createVehicles(): Vehicle[] {
  return Array.from({ length: 42 }, (_, offset) => {
    const index = offset + 1
    return {
      id: `VEH-${pad(index)}`,
      plate: `${80 + (index % 20)}가 ${pad(1000 + index, 4)}`,
      model: ['1톤 냉장탑차', '3.5톤 냉동탑차', '전기 저온밴'][index % 3],
      temperatureClass: (['chilled', 'frozen', 'dual'] as const)[index % 3],
      homeHubId: hubs[offset % hubs.length].id,
      active: index % 13 !== 0,
    }
  })
}

function createShipments(drivers: Driver[], vehicles: Vehicle[]): Shipment[] {
  return Array.from({ length: 64 }, (_, offset) => {
    const index = offset + 1
    const status = statuses[offset % statuses.length]
    const temperatureState = temperatureStates[offset % temperatureStates.length]
    const origin = hubs[offset % hubs.length]
    const destination = hubs[(offset * 5 + 3) % hubs.length]
    const frozen = index % 3 === 0
    const minTemperature = frozen ? -20.5 : index % 4 === 0 ? 2.5 : 0
    const maxTemperature = frozen ? -15 : index % 4 === 0 ? 8 : 5.5
    return {
      id: `SHP-${pad(index)}`,
      trackingCode: `CC-20260813-${pad(41000 + index, 5)}-${String.fromCharCode(64 + ((index % 26) || 26))}`,
      cargoName: cargoNames[offset % cargoNames.length],
      originHubId: origin.id,
      destinationHubId: destination.id,
      originAddress: origin.address,
      destinationAddress: destination.address,
      driverId: drivers[(offset * 7) % drivers.length].id,
      vehicleId: vehicles[(offset * 5) % vehicles.length].id,
      status,
      temperatureState,
      currentTemperature: status === 'sensor-offline' ? null : Number((minTemperature + 2.3 + (offset % 7) * 0.7).toFixed(1)),
      minTemperature,
      maxTemperature,
      eta: atHour(180 + offset * 19),
      alertCount: temperatureState === 'normal' ? 0 : (offset % 4) + 1,
      notes: notes[offset % notes.length],
    }
  })
}

function createAlerts(shipments: Shipment[]): Alert[] {
  return Array.from({ length: 30 }, (_, offset) => {
    const index = offset + 1
    const shipment = index === 30 ? shipments[0] : shipments[offset % shipments.length]
    const severity = (['info', 'warning', 'critical'] as const)[offset % 3]
    return {
      id: `ALT-${pad(index)}`,
      shipmentId: shipment.id,
      severity,
      title: severity === 'critical' ? '허용 온도 범위 이탈' : severity === 'warning' ? '도착 예정 지연' : '센서 데이터 복구',
      message: `${shipment.trackingCode} 운송 건의 상태를 확인해 주세요. 최근 측정값과 조치 이력을 함께 검토해야 합니다.`,
      createdAt: atHour(720 + offset * 11),
      read: offset % 4 === 0,
      resolution: offset % 7 === 0 ? 'acknowledged' : 'open',
    }
  })
}

function createEvents(shipments: Shipment[]): Record<string, TimelineEvent[]> {
  return Object.fromEntries(
    shipments.map((shipment, shipmentIndex) => {
      const count = 12 + (shipmentIndex % 29)
      const events = Array.from({ length: count }, (_, offset): TimelineEvent => ({
        id: `${shipment.id}-EVT-${pad(offset + 1)}`,
        shipmentId: shipment.id,
        kind: (['temperature', 'location', 'sensor', 'action'] as const)[offset % 4],
        occurredAt: atHour(shipmentIndex * 7 + offset * 13),
        title: ['온도 측정', '거점 통과', '센서 상태 변경', '관제 담당자 조치'][offset % 4],
        detail: offset % 5 === 0
          ? '온도 변화가 허용 범위에 근접하여 다음 측정 주기를 단축하고 운송 기사에게 확인을 요청했습니다.'
          : `${shipment.trackingCode} 자동 기록 ${offset + 1}`,
        temperature: offset % 4 === 0 && shipment.currentTemperature !== null
          ? Number((shipment.currentTemperature + ((offset % 3) - 1) * 0.4).toFixed(1))
          : null,
      }))
      return [shipment.id, events]
    }),
  )
}

function createAnomalySeries(): AnomalyPoint[] {
  return Array.from({ length: 24 }, (_, hour) => ({
    hour: `${pad(hour, 2)}:00`,
    warning: (hour * 3 + 2) % 9,
    critical: (hour * 5 + 1) % 5,
  }))
}

export function createExperimentData(): ExperimentData {
  const drivers = createDrivers()
  const vehicles = createVehicles()
  const shipments = createShipments(drivers, vehicles)
  return {
    shipments,
    drivers,
    vehicles,
    hubs: hubs.map((hub) => ({ ...hub })),
    alerts: createAlerts(shipments),
    eventsByShipment: createEvents(shipments),
    anomalySeries: createAnomalySeries(),
  }
}
```

- [ ] **Step 5: Run the fixture contract and fix only deterministic-data errors**

Run:

```bash
cd experiments/design-workflow-dashboard
npm run test:common
```

Expected: six tests pass. If a test fails, correct the generator without weakening counts or pressure assertions.

- [ ] **Step 6: Write the common product brief without hidden preferences**

Create `common/product-brief.md` with only these facts:

```markdown
# 콜드체인 물류 관제 대시보드

교대 근무 중인 물류 관제 담당자가 사용하는 한국어 데스크톱 웹 앱의 인터랙티브 목업을 만든다. 담당자는 진행 중 운송과 이상 상태를 빠르게 파악하고, 여러 조건으로 운송을 좁혀 다수 건을 일괄 조치하며, 운송 상세·센서 변화·조치 이력을 확인하고, 기사·차량·허브 배차 정보를 수정하고, 알림의 읽음·처리 상태를 바꾼다.

고정 fixture에는 운송 64건, 기사 96명, 차량 42대, 물류센터 12곳, 알림 30건과 운송별 12~40개의 이력이 있다. 정상, 온도 이탈, 배송 지연, 센서 단절, 조치 완료를 포함하며 짧고 긴 이름·식별자·화물명·주소·메모와 음수·소수 온도, 값 없음, 오류 상태가 섞여 있다.

추가 질문 없이 합리적인 제품 가정을 세우고 완성한다. 백엔드, 인증, 데이터베이스, API는 만들지 않으며 변경은 브라우저 메모리에만 반영한다. 1440×900과 1024×768에서 주요 과업을 수행할 수 있어야 한다.
```

Do not add the user's dislikes, evaluation categories, suggested UI patterns, or preferred visual style.

- [ ] **Step 7: Write the functional contract and neutral hooks**

Create `common/functional-contract.md`. It must require:

```markdown
# Functional contract

## Required surfaces and behavior
- Show operational KPIs and an hourly temperature-anomaly trend.
- Show all 64 shipments in a data table with row and visible-all selection, status, tracking code, cargo, route, driver, vehicle, current temperature, allowed range, ETA, and alert information.
- Apply date, status, hub, temperature-state, and driver filters; sort at least the temperature column.
- Apply an in-memory bulk status action to selected shipments.
- Open shipment detail without leaving the dashboard; include current information, temperature trend, sensor events, and action history with enough data to exceed the available display area.
- Edit driver name, phone, tracking code, assigned driver, vehicle, origin, destination, shipment status, minimum temperature, maximum temperature, and notes. Driver choice uses all 96 candidates. Save, cancel, validation error, and save success must work in memory.
- Put a notifications button in the dashboard header. It opens all 30 notifications without leaving the current dashboard and allows read and resolution state changes.
- Reproduce `?demo=loading`, `?demo=empty`, and `?demo=error`; default or `?demo=default` shows the working dashboard.

## Stable automation hooks
Place `data-testid` on the semantic control or state represented by each identifier:
`app-root`, `loading-state`, `empty-state`, `error-state`, `filter-trigger`, `filters-surface`, `filter-status`, `filter-status-option-temperature-excursion`, `filter-hub`, `filter-hub-option-HUB-12`, `filter-date`, `filter-temperature`, `filter-driver`, `filter-apply`, `results-count`, `sort-temperature`, `select-all-visible`, `row-select-SHP-001`, `bulk-action-trigger`, `bulk-resolve`, `shipment-status-SHP-001`, `notifications-trigger`, `notifications-surface`, `notification-ALT-030`, `notification-toggle-read-ALT-030`, `notification-state-ALT-030`, `notification-toggle-resolution-ALT-030`, `notification-resolution-ALT-030`, `shipment-open-SHP-001`, `shipment-detail`, `edit-dispatch`, `driver-control`, `driver-options`, `driver-option-DRV-096`, `dispatch-driver-name`, `dispatch-phone`, `dispatch-tracking`, `dispatch-min-temperature`, `dispatch-max-temperature`, `dispatch-notes`, `save-dispatch`, `cancel-dispatch`, `dispatch-driver`, `validation-error`, `save-success`.

Use native checkbox inputs for `select-all-visible` and row-selection hooks. For a native `<select>`, use the domain ID as the option value. For a custom selector, make the matching option hook clickable. Put `data-state="unread|read"` on `notification-state-ALT-030` and `data-state="open|acknowledged|resolved"` on `notification-resolution-ALT-030`. The six dispatch field hooks belong on their actual form controls. The hook names do not prescribe component type, layout, dimensions, list navigation, search, overlay behavior, or styling. Choose those as part of the implementation.

## Technical limits
Use React, TypeScript, Vite, `lucide-react`, CSS, HTML, SVG, and browser APIs already present in the root lockfile. Do not add dependencies or import runtime code from outside the assigned variant directory. Copy the supplied `types.ts` and `fixtures.ts` unchanged into `src/`.
```

- [ ] **Step 8: Run the common gate and commit**

Run:

```bash
cd experiments/design-workflow-dashboard
npm run test:common
npm ls --depth=0
git diff --check
```

Expected: six fixture tests pass, dependency versions are exact, and `git diff --check` emits nothing.

Commit from repository root:

```bash
git add experiments/design-workflow-dashboard
git commit -m "Add dashboard experiment common foundation"
```
