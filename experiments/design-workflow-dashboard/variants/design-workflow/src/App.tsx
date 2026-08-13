import { useEffect, useMemo, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import {
  Activity,
  AlertTriangle,
  Bell,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  CircleDot,
  Clock3,
  Filter,
  Gauge,
  MapPin,
  Package,
  PencilLine,
  RadioTower,
  Search,
  Snowflake,
  Thermometer,
  Truck,
  UserRound,
  X,
} from 'lucide-react'
import { createExperimentData } from './fixtures'
import type {
  Alert,
  AlertResolution,
  Driver,
  Shipment,
  ShipmentStatus,
  TemperatureState,
  TimelineEvent,
} from './types'

type Filters = {
  status: '' | ShipmentStatus
  hub: string
  date: string
  temperature: '' | TemperatureState
  driver: string
}

type DispatchForm = {
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

const statusLabels: Record<ShipmentStatus, string> = {
  normal: '정상 운송',
  'temperature-excursion': '온도 이탈',
  delayed: '배송 지연',
  'sensor-offline': '센서 단절',
  resolved: '조치 완료',
}

const temperatureLabels: Record<TemperatureState, string> = {
  normal: '정상',
  warning: '주의',
  critical: '위험',
  unavailable: '측정 불가',
}

const resolutionLabels: Record<AlertResolution, string> = {
  open: '미처리',
  acknowledged: '확인됨',
  resolved: '해결됨',
}

const emptyFilters: Filters = {
  status: '',
  hub: '',
  date: '',
  temperature: '',
  driver: '',
}

function timeLabel(value: string) {
  return new Intl.DateTimeFormat('ko-KR', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value))
}

function makeLine(values: number[], width: number, height: number, maxValue?: number) {
  const max = maxValue ?? Math.max(...values, 1)
  return values
    .map((value, index) => {
      const x = 8 + (index / Math.max(values.length - 1, 1)) * (width - 16)
      const y = height - 10 - (value / max) * (height - 24)
      return `${index === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`
    })
    .join(' ')
}

function shipmentToForm(shipment: Shipment, drivers: Driver[]): DispatchForm {
  const driver = drivers.find((item) => item.id === shipment.driverId)
  return {
    driverName: driver?.name ?? '',
    phone: driver?.phone ?? '',
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

function StateScreen({ kind }: { kind: 'loading' | 'empty' | 'error' }) {
  if (kind === 'loading') {
    return (
      <main className="state-screen" data-testid="loading-state" aria-live="polite">
        <div className="loader-orbit"><Snowflake size={30} /></div>
        <p className="eyebrow">관제 데이터 동기화</p>
        <h1>저온선 연결 상태를 확인하고 있습니다</h1>
        <p>운송 64건의 센서 기록과 알림을 안전하게 불러오는 중입니다.</p>
        <div className="loading-bars"><i /><i /><i /></div>
      </main>
    )
  }

  if (kind === 'empty') {
    return (
      <main className="state-screen" data-testid="empty-state">
        <div className="state-icon"><Package size={32} /></div>
        <p className="eyebrow">현재 운송 0건</p>
        <h1>관제할 운송이 아직 없습니다</h1>
        <p>신규 배차가 등록되면 이 화면에 온도 상태와 도착 예정 시간이 표시됩니다.</p>
        <button className="button secondary" type="button">10초 후 다시 확인</button>
      </main>
    )
  }

  return (
    <main className="state-screen" data-testid="error-state">
      <div className="state-icon error"><RadioTower size={32} /></div>
      <p className="eyebrow danger-copy">연결 오류 · E-204</p>
      <h1>센서 게이트웨이에 연결할 수 없습니다</h1>
      <p>마지막 정상 데이터는 2분 전입니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.</p>
      <button className="button primary" type="button">연결 다시 시도</button>
    </main>
  )
}

export function App() {
  const fixture = useMemo(() => createExperimentData(), [])
  const [shipments, setShipments] = useState(fixture.shipments)
  const [drivers, setDrivers] = useState(fixture.drivers)
  const [alerts, setAlerts] = useState(fixture.alerts)
  const [draftFilters, setDraftFilters] = useState<Filters>(emptyFilters)
  const [appliedFilters, setAppliedFilters] = useState<Filters>(emptyFilters)
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [sortDirection, setSortDirection] = useState<'none' | 'asc' | 'desc'>('none')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [bulkOpen, setBulkOpen] = useState(false)
  const [notificationsOpen, setNotificationsOpen] = useState(false)
  const [detailId, setDetailId] = useState<string | null>(null)
  const [editing, setEditing] = useState(false)
  const [dispatchForm, setDispatchForm] = useState<DispatchForm | null>(null)
  const [driverMenuOpen, setDriverMenuOpen] = useState(false)
  const [driverSearch, setDriverSearch] = useState('')
  const [validationError, setValidationError] = useState('')
  const [saveSuccess, setSaveSuccess] = useState(false)
  const notificationTriggerRef = useRef<HTMLButtonElement>(null)
  const notificationCloseRef = useRef<HTMLButtonElement>(null)

  const demo = new URLSearchParams(window.location.search).get('demo') ?? 'default'
  const hubMap = useMemo(() => new Map(fixture.hubs.map((hub) => [hub.id, hub])), [fixture.hubs])
  const driverMap = useMemo(() => new Map(drivers.map((driver) => [driver.id, driver])), [drivers])
  const vehicleMap = useMemo(() => new Map(fixture.vehicles.map((vehicle) => [vehicle.id, vehicle])), [fixture.vehicles])

  const filteredShipments = useMemo(() => {
    const items = shipments.filter((shipment) => {
      const statusMatch = !appliedFilters.status || shipment.status === appliedFilters.status
      const hubMatch = !appliedFilters.hub
        || shipment.originHubId === appliedFilters.hub
        || shipment.destinationHubId === appliedFilters.hub
      const dateMatch = !appliedFilters.date || shipment.eta.slice(0, 10) === appliedFilters.date
      const temperatureMatch = !appliedFilters.temperature || shipment.temperatureState === appliedFilters.temperature
      const driverMatch = !appliedFilters.driver || shipment.driverId === appliedFilters.driver
      return statusMatch && hubMatch && dateMatch && temperatureMatch && driverMatch
    })
    if (sortDirection === 'none') return items
    return [...items].sort((a, b) => {
      const aTemp = a.currentTemperature ?? Number.POSITIVE_INFINITY
      const bTemp = b.currentTemperature ?? Number.POSITIVE_INFINITY
      return sortDirection === 'asc' ? aTemp - bTemp : bTemp - aTemp
    })
  }, [shipments, appliedFilters, sortDirection])

  const detailShipment = shipments.find((shipment) => shipment.id === detailId) ?? null
  const activeFilterCount = Object.values(appliedFilters).filter(Boolean).length
  const unreadCount = alerts.filter((alert) => !alert.read).length
  const anomalyCount = shipments.filter((shipment) => shipment.status === 'temperature-excursion').length
  const delayedCount = shipments.filter((shipment) => shipment.status === 'delayed').length
  const offlineCount = shipments.filter((shipment) => shipment.status === 'sensor-offline').length
  const resolvedCount = shipments.filter((shipment) => shipment.status === 'resolved').length
  const allVisibleSelected = filteredShipments.length > 0 && filteredShipments.every((shipment) => selected.has(shipment.id))

  const filteredDrivers = drivers.filter((driver) =>
    `${driver.name} ${driver.id} ${driver.phone}`.toLowerCase().includes(driverSearch.trim().toLowerCase()),
  )

  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return
      if (driverMenuOpen) setDriverMenuOpen(false)
      else if (notificationsOpen) {
        setNotificationsOpen(false)
        notificationTriggerRef.current?.focus()
      } else if (detailId) {
        setDetailId(null)
        setEditing(false)
      }
    }
    window.addEventListener('keydown', closeOnEscape)
    return () => window.removeEventListener('keydown', closeOnEscape)
  }, [driverMenuOpen, notificationsOpen, detailId])

  useEffect(() => {
    if (notificationsOpen) notificationCloseRef.current?.focus()
  }, [notificationsOpen])

  function applyFilters() {
    setAppliedFilters({ ...draftFilters })
    setSelected(new Set())
    setFiltersOpen(false)
  }

  function toggleAllVisible() {
    setSelected((previous) => {
      const next = new Set(previous)
      if (allVisibleSelected) filteredShipments.forEach((shipment) => next.delete(shipment.id))
      else filteredShipments.forEach((shipment) => next.add(shipment.id))
      return next
    })
  }

  function toggleSelected(id: string) {
    setSelected((previous) => {
      const next = new Set(previous)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  function resolveSelected() {
    setShipments((previous) => previous.map((shipment) =>
      selected.has(shipment.id) ? { ...shipment, status: 'resolved' as const } : shipment,
    ))
    setSelected(new Set())
    setBulkOpen(false)
  }

  function openDetail(id: string) {
    setDetailId(id)
    setNotificationsOpen(false)
    setEditing(false)
    setSaveSuccess(false)
    setValidationError('')
  }

  function beginEdit() {
    if (!detailShipment) return
    setDispatchForm(shipmentToForm(detailShipment, drivers))
    setEditing(true)
    setSaveSuccess(false)
    setValidationError('')
    setDriverMenuOpen(false)
  }

  function cancelEdit() {
    setEditing(false)
    setDriverMenuOpen(false)
    setValidationError('')
  }

  function selectDriver(driver: Driver) {
    setDispatchForm((previous) => previous ? {
      ...previous,
      driverId: driver.id,
      driverName: driver.name,
      phone: driver.phone,
    } : previous)
    setDriverMenuOpen(false)
    setDriverSearch('')
  }

  function saveDispatch(event: FormEvent) {
    event.preventDefault()
    if (!detailShipment || !dispatchForm) return
    const minimum = Number(dispatchForm.minTemperature)
    const maximum = Number(dispatchForm.maxTemperature)
    if (!dispatchForm.driverName.trim() || !dispatchForm.phone.trim() || !dispatchForm.trackingCode.trim()) {
      setValidationError('기사 이름, 연락처, 운송장 코드는 필수입니다.')
      return
    }
    if (!Number.isFinite(minimum) || !Number.isFinite(maximum) || minimum >= maximum) {
      setValidationError('최저 온도는 최고 온도보다 낮아야 합니다.')
      return
    }
    setShipments((previous) => previous.map((shipment) => shipment.id === detailShipment.id ? {
      ...shipment,
      trackingCode: dispatchForm.trackingCode.trim(),
      driverId: dispatchForm.driverId,
      vehicleId: dispatchForm.vehicleId,
      originHubId: dispatchForm.originHubId,
      destinationHubId: dispatchForm.destinationHubId,
      originAddress: hubMap.get(dispatchForm.originHubId)?.address ?? shipment.originAddress,
      destinationAddress: hubMap.get(dispatchForm.destinationHubId)?.address ?? shipment.destinationAddress,
      status: dispatchForm.status,
      minTemperature: minimum,
      maxTemperature: maximum,
      notes: dispatchForm.notes,
    } : shipment))
    setDrivers((previous) => previous.map((driver) => driver.id === dispatchForm.driverId ? {
      ...driver,
      name: dispatchForm.driverName.trim(),
      phone: dispatchForm.phone.trim(),
    } : driver))
    setEditing(false)
    setDriverMenuOpen(false)
    setValidationError('')
    setSaveSuccess(true)
  }

  function toggleAlertRead(id: string) {
    setAlerts((previous) => previous.map((alert) => alert.id === id ? { ...alert, read: !alert.read } : alert))
  }

  function advanceResolution(id: string) {
    const next: Record<AlertResolution, AlertResolution> = {
      open: 'acknowledged',
      acknowledged: 'resolved',
      resolved: 'open',
    }
    setAlerts((previous) => previous.map((alert) => alert.id === id
      ? { ...alert, resolution: next[alert.resolution] }
      : alert,
    ))
  }

  function cycleTemperatureSort() {
    setSortDirection((current) => current === 'none' ? 'desc' : current === 'desc' ? 'asc' : 'none')
  }

  if (demo === 'loading' || demo === 'empty' || demo === 'error') {
    return (
      <div className="app-shell state-shell" data-testid="app-root">
        <BrandRail compact />
        <StateScreen kind={demo} />
      </div>
    )
  }

  return (
    <div className="app-shell" data-testid="app-root">
      <BrandRail />

      <div className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">2026. 08. 13 · 주간조 A</p>
            <h1>콜드체인 관제</h1>
          </div>
          <div className="top-actions">
            <div className="live-mark"><i />실시간 연결</div>
            <button
              className="icon-button notification-button"
              type="button"
              aria-label={`알림 ${unreadCount}개`}
              data-testid="notifications-trigger"
              ref={notificationTriggerRef}
              onClick={() => {
                setNotificationsOpen(true)
                setDetailId(null)
              }}
            >
              <Bell size={20} />
              <span>{unreadCount}</span>
            </button>
            <div className="operator">
              <span>관</span>
              <div><strong>관제자 01</strong><small>서울 통합센터</small></div>
              <ChevronDown size={16} />
            </div>
          </div>
        </header>

        <main className="dashboard-content">
          <section className="overview-grid" aria-label="운영 현황">
            <div className="kpi-cluster">
              <KpiCard label="진행 운송" value={shipments.length - resolvedCount} detail={`전체 ${shipments.length}건`} icon={<Truck />} tone="cool" />
              <KpiCard label="온도 이탈" value={anomalyCount} detail="즉시 확인 필요" icon={<Thermometer />} tone="critical" />
              <KpiCard label="배송 지연" value={delayedCount} detail="ETA 초과 예상" icon={<Clock3 />} tone="warning" />
              <KpiCard label="센서 단절" value={offlineCount} detail="게이트웨이 점검" icon={<RadioTower />} tone="muted" />
            </div>
            <AnomalyChart series={fixture.anomalySeries} />
          </section>

          <section className="shipments-panel">
            <div className="panel-heading">
              <div>
                <div className="heading-line"><span className="section-index">02</span><h2>운송 흐름</h2></div>
                <p>온도와 도착 위험도를 기준으로 빠르게 좁혀 조치하세요.</p>
              </div>
              <div className="panel-actions">
                <div className="bulk-wrap">
                  <button
                    className="button secondary"
                    type="button"
                    data-testid="bulk-action-trigger"
                    aria-expanded={bulkOpen}
                    disabled={selected.size === 0}
                    onClick={() => setBulkOpen((open) => !open)}
                  >
                    <CheckCircle2 size={16} /> 선택 조치 <b>{selected.size}</b><ChevronDown size={14} />
                  </button>
                  {bulkOpen && (
                    <div className="action-menu">
                      <button type="button" data-testid="bulk-resolve" onClick={resolveSelected}>
                        <Check size={16} /> 조치 완료로 변경
                      </button>
                    </div>
                  )}
                </div>
                <button
                  className={`button filter-button ${filtersOpen || activeFilterCount ? 'active' : ''}`}
                  type="button"
                  data-testid="filter-trigger"
                  aria-expanded={filtersOpen}
                  onClick={() => setFiltersOpen((open) => !open)}
                >
                  <Filter size={16} /> 필터 {activeFilterCount > 0 && <b>{activeFilterCount}</b>}
                </button>
              </div>
            </div>

            {filtersOpen && (
              <div className="filters" data-testid="filters-surface">
                <label>
                  <span>운송 상태</span>
                  <select
                    data-testid="filter-status"
                    value={draftFilters.status}
                    onChange={(event) => setDraftFilters({ ...draftFilters, status: event.target.value as Filters['status'] })}
                  >
                    <option value="">전체 상태</option>
                    {Object.entries(statusLabels).map(([value, label]) => (
                      <option
                        key={value}
                        value={value}
                        data-testid={value === 'temperature-excursion' ? 'filter-status-option-temperature-excursion' : undefined}
                      >{label}</option>
                    ))}
                  </select>
                </label>
                <label>
                  <span>경유 거점</span>
                  <select
                    data-testid="filter-hub"
                    value={draftFilters.hub}
                    onChange={(event) => setDraftFilters({ ...draftFilters, hub: event.target.value })}
                  >
                    <option value="">전체 거점</option>
                    {fixture.hubs.map((hub) => (
                      <option key={hub.id} value={hub.id} data-testid={hub.id === 'HUB-12' ? 'filter-hub-option-HUB-12' : undefined}>
                        {hub.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  <span>도착 예정일</span>
                  <input
                    type="date"
                    data-testid="filter-date"
                    value={draftFilters.date}
                    onChange={(event) => setDraftFilters({ ...draftFilters, date: event.target.value })}
                  />
                </label>
                <label>
                  <span>온도 판정</span>
                  <select
                    data-testid="filter-temperature"
                    value={draftFilters.temperature}
                    onChange={(event) => setDraftFilters({ ...draftFilters, temperature: event.target.value as Filters['temperature'] })}
                  >
                    <option value="">전체 판정</option>
                    {Object.entries(temperatureLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                  </select>
                </label>
                <label>
                  <span>담당 기사</span>
                  <select
                    data-testid="filter-driver"
                    value={draftFilters.driver}
                    onChange={(event) => setDraftFilters({ ...draftFilters, driver: event.target.value })}
                  >
                    <option value="">전체 기사</option>
                    {drivers.map((driver) => <option key={driver.id} value={driver.id}>{driver.name} · {driver.id}</option>)}
                  </select>
                </label>
                <div className="filter-actions">
                  <button className="text-button" type="button" onClick={() => setDraftFilters(emptyFilters)}>초기화</button>
                  <button className="button primary" type="button" data-testid="filter-apply" onClick={applyFilters}>조건 적용</button>
                </div>
              </div>
            )}

            <div className="results-bar">
              <p data-testid="results-count"><strong>{filteredShipments.length}</strong>건 표시</p>
              <div className="legend"><i className="legend-normal" />정상 <i className="legend-warning" />주의 <i className="legend-critical" />위험 <i className="legend-unavailable" />측정 불가</div>
            </div>

            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th className="select-cell">
                      <input
                        type="checkbox"
                        aria-label="현재 표시된 운송 전체 선택"
                        data-testid="select-all-visible"
                        checked={allVisibleSelected}
                        onChange={toggleAllVisible}
                      />
                    </th>
                    <th>상태</th>
                    <th>운송장 / 화물</th>
                    <th>운송 경로</th>
                    <th>기사 / 차량</th>
                    <th className="number-cell">
                      <button type="button" className="sort-button" data-testid="sort-temperature" onClick={cycleTemperatureSort}>
                        현재 온도 <span>{sortDirection === 'desc' ? '↓' : sortDirection === 'asc' ? '↑' : '↕'}</span>
                      </button>
                    </th>
                    <th className="number-cell">허용 범위</th>
                    <th>도착 예정</th>
                    <th>알림</th>
                    <th aria-label="상세 열" />
                  </tr>
                </thead>
                <tbody>
                  {filteredShipments.map((shipment) => {
                    const driver = driverMap.get(shipment.driverId)
                    const vehicle = vehicleMap.get(shipment.vehicleId)
                    const origin = hubMap.get(shipment.originHubId)
                    const destination = hubMap.get(shipment.destinationHubId)
                    return (
                      <tr key={shipment.id} className={selected.has(shipment.id) ? 'selected-row' : ''}>
                        <td className="select-cell">
                          <input
                            type="checkbox"
                            aria-label={`${shipment.id} 선택`}
                            data-testid={shipment.id === 'SHP-001' ? 'row-select-SHP-001' : undefined}
                            checked={selected.has(shipment.id)}
                            onChange={() => toggleSelected(shipment.id)}
                          />
                        </td>
                        <td>
                          <StatusBadge shipment={shipment} testHook />
                          <span className={`temperature-rail ${shipment.temperatureState}`} aria-hidden="true" />
                        </td>
                        <td className="identity-cell">
                          <strong>{shipment.trackingCode}</strong>
                          <span title={shipment.cargoName}>{shipment.cargoName}</span>
                        </td>
                        <td className="route-cell">
                          <strong>{origin?.city}<ChevronRight size={13} />{destination?.city}</strong>
                          <span>{origin?.name}</span>
                        </td>
                        <td className="identity-cell">
                          <strong>{driver?.name ?? '미배정'} <small>{shipment.driverId}</small></strong>
                          <span>{vehicle?.plate ?? '차량 없음'} · {shipment.vehicleId}</span>
                        </td>
                        <td className={`number-cell temperature-value ${shipment.temperatureState}`}>
                          {shipment.currentTemperature === null ? <><RadioTower size={14} /> —</> : `${shipment.currentTemperature.toFixed(1)}°C`}
                        </td>
                        <td className="number-cell range-cell">{shipment.minTemperature}–{shipment.maxTemperature}°</td>
                        <td className="eta-cell"><strong>{timeLabel(shipment.eta)}</strong><span>D-day</span></td>
                        <td>{shipment.alertCount > 0 ? <span className="alert-count"><AlertTriangle size={13} />{shipment.alertCount}</span> : <span className="no-alert">—</span>}</td>
                        <td>
                          <button
                            className="row-open"
                            type="button"
                            aria-label={`${shipment.id} 상세 열기`}
                            data-testid={shipment.id === 'SHP-001' ? 'shipment-open-SHP-001' : undefined}
                            onClick={() => openDetail(shipment.id)}
                          ><ChevronRight size={17} /></button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
              {filteredShipments.length === 0 && (
                <div className="inline-empty"><Search size={24} /><strong>조건에 맞는 운송이 없습니다</strong><span>필터를 줄이거나 초기화해 보세요.</span></div>
              )}
            </div>
          </section>
        </main>
      </div>

      {notificationsOpen && (
        <NotificationsPanel
          alerts={alerts}
          shipments={shipments}
          onClose={() => {
            setNotificationsOpen(false)
            notificationTriggerRef.current?.focus()
          }}
          closeRef={notificationCloseRef}
          onToggleRead={toggleAlertRead}
          onAdvanceResolution={advanceResolution}
          onOpenShipment={openDetail}
        />
      )}

      {detailShipment && (
        <DetailPanel
          shipment={detailShipment}
          events={fixture.eventsByShipment[detailShipment.id]}
          driver={driverMap.get(detailShipment.driverId)}
          vehicleLabel={`${vehicleMap.get(detailShipment.vehicleId)?.plate ?? '차량 없음'} · ${vehicleMap.get(detailShipment.vehicleId)?.model ?? ''}`}
          originLabel={hubMap.get(detailShipment.originHubId)?.name ?? detailShipment.originHubId}
          destinationLabel={hubMap.get(detailShipment.destinationHubId)?.name ?? detailShipment.destinationHubId}
          editing={editing}
          dispatchForm={dispatchForm}
          onFormChange={setDispatchForm}
          driverMenuOpen={driverMenuOpen}
          onDriverMenuToggle={() => setDriverMenuOpen((open) => !open)}
          driverSearch={driverSearch}
          onDriverSearch={setDriverSearch}
          filteredDrivers={filteredDrivers}
          onSelectDriver={selectDriver}
          vehicles={fixture.vehicles}
          hubs={fixture.hubs}
          onBeginEdit={beginEdit}
          onCancel={cancelEdit}
          onSave={saveDispatch}
          onClose={() => {
            setDetailId(null)
            setEditing(false)
            setDriverMenuOpen(false)
          }}
          validationError={validationError}
          saveSuccess={saveSuccess}
        />
      )}
    </div>
  )
}

function BrandRail({ compact = false }: { compact?: boolean }) {
  return (
    <aside className={`brand-rail ${compact ? 'compact' : ''}`}>
      <div className="brand-mark" aria-label="저온선"><Snowflake size={22} /></div>
      {!compact && (
        <>
          <nav aria-label="주 메뉴">
            <button className="nav-item active" type="button" aria-label="관제 현황"><Gauge size={20} /><span>관제</span></button>
            <button className="nav-item" type="button" aria-label="운송"><Truck size={20} /><span>운송</span></button>
            <button className="nav-item" type="button" aria-label="거점"><MapPin size={20} /><span>거점</span></button>
            <button className="nav-item" type="button" aria-label="기사"><UserRound size={20} /><span>기사</span></button>
          </nav>
          <div className="rail-temp"><Thermometer size={16} /><span>-18.2°</span><small>시스템</small></div>
        </>
      )}
    </aside>
  )
}

function KpiCard({ label, value, detail, icon, tone }: { label: string; value: number; detail: string; icon: React.ReactNode; tone: string }) {
  return (
    <article className={`kpi-card ${tone}`}>
      <div className="kpi-top"><span className="kpi-icon">{icon}</span><small>{label}</small></div>
      <div className="kpi-value"><strong>{value}</strong><span>건</span></div>
      <p>{detail}</p>
    </article>
  )
}

function AnomalyChart({ series }: { series: ReturnType<typeof createExperimentData>['anomalySeries'] }) {
  const width = 670
  const height = 150
  const warning = series.map((point) => point.warning)
  const critical = series.map((point) => point.critical)
  return (
    <article className="trend-card">
      <div className="trend-heading">
        <div><span className="section-index">01</span><div><h2>시간대별 온도 이상</h2><p>최근 24시간 · 센서 판정 건수</p></div></div>
        <div className="trend-legend"><span><i className="warning-dot" />주의</span><span><i className="critical-dot" />위험</span></div>
      </div>
      <div className="chart-frame">
        <div className="chart-y"><span>12</span><span>6</span><span>0</span></div>
        <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label="시간대별 온도 이상 추이">
          <defs>
            <linearGradient id="warningArea" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#e5a228" stopOpacity=".2" />
              <stop offset="1" stopColor="#e5a228" stopOpacity="0" />
            </linearGradient>
          </defs>
          <line x1="8" y1="22" x2="662" y2="22" className="grid-line" />
          <line x1="8" y1="76" x2="662" y2="76" className="grid-line" />
          <line x1="8" y1="140" x2="662" y2="140" className="grid-line" />
          <path d={`${makeLine(warning, width, height, 12)} L 662 140 L 8 140 Z`} fill="url(#warningArea)" />
          <path d={makeLine(warning, width, height, 12)} className="warning-line" />
          <path d={makeLine(critical, width, height, 12)} className="critical-line" />
          {critical.map((value, index) => index % 4 === 0 && (
            <circle key={index} cx={8 + (index / 23) * (width - 16)} cy={height - 10 - (value / 12) * (height - 24)} r="3" className="critical-point" />
          ))}
        </svg>
        <div className="chart-x"><span>00시</span><span>06시</span><span>12시</span><span>18시</span><span>23시</span></div>
      </div>
    </article>
  )
}

function StatusBadge({ shipment, testHook = false }: { shipment: Shipment; testHook?: boolean }) {
  return (
    <span
      className={`status-badge ${shipment.status}`}
      data-testid={testHook && shipment.id === 'SHP-001' ? 'shipment-status-SHP-001' : undefined}
    >
      <i />{statusLabels[shipment.status]}
    </span>
  )
}

function NotificationsPanel({
  alerts,
  shipments,
  onClose,
  closeRef,
  onToggleRead,
  onAdvanceResolution,
  onOpenShipment,
}: {
  alerts: Alert[]
  shipments: Shipment[]
  onClose: () => void
  closeRef: React.RefObject<HTMLButtonElement | null>
  onToggleRead: (id: string) => void
  onAdvanceResolution: (id: string) => void
  onOpenShipment: (id: string) => void
}) {
  const unread = alerts.filter((alert) => !alert.read).length
  return (
    <div className="panel-layer" role="presentation">
      <button className="panel-backdrop" type="button" aria-label="알림 닫기" onClick={onClose} />
      <aside className="side-panel notifications-panel" data-testid="notifications-surface" role="dialog" aria-modal="true" aria-labelledby="notifications-title">
        <header className="side-panel-header">
          <div><p className="eyebrow">ALERT CENTER</p><h2 id="notifications-title">알림 <span>{alerts.length}</span></h2></div>
          <button className="icon-button" type="button" aria-label="알림 패널 닫기" onClick={onClose} ref={closeRef}><X size={20} /></button>
        </header>
        <div className="notification-summary"><strong>{unread}건</strong><span>읽지 않음</span><i /><strong>{alerts.filter((alert) => alert.resolution === 'open').length}건</strong><span>조치 대기</span></div>
        <div className="notification-list">
          {[...alerts].reverse().map((alert) => {
            const shipment = shipments.find((item) => item.id === alert.shipmentId)
            return (
              <article
                key={alert.id}
                className={`notification-item ${alert.read ? 'read' : 'unread'} ${alert.severity}`}
                data-testid={alert.id === 'ALT-030' ? 'notification-ALT-030' : undefined}
              >
                <div className="notification-item-top">
                  <div className="alert-kind"><span className={`severity-mark ${alert.severity}`}><AlertTriangle size={14} /></span><strong>{alert.title}</strong></div>
                  <time>{timeLabel(alert.createdAt)}</time>
                </div>
                <p>{alert.message}</p>
                <button className="shipment-link" type="button" onClick={() => onOpenShipment(alert.shipmentId)}>
                  {alert.shipmentId} · {shipment?.cargoName}<ChevronRight size={13} />
                </button>
                <div className="notification-actions">
                  <button
                    type="button"
                    data-testid={alert.id === 'ALT-030' ? 'notification-toggle-read-ALT-030' : undefined}
                    onClick={() => onToggleRead(alert.id)}
                  >{alert.read ? '읽지 않음으로' : '읽음 처리'}</button>
                  <span
                    className={`state-pill ${alert.read ? 'read' : 'unread'}`}
                    data-state={alert.read ? 'read' : 'unread'}
                    data-testid={alert.id === 'ALT-030' ? 'notification-state-ALT-030' : undefined}
                  >{alert.read ? '읽음' : '새 알림'}</span>
                  <button
                    type="button"
                    data-testid={alert.id === 'ALT-030' ? 'notification-toggle-resolution-ALT-030' : undefined}
                    onClick={() => onAdvanceResolution(alert.id)}
                  >다음 조치 상태</button>
                  <span
                    className={`state-pill resolution ${alert.resolution}`}
                    data-state={alert.resolution}
                    data-testid={alert.id === 'ALT-030' ? 'notification-resolution-ALT-030' : undefined}
                  >{resolutionLabels[alert.resolution]}</span>
                </div>
              </article>
            )
          })}
        </div>
      </aside>
    </div>
  )
}

function DetailPanel({
  shipment,
  events,
  driver,
  vehicleLabel,
  originLabel,
  destinationLabel,
  editing,
  dispatchForm,
  onFormChange,
  driverMenuOpen,
  onDriverMenuToggle,
  driverSearch,
  onDriverSearch,
  filteredDrivers,
  onSelectDriver,
  vehicles,
  hubs,
  onBeginEdit,
  onCancel,
  onSave,
  onClose,
  validationError,
  saveSuccess,
}: {
  shipment: Shipment
  events: TimelineEvent[]
  driver: Driver | undefined
  vehicleLabel: string
  originLabel: string
  destinationLabel: string
  editing: boolean
  dispatchForm: DispatchForm | null
  onFormChange: (value: DispatchForm) => void
  driverMenuOpen: boolean
  onDriverMenuToggle: () => void
  driverSearch: string
  onDriverSearch: (value: string) => void
  filteredDrivers: Driver[]
  onSelectDriver: (driver: Driver) => void
  vehicles: ReturnType<typeof createExperimentData>['vehicles']
  hubs: ReturnType<typeof createExperimentData>['hubs']
  onBeginEdit: () => void
  onCancel: () => void
  onSave: (event: FormEvent) => void
  onClose: () => void
  validationError: string
  saveSuccess: boolean
}) {
  const temperatureEvents = events.filter((event) => event.temperature !== null)
  const temperatureValues = temperatureEvents.map((event) => event.temperature as number)
  const min = shipment.minTemperature - 2
  const max = shipment.maxTemperature + 3
  const normalized = temperatureValues.map((value) => ((value - min) / Math.max(max - min, 1)) * 10)
  return (
    <div className="panel-layer" role="presentation">
      <button className="panel-backdrop" type="button" aria-label="운송 상세 닫기" onClick={onClose} />
      <aside className="side-panel detail-panel" data-testid="shipment-detail" role="dialog" aria-modal="true" aria-labelledby="detail-title">
        <header className="side-panel-header detail-header">
          <div>
            <p className="eyebrow">SHIPMENT RECORD · {shipment.id}</p>
            <h2 id="detail-title">{shipment.cargoName}</h2>
            <span className="tracking-label">{shipment.trackingCode}</span>
          </div>
          <button className="icon-button" type="button" aria-label="운송 상세 닫기" onClick={onClose}><X size={20} /></button>
        </header>

        {!editing ? (
          <div className="detail-scroll">
            <div className="detail-command-bar">
              <StatusBadge shipment={shipment} />
              <button className="button primary" type="button" data-testid="edit-dispatch" onClick={onBeginEdit}><PencilLine size={15} />배차 정보 수정</button>
            </div>
            {saveSuccess && <div className="success-message" data-testid="save-success"><CheckCircle2 size={17} />변경 사항이 저장되었습니다.</div>}

            <section className="temperature-focus">
              <div className="temperature-reading">
                <span>현재 온도</span>
                <strong>{shipment.currentTemperature === null ? '—' : shipment.currentTemperature.toFixed(1)}<small>°C</small></strong>
                <p>허용 범위 {shipment.minTemperature}° – {shipment.maxTemperature}°</p>
              </div>
              <div className={`thermal-gauge ${shipment.temperatureState}`}><i /><span>{temperatureLabels[shipment.temperatureState]}</span></div>
            </section>

            <section className="detail-section">
              <div className="detail-section-title"><div><span className="section-index">A</span><h3>배차 및 경로</h3></div><small>현재 정보</small></div>
              <div className="route-visual">
                <div><span className="route-node origin"><MapPin size={15} /></span><p><small>출발</small><strong>{originLabel}</strong><span>{shipment.originAddress}</span></p></div>
                <i />
                <div><span className="route-node destination"><MapPin size={15} /></span><p><small>도착</small><strong>{destinationLabel}</strong><span>{shipment.destinationAddress}</span></p></div>
              </div>
              <div className="detail-info-grid">
                <InfoItem icon={<UserRound />} label="담당 기사" value={`${driver?.name ?? '미배정'} · ${driver?.phone ?? ''}`} />
                <InfoItem icon={<Truck />} label="배정 차량" value={vehicleLabel} />
                <InfoItem icon={<Clock3 />} label="도착 예정" value={timeLabel(shipment.eta)} />
                <InfoItem icon={<AlertTriangle />} label="연결 알림" value={`${shipment.alertCount}건`} />
              </div>
              {shipment.notes && <div className="notes-card"><strong>운송 메모</strong><p>{shipment.notes}</p></div>}
            </section>

            <section className="detail-section">
              <div className="detail-section-title"><div><span className="section-index">B</span><h3>온도 추이</h3></div><small>센서 측정값</small></div>
              <div className="detail-chart">
                <div className="allowed-band" />
                <svg viewBox="0 0 470 150" role="img" aria-label={`${shipment.id} 온도 추이`}>
                  <line x1="8" y1="36" x2="462" y2="36" className="grid-line" />
                  <line x1="8" y1="78" x2="462" y2="78" className="grid-line" />
                  <line x1="8" y1="126" x2="462" y2="126" className="grid-line" />
                  <path d={makeLine(normalized.length ? normalized : [0, 0], 470, 150, 10)} className="detail-temp-line" />
                  {normalized.map((value, index) => <circle key={index} cx={8 + (index / Math.max(normalized.length - 1, 1)) * 454} cy={140 - (value / 10) * 126} r="3" className="detail-temp-point" />)}
                </svg>
                <div className="detail-chart-labels"><span>초기</span><span>현재</span></div>
              </div>
            </section>

            <section className="detail-section timeline-section">
              <div className="detail-section-title"><div><span className="section-index">C</span><h3>센서 이벤트 및 조치 이력</h3></div><small>{events.length}개 기록</small></div>
              <div className="timeline">
                {[...events].reverse().map((event) => (
                  <article key={event.id} className={`timeline-item ${event.kind}`}>
                    <span className="timeline-icon">{event.kind === 'temperature' ? <Thermometer /> : event.kind === 'location' ? <MapPin /> : event.kind === 'sensor' ? <RadioTower /> : <CheckCircle2 />}</span>
                    <div>
                      <div><strong>{event.title}</strong><time>{timeLabel(event.occurredAt)}</time></div>
                      <p>{event.detail}</p>
                      {event.temperature !== null && <b>{event.temperature.toFixed(1)}°C</b>}
                    </div>
                  </article>
                ))}
              </div>
            </section>
          </div>
        ) : dispatchForm && (
          <form className="edit-form" onSubmit={onSave} noValidate>
            <div className="edit-intro"><span className="section-index">EDIT</span><div><h3>배차 정보 수정</h3><p>저장 전 배차와 허용 온도 범위를 다시 확인하세요.</p></div></div>
            {validationError && <div className="validation-message" data-testid="validation-error"><AlertTriangle size={17} />{validationError}</div>}

            <fieldset>
              <legend>기사 정보</legend>
              <label className="form-field full-field">
                <span>배정 기사 <em>96명 중 선택</em></span>
                <div className="driver-selector">
                  <button className="select-button" type="button" data-testid="driver-control" aria-expanded={driverMenuOpen} onClick={onDriverMenuToggle}>
                    <span><strong>{dispatchForm.driverName}</strong><small data-testid="dispatch-driver">{dispatchForm.driverId} · {dispatchForm.phone}</small></span><ChevronDown size={17} />
                  </button>
                  {driverMenuOpen && (
                    <div className="driver-options" data-testid="driver-options">
                      <div className="driver-search"><Search size={15} /><input aria-label="기사 검색" placeholder="이름, ID, 연락처 검색" value={driverSearch} onChange={(event) => onDriverSearch(event.target.value)} autoFocus /></div>
                      <div className="driver-options-scroll">
                        {filteredDrivers.map((item) => (
                          <button
                            type="button"
                            key={item.id}
                            className={item.id === dispatchForm.driverId ? 'selected' : ''}
                            data-testid={item.id === 'DRV-096' ? 'driver-option-DRV-096' : undefined}
                            onClick={() => onSelectDriver(item)}
                          >
                            <span><strong>{item.name}</strong><small>{item.id} · {item.phone}</small></span><em>{item.active ? '운행 가능' : '휴무'}</em>
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </label>
              <label className="form-field"><span>기사 이름</span><input data-testid="dispatch-driver-name" value={dispatchForm.driverName} onChange={(event) => onFormChange({ ...dispatchForm, driverName: event.target.value })} /></label>
              <label className="form-field"><span>연락처</span><input data-testid="dispatch-phone" value={dispatchForm.phone} onChange={(event) => onFormChange({ ...dispatchForm, phone: event.target.value })} /></label>
            </fieldset>

            <fieldset>
              <legend>운송 및 차량</legend>
              <label className="form-field full-field"><span>운송장 코드</span><input data-testid="dispatch-tracking" value={dispatchForm.trackingCode} onChange={(event) => onFormChange({ ...dispatchForm, trackingCode: event.target.value })} /></label>
              <label className="form-field"><span>배정 차량</span><select value={dispatchForm.vehicleId} onChange={(event) => onFormChange({ ...dispatchForm, vehicleId: event.target.value })}>{vehicles.map((item) => <option key={item.id} value={item.id}>{item.plate} · {item.model}</option>)}</select></label>
              <label className="form-field"><span>운송 상태</span><select value={dispatchForm.status} onChange={(event) => onFormChange({ ...dispatchForm, status: event.target.value as ShipmentStatus })}>{Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
              <label className="form-field"><span>출발 거점</span><select value={dispatchForm.originHubId} onChange={(event) => onFormChange({ ...dispatchForm, originHubId: event.target.value })}>{hubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</select></label>
              <label className="form-field"><span>도착 거점</span><select value={dispatchForm.destinationHubId} onChange={(event) => onFormChange({ ...dispatchForm, destinationHubId: event.target.value })}>{hubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</select></label>
            </fieldset>

            <fieldset>
              <legend>온도 및 메모</legend>
              <label className="form-field"><span>최저 온도 (°C)</span><input type="number" step="0.1" data-testid="dispatch-min-temperature" value={dispatchForm.minTemperature} onChange={(event) => onFormChange({ ...dispatchForm, minTemperature: event.target.value })} /></label>
              <label className="form-field"><span>최고 온도 (°C)</span><input type="number" step="0.1" data-testid="dispatch-max-temperature" value={dispatchForm.maxTemperature} onChange={(event) => onFormChange({ ...dispatchForm, maxTemperature: event.target.value })} /></label>
              <label className="form-field full-field"><span>운송 메모</span><textarea data-testid="dispatch-notes" rows={5} value={dispatchForm.notes} onChange={(event) => onFormChange({ ...dispatchForm, notes: event.target.value })} /></label>
            </fieldset>

            <footer className="form-footer">
              <button className="button secondary" type="button" data-testid="cancel-dispatch" onClick={onCancel}>취소</button>
              <button className="button primary" type="submit" data-testid="save-dispatch"><Check size={16} />변경 사항 저장</button>
            </footer>
          </form>
        )}
      </aside>
    </div>
  )
}

function InfoItem({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return <div className="info-item"><span>{icon}</span><p><small>{label}</small><strong>{value}</strong></p></div>
}
