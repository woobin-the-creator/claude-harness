import { useMemo, useState } from 'react'
import {
  AlertTriangle,
  Bell,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  CircleAlert,
  Clock3,
  MapPin,
  PencilLine,
  RefreshCw,
  Search,
  WifiOff,
  SlidersHorizontal,
  Thermometer,
  Truck,
  UserRound,
  X,
} from 'lucide-react'
import { createExperimentData } from './fixtures'
import type {
  Alert,
  Driver,
  Shipment,
  ShipmentStatus,
  TemperatureState,
  TimelineEvent,
} from './types'

const initialData = createExperimentData()

const statusCopy: Record<ShipmentStatus, string> = {
  normal: '정상 운송',
  'temperature-excursion': '온도 이탈',
  delayed: '배송 지연',
  'sensor-offline': '센서 단절',
  resolved: '조치 완료',
}

const temperatureCopy: Record<TemperatureState, string> = {
  normal: '정상',
  warning: '주의',
  critical: '위험',
  unavailable: '측정 불가',
}

const resolutionCopy = {
  open: '미처리',
  acknowledged: '확인 중',
  resolved: '처리 완료',
} as const

type FilterState = {
  date: string
  status: '' | ShipmentStatus
  hub: string
  temperature: '' | TemperatureState
  driver: string
}

type DispatchDraft = {
  driverName: string
  phone: string
  trackingCode: string
  driverId: string
  vehicleId: string
  originHubId: string
  destinationHubId: string
  status: ShipmentStatus
  minTemperature: string
  maxTemperature: string
  notes: string
}

const emptyFilters: FilterState = {
  date: '',
  status: '',
  hub: '',
  temperature: '',
  driver: '',
}

function formatTime(value: string) {
  return new Intl.DateTimeFormat('ko-KR', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value))
}

function temperatureLabel(value: number | null) {
  return value === null ? '값 없음' : `${value.toFixed(1)}°C`
}

function makeDraft(shipment: Shipment, driver: Driver): DispatchDraft {
  return {
    driverName: driver.name,
    phone: driver.phone,
    trackingCode: shipment.trackingCode,
    driverId: shipment.driverId,
    vehicleId: shipment.vehicleId,
    originHubId: shipment.originHubId,
    destinationHubId: shipment.destinationHubId,
    status: shipment.status,
    minTemperature: String(shipment.minTemperature),
    maxTemperature: String(shipment.maxTemperature),
    notes: shipment.notes,
  }
}

function LogoMark() {
  return (
    <div className="logoMark" aria-hidden="true">
      <span>C</span>
      <i />
    </div>
  )
}

function SkeletonState() {
  return (
    <main className="stateShell" data-testid="loading-state" aria-busy="true" aria-label="운송 데이터 불러오는 중">
      <div className="skeletonTop">
        <span className="skeletonBlock wide" />
        <span className="skeletonBlock button" />
      </div>
      <div className="skeletonKpis">
        {[0, 1, 2, 3, 4].map((item) => <span className="skeletonBlock kpi" key={item} />)}
      </div>
      <div className="skeletonChart"><span className="skeletonLine" /></div>
      <div className="skeletonToolbar">
        <span className="skeletonBlock button" />
        <span className="skeletonBlock medium" />
        <span className="skeletonBlock button" />
      </div>
      <div className="skeletonTable">
        {[0, 1, 2, 3, 4, 5, 6, 7].map((row) => (
          <div className="skeletonRow" key={row}>
            {[32, 74, 126, 190, 82, 92, 68, 58, 74].map((width, cell) => (
              <span className="skeletonCell" style={{ width }} key={cell} />
            ))}
          </div>
        ))}
      </div>
      <p className="stateHint">운송·센서 정보를 안전하게 불러오고 있습니다.</p>
    </main>
  )
}

function DemoState({ kind }: { kind: 'empty' | 'error' }) {
  if (kind === 'error') {
    return (
      <main className="stateShell compactState" data-testid="error-state">
        <div className="stateIcon errorIcon"><AlertTriangle size={22} /></div>
        <p className="eyebrow">연결 오류 · 12:58</p>
        <h1>운송 데이터를 가져오지 못했습니다</h1>
        <p>마지막 동기화 데이터는 유지됩니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.</p>
        <button className="button primary" type="button" onClick={() => window.location.reload()}>
          <RefreshCw size={15} /> 다시 불러오기
        </button>
      </main>
    )
  }

  return (
    <main className="stateShell compactState" data-testid="empty-state">
      <div className="stateIcon"><Truck size={22} /></div>
      <p className="eyebrow">현재 배차 0건</p>
      <h1>진행 중인 운송이 없습니다</h1>
      <p>새 배차가 등록되면 이 화면에 운송 경로와 센서 상태가 표시됩니다.</p>
      <button className="button" type="button" onClick={() => window.location.search = '?demo=default'}>
        데모 데이터 보기
      </button>
    </main>
  )
}

function TrendChart() {
  const width = 720
  const height = 110
  const max = 9
  const line = (key: 'warning' | 'critical') => initialData.anomalySeries
    .map((point, index) => {
      const x = (index / 23) * width
      const y = height - (point[key] / max) * (height - 16) - 8
      return `${index === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`
    }).join(' ')

  return (
    <figure className="trendCard">
      <figcaption>
        <div>
          <p className="eyebrow">최근 24시간</p>
          <h2>시간대별 온도 이상</h2>
        </div>
        <div className="chartLegend" aria-hidden="true">
          <span><i className="warningDot" />주의</span>
          <span><i className="criticalDot" />위험</span>
        </div>
      </figcaption>
      <div className="chartFrame">
        <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-labelledby="trend-title trend-description" preserveAspectRatio="none">
          <title id="trend-title">시간대별 온도 이상 추이</title>
          <desc id="trend-description">24시간 동안의 주의 및 위험 온도 이상 건수</desc>
          {[0, 3, 6, 9].map((tick) => {
            const y = height - (tick / max) * (height - 16) - 8
            return <line className="gridLine" x1="0" x2={width} y1={y} y2={y} key={tick} />
          })}
          <path className="warningLine" d={line('warning')} />
          <path className="criticalLine" d={line('critical')} />
        </svg>
        <div className="chartTicks" aria-hidden="true">
          {['00시', '04시', '08시', '12시', '16시', '20시', '23시'].map((tick) => <span key={tick}>{tick}</span>)}
        </div>
      </div>
      <table className="srOnly">
        <caption>시간대별 온도 이상 건수</caption>
        <thead><tr><th>시간</th><th>주의</th><th>위험</th></tr></thead>
        <tbody>{initialData.anomalySeries.map((point) => <tr key={point.hour}><td>{point.hour}</td><td>{point.warning}</td><td>{point.critical}</td></tr>)}</tbody>
      </table>
    </figure>
  )
}

function KpiStrip({ shipments }: { shipments: Shipment[] }) {
  const items = [
    { label: '진행 운송', value: shipments.filter((item) => item.status !== 'resolved').length, detail: '전체 64건 중', icon: Truck },
    { label: '온도 이탈', value: shipments.filter((item) => item.status === 'temperature-excursion').length, detail: '즉시 확인', icon: Thermometer, urgent: true },
    { label: '배송 지연', value: shipments.filter((item) => item.status === 'delayed').length, detail: 'ETA 경과', icon: Clock3 },
    { label: '센서 단절', value: shipments.filter((item) => item.status === 'sensor-offline').length, detail: '수신 불가', icon: WifiOff },
    { label: '조치 완료', value: shipments.filter((item) => item.status === 'resolved').length, detail: '오늘 누계', icon: CheckCircle2 },
  ]
  return (
    <section className="kpiStrip" aria-label="운송 핵심 지표">
      {items.map(({ label, value, detail, icon: Icon, urgent }) => (
        <article className={urgent ? 'kpiItem urgent' : 'kpiItem'} key={label}>
          <Icon size={17} aria-hidden="true" />
          <div><span>{label}</span><strong>{value}<small>건</small></strong></div>
          <em>{detail}</em>
        </article>
      ))}
    </section>
  )
}

function Filters({
  draft,
  onChange,
  onApply,
  onReset,
}: {
  draft: FilterState
  onChange: (next: FilterState) => void
  onApply: () => void
  onReset: () => void
}) {
  return (
    <section className="filtersSurface" data-testid="filters-surface" aria-label="운송 필터">
      <label className="filterField dateField">
        <span>도착 예정일</span>
        <input data-testid="filter-date" type="date" value={draft.date} onChange={(event) => onChange({ ...draft, date: event.target.value })} />
      </label>
      <label className="filterField statusField">
        <span>운송 상태</span>
        <select data-testid="filter-status" value={draft.status} onChange={(event) => onChange({ ...draft, status: event.target.value as FilterState['status'] })}>
          <option value="">전체 상태</option>
          {(Object.keys(statusCopy) as ShipmentStatus[]).map((status) => (
            <option data-testid={status === 'temperature-excursion' ? 'filter-status-option-temperature-excursion' : undefined} value={status} key={status}>{statusCopy[status]}</option>
          ))}
        </select>
      </label>
      <label className="filterField hubField">
        <span>출발·도착 거점</span>
        <select data-testid="filter-hub" value={draft.hub} onChange={(event) => onChange({ ...draft, hub: event.target.value })}>
          <option value="">전체 거점</option>
          {initialData.hubs.map((hub) => (
            <option data-testid={hub.id === 'HUB-12' ? 'filter-hub-option-HUB-12' : undefined} value={hub.id} key={hub.id}>{hub.name}</option>
          ))}
        </select>
      </label>
      <label className="filterField tempField">
        <span>온도 상태</span>
        <select data-testid="filter-temperature" value={draft.temperature} onChange={(event) => onChange({ ...draft, temperature: event.target.value as FilterState['temperature'] })}>
          <option value="">전체 온도</option>
          {(Object.keys(temperatureCopy) as TemperatureState[]).map((state) => <option value={state} key={state}>{temperatureCopy[state]}</option>)}
        </select>
      </label>
      <label className="filterField driverField">
        <span>기사</span>
        <select data-testid="filter-driver" value={draft.driver} onChange={(event) => onChange({ ...draft, driver: event.target.value })}>
          <option value="">전체 기사</option>
          {initialData.drivers.map((driver) => <option value={driver.id} key={driver.id}>{driver.name} · {driver.id}</option>)}
        </select>
      </label>
      <div className="filterActions">
        <button className="button quiet" type="button" onClick={onReset}>초기화</button>
        <button className="button primary" data-testid="filter-apply" type="button" onClick={onApply}>필터 적용</button>
      </div>
    </section>
  )
}

function StatusBadge({ status, testId }: { status: ShipmentStatus; testId?: string }) {
  return <span className={`statusBadge status-${status}`} data-testid={testId}>{statusCopy[status]}</span>
}

function ShipmentTable({
  shipments,
  drivers,
  selected,
  sortDirection,
  onSort,
  onToggleAll,
  onToggle,
  onOpen,
}: {
  shipments: Shipment[]
  drivers: Driver[]
  selected: Set<string>
  sortDirection: 'asc' | 'desc'
  onSort: () => void
  onToggleAll: () => void
  onToggle: (id: string) => void
  onOpen: (id: string) => void
}) {
  const hub = (id: string) => initialData.hubs.find((item) => item.id === id)!
  const driver = (id: string) => drivers.find((item) => item.id === id)!
  const vehicle = (id: string) => initialData.vehicles.find((item) => item.id === id)!
  const allSelected = shipments.length > 0 && shipments.every((item) => selected.has(item.id))

  return (
    <div className="tableScroller">
      <table className="shipmentTable">
        <colgroup>
          <col className="colCheck" /><col className="colStatus" /><col className="colTracking" /><col className="colCargo" />
          <col className="colRoute" /><col className="colDriver" /><col className="colVehicle" /><col className="colTemp" />
          <col className="colRange" /><col className="colEta" /><col className="colAlert" />
        </colgroup>
        <thead>
          <tr>
            <th className="checkCell"><input aria-label="현재 보이는 운송 전체 선택" data-testid="select-all-visible" type="checkbox" checked={allSelected} onChange={onToggleAll} /></th>
            <th>상태</th><th>운송 번호</th><th>화물</th><th>경로</th><th>기사</th><th>차량</th>
            <th aria-sort={sortDirection === 'asc' ? 'ascending' : 'descending'}>
              <button className="sortButton" data-testid="sort-temperature" type="button" onClick={onSort}>현재 온도 <ChevronDown className={sortDirection === 'asc' ? 'sortUp' : ''} size={13} /></button>
            </th>
            <th>허용 범위</th><th>도착 예정</th><th>알림</th>
          </tr>
        </thead>
        <tbody>
          {shipments.length === 0 ? (
            <tr><td className="inlineEmpty" colSpan={11}>조건에 맞는 운송이 없습니다. 필터를 초기화해 전체 운송을 확인하세요.</td></tr>
          ) : shipments.map((shipment) => {
            const assignedDriver = driver(shipment.driverId)
            const assignedVehicle = vehicle(shipment.vehicleId)
            return (
              <tr className={selected.has(shipment.id) ? 'selectedRow' : ''} key={shipment.id}>
                <td className="checkCell"><input aria-label={`${shipment.id} 선택`} data-testid={shipment.id === 'SHP-001' ? 'row-select-SHP-001' : undefined} type="checkbox" checked={selected.has(shipment.id)} onChange={() => onToggle(shipment.id)} /></td>
                <td><StatusBadge status={shipment.status} testId={shipment.id === 'SHP-001' ? 'shipment-status-SHP-001' : undefined} /></td>
                <td>
                  <button className="trackingButton" data-testid={shipment.id === 'SHP-001' ? 'shipment-open-SHP-001' : undefined} type="button" onClick={() => onOpen(shipment.id)}>
                    <strong>{shipment.id}</strong><small>{shipment.trackingCode}</small>
                  </button>
                </td>
                <td><span className="clampCell" title={shipment.cargoName}>{shipment.cargoName}</span></td>
                <td><span className="routeCell"><b>{hub(shipment.originHubId).city}</b><ChevronRight size={12} /><b>{hub(shipment.destinationHubId).city}</b></span></td>
                <td><span className="stackCell"><strong>{assignedDriver.name}</strong><small>{assignedDriver.id}</small></span></td>
                <td><span className="stackCell"><strong>{assignedVehicle.plate}</strong><small>{assignedVehicle.model}</small></span></td>
                <td><strong className={`temperatureValue temp-${shipment.temperatureState}`}>{temperatureLabel(shipment.currentTemperature)}</strong></td>
                <td>{shipment.minTemperature}~{shipment.maxTemperature}°C</td>
                <td><span className="stackCell"><strong>{formatTime(shipment.eta).split(' ')[0]}</strong><small>{formatTime(shipment.eta).split(' ').slice(1).join(' ')}</small></span></td>
                <td>{shipment.alertCount > 0 ? <span className="alertCount"><CircleAlert size={13} />{shipment.alertCount}</span> : <span className="noAlert">없음</span>}</td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

function MiniTemperatureChart({ events, shipment }: { events: TimelineEvent[]; shipment: Shipment }) {
  const points = events.filter((event) => event.temperature !== null)
  const values = points.map((point) => point.temperature as number)
  const dataMin = Math.min(shipment.minTemperature - 2, ...values)
  const dataMax = Math.max(shipment.maxTemperature + 2, ...values)
  const path = points.map((point, index) => {
    const x = points.length === 1 ? 150 : (index / (points.length - 1)) * 300
    const y = 74 - (((point.temperature as number) - dataMin) / (dataMax - dataMin || 1)) * 60
    return `${index === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`
  }).join(' ')
  const rangeTop = 74 - ((shipment.maxTemperature - dataMin) / (dataMax - dataMin || 1)) * 60
  const rangeBottom = 74 - ((shipment.minTemperature - dataMin) / (dataMax - dataMin || 1)) * 60

  return (
    <figure className="miniChart">
      <figcaption><strong>센서 온도 추이</strong><span>허용 {shipment.minTemperature}~{shipment.maxTemperature}°C</span></figcaption>
      <svg viewBox="0 0 300 82" role="img" aria-label={`${shipment.id} 센서 온도 추이`} preserveAspectRatio="none">
        <rect className="safeBand" x="0" width="300" y={rangeTop} height={Math.max(2, rangeBottom - rangeTop)} />
        <path className="temperaturePath" d={path} />
        {points.map((point, index) => {
          const x = points.length === 1 ? 150 : (index / (points.length - 1)) * 300
          const y = 74 - (((point.temperature as number) - dataMin) / (dataMax - dataMin || 1)) * 60
          return <circle className="temperatureDot" cx={x} cy={y} r="2.2" key={point.id} />
        })}
      </svg>
    </figure>
  )
}

function DriverSelector({
  drivers,
  selectedId,
  onSelect,
}: {
  drivers: Driver[]
  selectedId: string
  onSelect: (driver: Driver) => void
}) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const selected = drivers.find((driver) => driver.id === selectedId)!
  const candidates = drivers.filter((driver) => `${driver.name} ${driver.id} ${driver.phone} ${driver.certifications.join(' ')}`.toLowerCase().includes(query.toLowerCase()))

  return (
    <div className="driverSelector" data-testid="dispatch-driver">
      <span className="formLabel">배정 기사 <b aria-hidden="true">*</b></span>
      <button className="selectButton" data-testid="driver-control" type="button" aria-expanded={open} aria-controls="driver-options" onClick={() => setOpen(!open)}>
        <span><strong>{selected.name}</strong><small>{selected.id} · {selected.phone}</small></span><ChevronDown size={15} />
      </button>
      {open && (
        <div className="driverPopover" id="driver-options" data-testid="driver-options">
          <label className="driverSearch"><Search size={14} /><span className="srOnly">기사 검색</span><input autoFocus placeholder="이름, ID, 전화번호, 자격 검색" value={query} onChange={(event) => setQuery(event.target.value)} /></label>
          <p className="searchCount">검색 결과 {candidates.length}명</p>
          <div className="driverList">
            {candidates.map((driver) => (
              <button
                className={driver.id === selectedId ? 'driverOption active' : 'driverOption'}
                data-testid={driver.id === 'DRV-096' ? 'driver-option-DRV-096' : undefined}
                type="button"
                key={driver.id}
                onClick={() => { onSelect(driver); setOpen(false); setQuery('') }}
              >
                <span><strong>{driver.name}</strong><small>{driver.id} · {driver.phone}</small></span>
                <span className="driverMeta">{driver.certifications.join(' · ')}{!driver.active && <em> · 현재 비활성</em>}</span>
                {driver.id === selectedId && <Check size={14} />}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function DispatchForm({
  shipment,
  drivers,
  draft,
  error,
  onChange,
  onCancel,
  onSave,
}: {
  shipment: Shipment
  drivers: Driver[]
  draft: DispatchDraft
  error: string
  onChange: (next: DispatchDraft) => void
  onCancel: () => void
  onSave: () => void
}) {
  return (
    <form className="dispatchForm" onSubmit={(event) => { event.preventDefault(); onSave() }}>
      <div className="formHeading">
        <div><p className="eyebrow">{shipment.id}</p><h3>배차·운송 정보 수정</h3></div>
        <span><b aria-hidden="true">*</b> 필수 입력</span>
      </div>
      <DriverSelector drivers={drivers} selectedId={draft.driverId} onSelect={(driver) => onChange({ ...draft, driverId: driver.id, driverName: driver.name, phone: driver.phone })} />
      <div className="formRow compactInputs">
        <label><span>기사 이름 <b aria-hidden="true">*</b></span><input data-testid="dispatch-driver-name" size={8} value={draft.driverName} onChange={(event) => onChange({ ...draft, driverName: event.target.value })} /></label>
        <label><span>연락처 <b aria-hidden="true">*</b></span><input data-testid="dispatch-phone" size={17} value={draft.phone} onChange={(event) => onChange({ ...draft, phone: event.target.value })} /></label>
      </div>
      <label><span>운송 추적 코드 <b aria-hidden="true">*</b></span><input className="trackingInput" data-testid="dispatch-tracking" size={32} value={draft.trackingCode} onChange={(event) => onChange({ ...draft, trackingCode: event.target.value })} /></label>
      <div className="formRow">
        <label><span>출발 거점</span><select value={draft.originHubId} onChange={(event) => onChange({ ...draft, originHubId: event.target.value })}>{initialData.hubs.map((hub) => <option value={hub.id} key={hub.id}>{hub.name}</option>)}</select></label>
        <label><span>도착 거점</span><select value={draft.destinationHubId} onChange={(event) => onChange({ ...draft, destinationHubId: event.target.value })}>{initialData.hubs.map((hub) => <option value={hub.id} key={hub.id}>{hub.name}</option>)}</select></label>
      </div>
      <div className="formRow">
        <label><span>배정 차량</span><select value={draft.vehicleId} onChange={(event) => onChange({ ...draft, vehicleId: event.target.value })}>{initialData.vehicles.map((vehicle) => <option value={vehicle.id} key={vehicle.id}>{vehicle.plate} · {vehicle.model}</option>)}</select></label>
        <label><span>운송 상태</span><select value={draft.status} onChange={(event) => onChange({ ...draft, status: event.target.value as ShipmentStatus })}>{(Object.keys(statusCopy) as ShipmentStatus[]).map((status) => <option value={status} key={status}>{statusCopy[status]}</option>)}</select></label>
      </div>
      <fieldset className="temperatureFields">
        <legend>허용 온도 범위 <b aria-hidden="true">*</b></legend>
        <label><span>최저</span><span className="unitInput"><input data-testid="dispatch-min-temperature" type="number" step="0.1" value={draft.minTemperature} onChange={(event) => onChange({ ...draft, minTemperature: event.target.value })} /><em>°C</em></span></label>
        <span className="rangeDash">—</span>
        <label><span>최고</span><span className="unitInput"><input data-testid="dispatch-max-temperature" type="number" step="0.1" value={draft.maxTemperature} onChange={(event) => onChange({ ...draft, maxTemperature: event.target.value })} /><em>°C</em></span></label>
      </fieldset>
      <label><span>운송 메모</span><textarea data-testid="dispatch-notes" rows={3} value={draft.notes} onChange={(event) => onChange({ ...draft, notes: event.target.value })} placeholder="현장 인계 사항을 입력하세요" /></label>
      {error && <p className="validationError" data-testid="validation-error" role="alert"><CircleAlert size={14} />{error}</p>}
      <div className="formFooter">
        <button className="button" data-testid="cancel-dispatch" type="button" onClick={onCancel}>취소</button>
        <button className="button primary" data-testid="save-dispatch" type="submit">변경 저장</button>
      </div>
    </form>
  )
}

function ShipmentDetail({
  shipment,
  drivers,
  events,
  editing,
  draft,
  error,
  saveSuccess,
  onClose,
  onStartEdit,
  onDraftChange,
  onCancelEdit,
  onSave,
}: {
  shipment: Shipment
  drivers: Driver[]
  events: TimelineEvent[]
  editing: boolean
  draft: DispatchDraft | null
  error: string
  saveSuccess: boolean
  onClose: () => void
  onStartEdit: () => void
  onDraftChange: (next: DispatchDraft) => void
  onCancelEdit: () => void
  onSave: () => void
}) {
  const driver = drivers.find((item) => item.id === shipment.driverId)!
  const vehicle = initialData.vehicles.find((item) => item.id === shipment.vehicleId)!
  const origin = initialData.hubs.find((item) => item.id === shipment.originHubId)!
  const destination = initialData.hubs.find((item) => item.id === shipment.destinationHubId)!

  return (
    <div className="scrim" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose() }}>
      <aside className="sidePanel detailPanel" data-testid="shipment-detail" role="dialog" aria-modal="true" aria-labelledby="shipment-title">
        <header className="panelHeader">
          <div><p className="eyebrow">운송 상세 · {shipment.id}</p><h2 id="shipment-title">{shipment.cargoName}</h2></div>
          <button className="iconButton" aria-label="운송 상세 닫기" type="button" onClick={onClose}><X size={18} /></button>
        </header>
        {saveSuccess && <div className="saveSuccess" data-testid="save-success" role="status"><CheckCircle2 size={15} />변경 사항을 저장했습니다.</div>}
        <div className="panelScroll">
          {editing && draft ? (
            <DispatchForm shipment={shipment} drivers={drivers} draft={draft} error={error} onChange={onDraftChange} onCancel={onCancelEdit} onSave={onSave} />
          ) : (
            <>
              <section className="detailSummary">
                <div className="summaryTop">
                  <StatusBadge status={shipment.status} />
                  <button className="button small" data-testid="edit-dispatch" type="button" onClick={onStartEdit}><PencilLine size={14} />배차 수정</button>
                </div>
                <p className="trackingCode">{shipment.trackingCode}</p>
                <dl className="detailGrid">
                  <div><dt>현재 온도</dt><dd className={`temp-${shipment.temperatureState}`}>{temperatureLabel(shipment.currentTemperature)}</dd></div>
                  <div><dt>허용 범위</dt><dd>{shipment.minTemperature}~{shipment.maxTemperature}°C</dd></div>
                  <div><dt>도착 예정</dt><dd>{formatTime(shipment.eta)}</dd></div>
                  <div><dt>활성 알림</dt><dd>{shipment.alertCount}건</dd></div>
                </dl>
              </section>
              <section className="routeSummary">
                <div><MapPin size={15} /><span><small>출발</small><strong>{origin.name}</strong><em>{shipment.originAddress}</em></span></div>
                <i />
                <div><MapPin size={15} /><span><small>도착</small><strong>{destination.name}</strong><em>{shipment.destinationAddress}</em></span></div>
              </section>
              <section className="assignmentSummary">
                <div><UserRound size={15} /><span><small>운송 기사</small><strong>{driver.name} · {driver.phone}</strong><em>{driver.id} · {driver.certifications.join(', ')}</em></span></div>
                <div><Truck size={15} /><span><small>배정 차량</small><strong>{vehicle.plate}</strong><em>{vehicle.model} · {vehicle.temperatureClass}</em></span></div>
              </section>
              {shipment.notes && <section className="notesBlock"><p className="eyebrow">운송 메모</p><p>{shipment.notes}</p></section>}
              <MiniTemperatureChart events={events} shipment={shipment} />
              <section className="timelineSection">
                <div className="sectionTitle"><div><p className="eyebrow">센서·위치·조치</p><h3>전체 이력</h3></div><span className="countTag">{events.length}건</span></div>
                <ol className="timeline">
                  {[...events].reverse().map((event) => (
                    <li key={event.id}>
                      <i className={`eventDot event-${event.kind}`} />
                      <div><span><strong>{event.title}</strong><time>{formatTime(event.occurredAt)}</time></span><p>{event.detail}</p>{event.temperature !== null && <em>{event.temperature.toFixed(1)}°C</em>}</div>
                    </li>
                  ))}
                </ol>
              </section>
            </>
          )}
        </div>
      </aside>
    </div>
  )
}

function NotificationsPanel({ alerts, onClose, onToggleRead, onToggleResolution }: {
  alerts: Alert[]
  onClose: () => void
  onToggleRead: (id: string) => void
  onToggleResolution: (id: string) => void
}) {
  return (
    <div className="scrim" role="presentation" onMouseDown={(event) => { if (event.currentTarget === event.target) onClose() }}>
      <aside className="sidePanel notificationPanel" data-testid="notifications-surface" role="dialog" aria-modal="true" aria-labelledby="notification-title">
        <header className="panelHeader">
          <div><p className="eyebrow">전체 알림 {alerts.length}건</p><h2 id="notification-title">운영 알림</h2></div>
          <button className="iconButton" aria-label="알림 닫기" type="button" onClick={onClose}><X size={18} /></button>
        </header>
        <div className="notificationLegend"><span><i className="unreadMark" />읽지 않음</span><span>처리 상태는 알림별로 변경됩니다.</span></div>
        <div className="notificationList">
          {[...alerts].reverse().map((alert) => (
            <article className={alert.read ? 'notificationItem read' : 'notificationItem'} data-testid={alert.id === 'ALT-030' ? 'notification-ALT-030' : undefined} key={alert.id}>
              <div className="notificationMeta">
                <span className={`severity severity-${alert.severity}`}>{alert.severity === 'critical' ? '위험' : alert.severity === 'warning' ? '주의' : '안내'}</span>
                <time>{formatTime(alert.createdAt)}</time>
                {!alert.read && <i className="unreadMark" aria-label="읽지 않음" />}
              </div>
              <h3>{alert.title}</h3>
              <p>{alert.message}</p>
              <button className="shipmentRef" type="button">{alert.shipmentId}<ChevronRight size={12} /></button>
              <div className="notificationActions">
                <span data-testid={alert.id === 'ALT-030' ? 'notification-state-ALT-030' : undefined} data-state={alert.read ? 'read' : 'unread'}>{alert.read ? '읽음' : '읽지 않음'}</span>
                <button className="button tiny" data-testid={alert.id === 'ALT-030' ? 'notification-toggle-read-ALT-030' : undefined} type="button" onClick={() => onToggleRead(alert.id)}>{alert.read ? '읽지 않음으로' : '읽음으로'}</button>
                <span className={`resolution resolution-${alert.resolution}`} data-testid={alert.id === 'ALT-030' ? 'notification-resolution-ALT-030' : undefined} data-state={alert.resolution}>{resolutionCopy[alert.resolution]}</span>
                <button className="button tiny" data-testid={alert.id === 'ALT-030' ? 'notification-toggle-resolution-ALT-030' : undefined} type="button" onClick={() => onToggleResolution(alert.id)}>{alert.resolution === 'resolved' ? '다시 열기' : '처리 진행'}</button>
              </div>
            </article>
          ))}
        </div>
      </aside>
    </div>
  )
}

export function App() {
  const mode = new URLSearchParams(window.location.search).get('demo') ?? 'default'
  const [shipments, setShipments] = useState(initialData.shipments)
  const [drivers, setDrivers] = useState(initialData.drivers)
  const [alerts, setAlerts] = useState(initialData.alerts)
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [draftFilters, setDraftFilters] = useState<FilterState>(emptyFilters)
  const [appliedFilters, setAppliedFilters] = useState<FilterState>(emptyFilters)
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [bulkOpen, setBulkOpen] = useState(false)
  const [notificationsOpen, setNotificationsOpen] = useState(false)
  const [detailId, setDetailId] = useState<string | null>(null)
  const [editing, setEditing] = useState(false)
  const [dispatchDraft, setDispatchDraft] = useState<DispatchDraft | null>(null)
  const [validationError, setValidationError] = useState('')
  const [saveSuccess, setSaveSuccess] = useState(false)

  const visibleShipments = useMemo(() => shipments
    .filter((shipment) => !appliedFilters.date || shipment.eta.slice(0, 10) === appliedFilters.date)
    .filter((shipment) => !appliedFilters.status || shipment.status === appliedFilters.status)
    .filter((shipment) => !appliedFilters.hub || shipment.originHubId === appliedFilters.hub || shipment.destinationHubId === appliedFilters.hub)
    .filter((shipment) => !appliedFilters.temperature || shipment.temperatureState === appliedFilters.temperature)
    .filter((shipment) => !appliedFilters.driver || shipment.driverId === appliedFilters.driver)
    .sort((left, right) => {
      if (left.currentTemperature === null) return 1
      if (right.currentTemperature === null) return -1
      return sortDirection === 'asc' ? left.currentTemperature - right.currentTemperature : right.currentTemperature - left.currentTemperature
    }), [appliedFilters, shipments, sortDirection])

  const detailShipment = detailId ? shipments.find((shipment) => shipment.id === detailId) ?? null : null
  const activeFilterCount = Object.values(appliedFilters).filter(Boolean).length
  const unreadCount = alerts.filter((alert) => !alert.read).length

  const openShipment = (id: string) => {
    setDetailId(id)
    setEditing(false)
    setValidationError('')
    setSaveSuccess(false)
  }

  const startEditing = () => {
    if (!detailShipment) return
    const assignedDriver = drivers.find((driver) => driver.id === detailShipment.driverId)!
    setDispatchDraft(makeDraft(detailShipment, assignedDriver))
    setValidationError('')
    setSaveSuccess(false)
    setEditing(true)
  }

  const saveDispatch = () => {
    if (!detailShipment || !dispatchDraft) return
    const minimum = Number(dispatchDraft.minTemperature)
    const maximum = Number(dispatchDraft.maxTemperature)
    if (!dispatchDraft.driverName.trim() || !/^010-\d{4}-\d{4}$/.test(dispatchDraft.phone) || !dispatchDraft.trackingCode.trim()) {
      setValidationError('필수 항목과 연락처 형식(010-0000-0000)을 확인해 주세요.')
      return
    }
    if (!Number.isFinite(minimum) || !Number.isFinite(maximum) || minimum >= maximum) {
      setValidationError('최저 온도는 최고 온도보다 낮아야 합니다.')
      return
    }
    setShipments((current) => current.map((shipment) => shipment.id === detailShipment.id ? {
      ...shipment,
      trackingCode: dispatchDraft.trackingCode.trim(),
      driverId: dispatchDraft.driverId,
      vehicleId: dispatchDraft.vehicleId,
      originHubId: dispatchDraft.originHubId,
      destinationHubId: dispatchDraft.destinationHubId,
      originAddress: initialData.hubs.find((hub) => hub.id === dispatchDraft.originHubId)!.address,
      destinationAddress: initialData.hubs.find((hub) => hub.id === dispatchDraft.destinationHubId)!.address,
      status: dispatchDraft.status,
      minTemperature: minimum,
      maxTemperature: maximum,
      notes: dispatchDraft.notes,
    } : shipment))
    setDrivers((current) => current.map((driver) => driver.id === dispatchDraft.driverId ? { ...driver, name: dispatchDraft.driverName.trim(), phone: dispatchDraft.phone } : driver))
    setValidationError('')
    setEditing(false)
    setSaveSuccess(true)
  }

  const toggleAll = () => {
    const allSelected = visibleShipments.length > 0 && visibleShipments.every((shipment) => selected.has(shipment.id))
    setSelected((current) => {
      const next = new Set(current)
      visibleShipments.forEach((shipment) => allSelected ? next.delete(shipment.id) : next.add(shipment.id))
      return next
    })
  }

  const resolveSelected = () => {
    setShipments((current) => current.map((shipment) => selected.has(shipment.id) ? { ...shipment, status: 'resolved' } : shipment))
    setBulkOpen(false)
  }

  const toggleResolution = (id: string) => {
    setAlerts((current) => current.map((alert) => alert.id === id ? {
      ...alert,
      resolution: alert.resolution === 'open' ? 'acknowledged' : alert.resolution === 'acknowledged' ? 'resolved' : 'open',
    } : alert))
  }

  return (
    <div className="appRoot" data-testid="app-root">
      <header className="appHeader">
        <button className="brand" type="button" aria-label="콜드체인 관제실 홈" onClick={() => { setAppliedFilters(emptyFilters); setDraftFilters(emptyFilters) }}>
          <LogoMark /><span><strong>COLD<span>WATCH</span></strong><small>물류 관제실</small></span>
        </button>
        <div className="shiftMeta"><span className="liveDot" />관제 연결 정상 <b>주간조 · 12:58 KST</b></div>
        <button className="notificationButton" data-testid="notifications-trigger" type="button" onClick={() => setNotificationsOpen(true)}>
          <Bell size={17} /><span>알림</span><strong>{unreadCount}</strong>
        </button>
      </header>
      {mode === 'loading' ? <SkeletonState /> : mode === 'empty' ? <DemoState kind="empty" /> : mode === 'error' ? <DemoState kind="error" /> : (
        <main className="dashboard">
          <section className="pageHeading">
            <div><p className="eyebrow">2026년 8월 13일 목요일</p><h1>운송 현황</h1><p>전국 12개 물류 거점의 운송과 온도 센서를 실시간으로 확인합니다.</p></div>
            <p className="syncInfo"><RefreshCw size={13} />마지막 동기화 12:58:24</p>
          </section>
          <KpiStrip shipments={shipments} />
          <TrendChart />
          <section className="operationsPanel">
            <div className="tableToolbar">
              <div className="resultsTitle"><h2>전체 운송</h2><span data-testid="results-count">{visibleShipments.length}건</span><small>선택 {selected.size}건</small></div>
              <div className="toolbarActions">
                <div className="bulkWrapper">
                  <button className="button" data-testid="bulk-action-trigger" type="button" disabled={selected.size === 0} onClick={() => setBulkOpen(!bulkOpen)}>선택 조치 <ChevronDown size={14} /></button>
                  {bulkOpen && <div className="bulkMenu"><p>{selected.size}건 일괄 조치</p><button data-testid="bulk-resolve" type="button" onClick={resolveSelected}><CheckCircle2 size={14} />조치 완료로 변경</button></div>}
                </div>
                <button className={filtersOpen ? 'button filterActive' : 'button'} data-testid="filter-trigger" type="button" aria-expanded={filtersOpen} onClick={() => setFiltersOpen(!filtersOpen)}>
                  <SlidersHorizontal size={15} />필터{activeFilterCount > 0 && <span className="countTag">{activeFilterCount}</span>}
                </button>
              </div>
            </div>
            {filtersOpen && <Filters draft={draftFilters} onChange={setDraftFilters} onApply={() => { setAppliedFilters(draftFilters); setSelected(new Set()) }} onReset={() => { setDraftFilters(emptyFilters); setAppliedFilters(emptyFilters); setSelected(new Set()) }} />}
            <ShipmentTable
              shipments={visibleShipments}
              drivers={drivers}
              selected={selected}
              sortDirection={sortDirection}
              onSort={() => setSortDirection((current) => current === 'asc' ? 'desc' : 'asc')}
              onToggleAll={toggleAll}
              onToggle={(id) => setSelected((current) => { const next = new Set(current); next.has(id) ? next.delete(id) : next.add(id); return next })}
              onOpen={openShipment}
            />
          </section>
        </main>
      )}
      {notificationsOpen && <NotificationsPanel alerts={alerts} onClose={() => setNotificationsOpen(false)} onToggleRead={(id) => setAlerts((current) => current.map((alert) => alert.id === id ? { ...alert, read: !alert.read } : alert))} onToggleResolution={toggleResolution} />}
      {detailShipment && <ShipmentDetail
        shipment={detailShipment}
        drivers={drivers}
        events={initialData.eventsByShipment[detailShipment.id]}
        editing={editing}
        draft={dispatchDraft}
        error={validationError}
        saveSuccess={saveSuccess}
        onClose={() => { setDetailId(null); setEditing(false) }}
        onStartEdit={startEditing}
        onDraftChange={setDispatchDraft}
        onCancelEdit={() => { setEditing(false); setValidationError(''); setDispatchDraft(null) }}
        onSave={saveDispatch}
      />}
    </div>
  )
}
