import { useMemo, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import {
  Activity,
  AlertTriangle,
  Bell,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  CircleGauge,
  Clock3,
  CloudOff,
  Edit3,
  Filter,
  Gauge,
  Inbox,
  LayoutDashboard,
  LoaderCircle,
  MapPin,
  Menu,
  Package,
  RefreshCw,
  Route,
  Search,
  ShieldCheck,
  Snowflake,
  Thermometer,
  Truck,
  Users,
  WifiOff,
  X,
} from 'lucide-react'
import { createExperimentData } from './fixtures'
import type {
  Alert,
  AlertResolution,
  AnomalyPoint,
  Driver,
  Shipment,
  ShipmentStatus,
  TemperatureState,
  TimelineEvent,
} from './types'

const statusLabels: Record<ShipmentStatus, string> = {
  normal: '정상',
  'temperature-excursion': '온도 이탈',
  delayed: '배송 지연',
  'sensor-offline': '센서 단절',
  resolved: '조치 완료',
}

const temperatureLabels: Record<TemperatureState, string> = {
  normal: '정상',
  warning: '주의',
  critical: '위험',
  unavailable: '수신 불가',
}

const resolutionLabels: Record<AlertResolution, string> = {
  open: '미처리',
  acknowledged: '확인함',
  resolved: '처리 완료',
}

interface FilterValues {
  date: string
  status: ShipmentStatus | ''
  hub: string
  temperature: TemperatureState | ''
  driver: string
}

interface DispatchFormValues {
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

const blankFilters: FilterValues = {
  date: '',
  status: '',
  hub: '',
  temperature: '',
  driver: '',
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat('ko-KR', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: 'Asia/Seoul',
  }).format(new Date(value))
}

function getDemoMode(): string {
  return new URLSearchParams(window.location.search).get('demo') ?? 'default'
}

function StatusBadge({ shipment }: { shipment: Shipment }) {
  const icon = shipment.status === 'temperature-excursion'
    ? <Thermometer size={13} />
    : shipment.status === 'delayed'
      ? <Clock3 size={13} />
      : shipment.status === 'sensor-offline'
        ? <WifiOff size={13} />
        : shipment.status === 'resolved'
          ? <CheckCircle2 size={13} />
          : <Check size={13} />

  return (
    <span
      className={`status-badge status-${shipment.status}`}
      data-testid={`shipment-status-${shipment.id}`}
      data-state={shipment.status}
    >
      {icon}
      {statusLabels[shipment.status]}
    </span>
  )
}

function TemperatureValue({ shipment }: { shipment: Shipment }) {
  if (shipment.currentTemperature === null) {
    return <span className="temperature-value unavailable">—</span>
  }
  return (
    <span className={`temperature-value ${shipment.temperatureState}`}>
      {shipment.currentTemperature.toFixed(1)}<small>°C</small>
    </span>
  )
}

function TrendChart({ points }: { points: AnomalyPoint[] }) {
  const width = 720
  const height = 174
  const left = 34
  const right = 12
  const top = 18
  const bottom = 28
  const max = 10
  const xFor = (index: number) => left + (index / (points.length - 1)) * (width - left - right)
  const yFor = (value: number) => top + (1 - value / max) * (height - top - bottom)
  const warning = points.map((point, index) => `${xFor(index)},${yFor(point.warning)}`).join(' ')
  const critical = points.map((point, index) => `${xFor(index)},${yFor(point.critical)}`).join(' ')

  return (
    <div className="trend-chart" aria-label="24시간 온도 이상 추이 차트">
      <div className="chart-legend">
        <span><i className="legend-dot warning-dot" />주의</span>
        <span><i className="legend-dot critical-dot" />위험</span>
      </div>
      <svg viewBox={`0 0 ${width} ${height}`} role="img">
        {[0, 5, 10].map((tick) => (
          <g key={tick}>
            <line x1={left} x2={width - right} y1={yFor(tick)} y2={yFor(tick)} className="grid-line" />
            <text x={left - 10} y={yFor(tick) + 4} textAnchor="end" className="axis-text">{tick}</text>
          </g>
        ))}
        <polyline points={warning} className="trend-line warning-line" />
        <polyline points={critical} className="trend-line critical-line" />
        {points.map((point, index) => index % 4 === 0 && (
          <text key={point.hour} x={xFor(index)} y={height - 8} textAnchor="middle" className="axis-text">
            {point.hour.slice(0, 2)}
          </text>
        ))}
      </svg>
    </div>
  )
}

function KpiCard({ icon, label, value, detail, tone = 'neutral' }: {
  icon: ReactNode
  label: string
  value: number
  detail: string
  tone?: 'neutral' | 'warning' | 'critical' | 'success'
}) {
  return (
    <article className={`kpi-card kpi-${tone}`}>
      <div className="kpi-icon">{icon}</div>
      <div>
        <p>{label}</p>
        <strong>{value}<small>건</small></strong>
        <span>{detail}</span>
      </div>
    </article>
  )
}

function AppState({ testId, icon, title, description, action }: {
  testId: string
  icon: ReactNode
  title: string
  description: string
  action?: ReactNode
}) {
  return (
    <div className="state-shell" data-testid={testId}>
      <div className="state-brand"><Snowflake size={24} /> FROSTLINE</div>
      <div className="state-card">
        <div className="state-icon">{icon}</div>
        <h1>{title}</h1>
        <p>{description}</p>
        {action}
      </div>
    </div>
  )
}

function ShipmentMiniChart({ events, shipment }: { events: TimelineEvent[]; shipment: Shipment }) {
  const values = events.filter((event) => event.temperature !== null).slice(-12)
  if (!values.length) {
    return <div className="chart-unavailable"><WifiOff size={20} /> 최근 온도 데이터가 없습니다.</div>
  }
  const width = 440
  const height = 120
  const allValues = values.map((event) => event.temperature as number)
  const min = Math.min(...allValues, shipment.minTemperature) - 1
  const max = Math.max(...allValues, shipment.maxTemperature) + 1
  const xFor = (index: number) => 16 + index * ((width - 32) / Math.max(values.length - 1, 1))
  const yFor = (value: number) => 12 + (max - value) * ((height - 28) / Math.max(max - min, 1))
  const line = values.map((event, index) => `${xFor(index)},${yFor(event.temperature as number)}`).join(' ')
  return (
    <svg className="mini-chart" viewBox={`0 0 ${width} ${height}`} role="img" aria-label="운송 온도 추이">
      <rect x="16" y={yFor(shipment.maxTemperature)} width={width - 32} height={Math.max(yFor(shipment.minTemperature) - yFor(shipment.maxTemperature), 1)} className="allowed-zone" />
      <line x1="16" x2={width - 16} y1={yFor(shipment.maxTemperature)} y2={yFor(shipment.maxTemperature)} className="limit-line" />
      <line x1="16" x2={width - 16} y1={yFor(shipment.minTemperature)} y2={yFor(shipment.minTemperature)} className="limit-line" />
      <polyline points={line} className="mini-line" />
      {values.map((event, index) => <circle key={event.id} cx={xFor(index)} cy={yFor(event.temperature as number)} r="3" className="mini-point" />)}
    </svg>
  )
}

export default function App() {
  const demo = getDemoMode()
  const initialData = useMemo(() => createExperimentData(), [])
  const [shipments, setShipments] = useState(initialData.shipments)
  const [drivers, setDrivers] = useState(initialData.drivers)
  const [alerts, setAlerts] = useState(initialData.alerts)
  const [draftFilters, setDraftFilters] = useState<FilterValues>(blankFilters)
  const [appliedFilters, setAppliedFilters] = useState<FilterValues>(blankFilters)
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [temperatureSort, setTemperatureSort] = useState<'none' | 'asc' | 'desc'>('none')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [bulkOpen, setBulkOpen] = useState(false)
  const [detailId, setDetailId] = useState<string | null>(null)
  const [notificationsOpen, setNotificationsOpen] = useState(false)
  const [editing, setEditing] = useState(false)
  const [dispatchForm, setDispatchForm] = useState<DispatchFormValues | null>(null)
  const [driverOptionsOpen, setDriverOptionsOpen] = useState(false)
  const [validationError, setValidationError] = useState('')
  const [saveSuccess, setSaveSuccess] = useState(false)

  const hubsById = useMemo(() => new Map(initialData.hubs.map((hub) => [hub.id, hub])), [initialData.hubs])
  const vehiclesById = useMemo(() => new Map(initialData.vehicles.map((vehicle) => [vehicle.id, vehicle])), [initialData.vehicles])
  const driversById = useMemo(() => new Map(drivers.map((driver) => [driver.id, driver])), [drivers])

  const visibleShipments = useMemo(() => {
    const filtered = shipments.filter((shipment) => {
      if (appliedFilters.date && shipment.eta.slice(0, 10) !== appliedFilters.date) return false
      if (appliedFilters.status && shipment.status !== appliedFilters.status) return false
      if (appliedFilters.hub && shipment.originHubId !== appliedFilters.hub && shipment.destinationHubId !== appliedFilters.hub) return false
      if (appliedFilters.temperature && shipment.temperatureState !== appliedFilters.temperature) return false
      if (appliedFilters.driver && shipment.driverId !== appliedFilters.driver) return false
      return true
    })
    if (temperatureSort === 'none') return filtered
    return [...filtered].sort((a, b) => {
      const aTemp = a.currentTemperature ?? Number.POSITIVE_INFINITY
      const bTemp = b.currentTemperature ?? Number.POSITIVE_INFINITY
      return temperatureSort === 'asc' ? aTemp - bTemp : bTemp - aTemp
    })
  }, [shipments, appliedFilters, temperatureSort])

  const detailShipment = detailId ? shipments.find((shipment) => shipment.id === detailId) ?? null : null
  const allVisibleSelected = visibleShipments.length > 0 && visibleShipments.every((shipment) => selected.has(shipment.id))
  const activeFilterCount = Object.values(appliedFilters).filter(Boolean).length
  const unreadCount = alerts.filter((alert) => !alert.read).length
  const abnormalCount = shipments.filter((shipment) => shipment.status === 'temperature-excursion' || shipment.status === 'delayed').length
  const criticalCount = shipments.filter((shipment) => shipment.temperatureState === 'critical').length
  const offlineCount = shipments.filter((shipment) => shipment.status === 'sensor-offline').length
  const resolvedCount = shipments.filter((shipment) => shipment.status === 'resolved').length

  if (demo === 'loading') {
    return (
      <div data-testid="app-root">
        <AppState
          testId="loading-state"
          icon={<LoaderCircle className="spin" size={34} />}
          title="관제 데이터를 불러오는 중입니다"
          description="운송 현황과 온도 센서 연결 상태를 확인하고 있습니다."
        />
      </div>
    )
  }

  if (demo === 'empty') {
    return (
      <div data-testid="app-root">
        <AppState
          testId="empty-state"
          icon={<Inbox size={34} />}
          title="표시할 운송이 없습니다"
          description="현재 조건에 해당하는 운송이 없습니다. 필터를 초기화하거나 다른 조건을 선택해 보세요."
          action={<button className="primary-button"><RefreshCw size={16} /> 조건 초기화</button>}
        />
      </div>
    )
  }

  if (demo === 'error') {
    return (
      <div data-testid="app-root">
        <AppState
          testId="error-state"
          icon={<CloudOff size={34} />}
          title="운송 데이터를 연결할 수 없습니다"
          description="관제 서버와의 연결이 지연되고 있습니다. 잠시 후 다시 시도해 주세요."
          action={<button className="primary-button" onClick={() => window.location.reload()}><RefreshCw size={16} /> 다시 시도</button>}
        />
      </div>
    )
  }

  const toggleSelection = (id: string) => {
    setSelected((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const toggleAllVisible = () => {
    setSelected((current) => {
      const next = new Set(current)
      if (allVisibleSelected) visibleShipments.forEach((shipment) => next.delete(shipment.id))
      else visibleShipments.forEach((shipment) => next.add(shipment.id))
      return next
    })
  }

  const resolveSelected = () => {
    setShipments((current) => current.map((shipment) => selected.has(shipment.id)
      ? { ...shipment, status: 'resolved', temperatureState: 'normal', alertCount: 0 }
      : shipment))
    setBulkOpen(false)
  }

  const openDetail = (shipment: Shipment) => {
    setDetailId(shipment.id)
    setEditing(false)
    setDispatchForm(null)
    setValidationError('')
    setSaveSuccess(false)
  }

  const beginEditing = () => {
    if (!detailShipment) return
    const driver = driversById.get(detailShipment.driverId)
    setDispatchForm({
      driverName: driver?.name ?? '',
      phone: driver?.phone ?? '',
      trackingCode: detailShipment.trackingCode,
      driverId: detailShipment.driverId,
      vehicleId: detailShipment.vehicleId,
      originHubId: detailShipment.originHubId,
      destinationHubId: detailShipment.destinationHubId,
      status: detailShipment.status,
      minTemperature: String(detailShipment.minTemperature),
      maxTemperature: String(detailShipment.maxTemperature),
      notes: detailShipment.notes,
    })
    setEditing(true)
    setValidationError('')
    setSaveSuccess(false)
  }

  const selectDriver = (driver: Driver) => {
    setDispatchForm((current) => current ? {
      ...current,
      driverId: driver.id,
      driverName: driver.name,
      phone: driver.phone,
    } : current)
    setDriverOptionsOpen(false)
  }

  const saveDispatch = (event: FormEvent) => {
    event.preventDefault()
    if (!detailShipment || !dispatchForm) return
    const min = Number(dispatchForm.minTemperature)
    const max = Number(dispatchForm.maxTemperature)
    if (!dispatchForm.driverName.trim() || !dispatchForm.trackingCode.trim()) {
      setValidationError('기사명과 운송장 번호를 입력해 주세요.')
      return
    }
    if (!/^010-\d{4}-\d{4}$/.test(dispatchForm.phone)) {
      setValidationError('연락처를 010-0000-0000 형식으로 입력해 주세요.')
      return
    }
    if (!Number.isFinite(min) || !Number.isFinite(max) || min >= max) {
      setValidationError('최저 온도는 최고 온도보다 낮아야 합니다.')
      return
    }

    setShipments((current) => current.map((shipment) => shipment.id === detailShipment.id ? {
      ...shipment,
      trackingCode: dispatchForm.trackingCode.trim(),
      driverId: dispatchForm.driverId,
      vehicleId: dispatchForm.vehicleId,
      originHubId: dispatchForm.originHubId,
      destinationHubId: dispatchForm.destinationHubId,
      originAddress: hubsById.get(dispatchForm.originHubId)?.address ?? shipment.originAddress,
      destinationAddress: hubsById.get(dispatchForm.destinationHubId)?.address ?? shipment.destinationAddress,
      status: dispatchForm.status,
      minTemperature: min,
      maxTemperature: max,
      notes: dispatchForm.notes,
    } : shipment))
    setDrivers((current) => current.map((driver) => driver.id === dispatchForm.driverId ? {
      ...driver,
      name: dispatchForm.driverName.trim(),
      phone: dispatchForm.phone,
    } : driver))
    setValidationError('')
    setEditing(false)
    setSaveSuccess(true)
  }

  const updateAlert = (id: string, update: (alert: Alert) => Alert) => {
    setAlerts((current) => current.map((alert) => alert.id === id ? update(alert) : alert))
  }

  const cycleResolution = (resolution: AlertResolution): AlertResolution => {
    if (resolution === 'open') return 'acknowledged'
    if (resolution === 'acknowledged') return 'resolved'
    return 'open'
  }

  return (
    <div className="app" data-testid="app-root">
      <aside className="sidebar">
        <div className="brand-mark"><Snowflake size={24} /><span>FROSTLINE</span></div>
        <nav className="primary-nav" aria-label="주 메뉴">
          <a className="nav-item active" href="#dashboard"><LayoutDashboard size={19} /><span>관제 대시보드</span></a>
          <a className="nav-item" href="#shipments"><Truck size={19} /><span>운송 관리</span><em>64</em></a>
          <a className="nav-item" href="#alerts"><AlertTriangle size={19} /><span>이상 알림</span><em>{unreadCount}</em></a>
          <a className="nav-item" href="#drivers"><Users size={19} /><span>기사·차량</span></a>
          <a className="nav-item" href="#hubs"><MapPin size={19} /><span>물류 거점</span></a>
        </nav>
        <div className="sidebar-system">
          <div className="system-row"><span className="live-dot" />센서 네트워크</div>
          <strong>96.8% 정상</strong>
          <small>마지막 동기화 14:32</small>
        </div>
      </aside>

      <div className="workspace">
        <header className="topbar">
          <div className="topbar-title">
            <button className="mobile-menu" aria-label="메뉴"><Menu size={20} /></button>
            <div>
              <p>운영 관제</p>
              <h1>콜드체인 통합 관제</h1>
            </div>
          </div>
          <div className="topbar-actions">
            <div className="shift-chip"><span className="live-dot" /> 오후 교대 · 운영 중</div>
            <button
              className={`icon-button notification-trigger ${notificationsOpen ? 'active' : ''}`}
              data-testid="notifications-trigger"
              aria-label={`알림 ${unreadCount}개`}
              onClick={() => setNotificationsOpen((open) => !open)}
            >
              <Bell size={19} />
              {unreadCount > 0 && <span>{unreadCount}</span>}
            </button>
            <div className="operator">
              <div className="avatar">이</div>
              <div><strong>이서현</strong><small>관제 담당자</small></div>
              <ChevronDown size={15} />
            </div>
          </div>
        </header>

        <main className="main-content" id="dashboard">
          <section className="page-heading">
            <div>
              <p className="eyebrow">2026년 8월 13일 · 목요일</p>
              <h2>오후 교대 운영 현황</h2>
              <p>진행 중인 운송과 온도 이상을 한눈에 확인하세요.</p>
            </div>
            <div className="heading-meta">
              <span><Activity size={15} /> 실시간 데이터</span>
              <button className="ghost-button"><RefreshCw size={15} /> 새로고침</button>
            </div>
          </section>

          <section className="overview-grid" aria-label="운영 요약">
            <div className="kpi-grid">
              <KpiCard icon={<Truck size={21} />} label="운송 중" value={shipments.length} detail="전체 배차 운송" />
              <KpiCard icon={<AlertTriangle size={21} />} label="이상 감지" value={abnormalCount} detail={`위험 수준 ${criticalCount}건`} tone="critical" />
              <KpiCard icon={<WifiOff size={21} />} label="센서 단절" value={offlineCount} detail="재연결 확인 필요" tone="warning" />
              <KpiCard icon={<ShieldCheck size={21} />} label="조치 완료" value={resolvedCount} detail="금일 처리 운송" tone="success" />
            </div>
            <article className="chart-card">
              <div className="section-card-header">
                <div><p className="section-kicker">24시간 분석</p><h3>시간대별 온도 이상</h3></div>
                <div className="chart-total"><span>오늘 누적</span><strong>{initialData.anomalySeries.reduce((sum, point) => sum + point.warning + point.critical, 0)}</strong></div>
              </div>
              <TrendChart points={initialData.anomalySeries} />
            </article>
          </section>

          <section className="shipments-card" id="shipments">
            <div className="shipments-toolbar">
              <div>
                <p className="section-kicker">실시간 모니터링</p>
                <div className="title-inline"><h3>운송 현황</h3><span data-testid="results-count">{visibleShipments.length}건</span></div>
              </div>
              <div className="toolbar-actions">
                {selected.size > 0 && <span className="selected-count">{selected.size}건 선택</span>}
                <div className="popover-anchor">
                  <button
                    className="ghost-button"
                    data-testid="bulk-action-trigger"
                    disabled={selected.size === 0}
                    onClick={() => setBulkOpen((open) => !open)}
                  >
                    일괄 조치 <ChevronDown size={15} />
                  </button>
                  {bulkOpen && (
                    <div className="bulk-menu">
                      <button data-testid="bulk-resolve" onClick={resolveSelected}><CheckCircle2 size={16} /> 조치 완료로 변경</button>
                    </div>
                  )}
                </div>
                <div className="popover-anchor">
                  <button
                    className={`filter-button ${activeFilterCount ? 'active' : ''}`}
                    data-testid="filter-trigger"
                    onClick={() => setFiltersOpen((open) => !open)}
                  >
                    <Filter size={16} /> 필터
                    {activeFilterCount > 0 && <span>{activeFilterCount}</span>}
                  </button>
                  {filtersOpen && (
                    <div className="filters-panel" data-testid="filters-surface">
                      <div className="filters-header"><div><strong>운송 필터</strong><small>조건을 조합해 운송을 좁혀보세요.</small></div><button onClick={() => setFiltersOpen(false)} aria-label="닫기"><X size={18} /></button></div>
                      <div className="filter-grid">
                        <label>운송일
                          <input type="date" data-testid="filter-date" value={draftFilters.date} onChange={(event) => setDraftFilters({ ...draftFilters, date: event.target.value })} />
                        </label>
                        <label>운송 상태
                          <select data-testid="filter-status" value={draftFilters.status} onChange={(event) => setDraftFilters({ ...draftFilters, status: event.target.value as ShipmentStatus | '' })}>
                            <option value="">전체 상태</option>
                            <option value="normal">정상</option>
                            <option value="temperature-excursion" data-testid="filter-status-option-temperature-excursion">온도 이탈</option>
                            <option value="delayed">배송 지연</option>
                            <option value="sensor-offline">센서 단절</option>
                            <option value="resolved">조치 완료</option>
                          </select>
                        </label>
                        <label>물류 거점
                          <select data-testid="filter-hub" value={draftFilters.hub} onChange={(event) => setDraftFilters({ ...draftFilters, hub: event.target.value })}>
                            <option value="">전체 거점</option>
                            {initialData.hubs.map((hub) => <option key={hub.id} value={hub.id} data-testid={`filter-hub-option-${hub.id}`}>{hub.name}</option>)}
                          </select>
                        </label>
                        <label>온도 상태
                          <select data-testid="filter-temperature" value={draftFilters.temperature} onChange={(event) => setDraftFilters({ ...draftFilters, temperature: event.target.value as TemperatureState | '' })}>
                            <option value="">전체 온도</option>
                            {Object.entries(temperatureLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                          </select>
                        </label>
                        <label className="filter-driver-label">배차 기사
                          <select data-testid="filter-driver" value={draftFilters.driver} onChange={(event) => setDraftFilters({ ...draftFilters, driver: event.target.value })}>
                            <option value="">전체 기사</option>
                            {drivers.map((driver) => <option key={driver.id} value={driver.id}>{driver.name} · {driver.id}</option>)}
                          </select>
                        </label>
                      </div>
                      <div className="filters-footer">
                        <button className="text-button" onClick={() => setDraftFilters(blankFilters)}> 조건 초기화</button>
                        <button className="primary-button" data-testid="filter-apply" onClick={() => { setAppliedFilters(draftFilters); setSelected(new Set()); setFiltersOpen(false) }}>적용하기</button>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>

            <div className="table-scroll">
              <table className="shipments-table">
                <thead>
                  <tr>
                    <th className="check-cell"><input type="checkbox" aria-label="표시된 운송 전체 선택" data-testid="select-all-visible" checked={allVisibleSelected} onChange={toggleAllVisible} /></th>
                    <th>상태</th>
                    <th>운송장 번호</th>
                    <th>화물</th>
                    <th>운송 구간</th>
                    <th>기사</th>
                    <th>차량</th>
                    <th>
                      <button className="sort-button" data-testid="sort-temperature" onClick={() => setTemperatureSort((sort) => sort === 'none' ? 'asc' : sort === 'asc' ? 'desc' : 'none')}>
                        현재 온도 <ChevronDown size={13} className={temperatureSort === 'asc' ? 'sort-asc' : temperatureSort === 'desc' ? 'sort-desc' : ''} />
                      </button>
                    </th>
                    <th>허용 범위</th>
                    <th>도착 예정</th>
                    <th>알림</th>
                    <th aria-label="상세" />
                  </tr>
                </thead>
                <tbody>
                  {visibleShipments.map((shipment) => {
                    const driver = driversById.get(shipment.driverId)
                    const vehicle = vehiclesById.get(shipment.vehicleId)
                    const origin = hubsById.get(shipment.originHubId)
                    const destination = hubsById.get(shipment.destinationHubId)
                    return (
                      <tr key={shipment.id} className={selected.has(shipment.id) ? 'selected-row' : ''}>
                        <td className="check-cell"><input type="checkbox" aria-label={`${shipment.id} 선택`} data-testid={`row-select-${shipment.id}`} checked={selected.has(shipment.id)} onChange={() => toggleSelection(shipment.id)} /></td>
                        <td><StatusBadge shipment={shipment} /></td>
                        <td><button className="tracking-button" data-testid={`shipment-open-${shipment.id}`} onClick={() => openDetail(shipment)}>{shipment.trackingCode}<small>{shipment.id}</small></button></td>
                        <td><div className="cargo-cell"><Package size={15} /><span title={shipment.cargoName}>{shipment.cargoName}</span></div></td>
                        <td><div className="route-cell"><span>{origin?.city}</span><i /><span>{destination?.city}</span></div></td>
                        <td><div className="person-cell"><span className="mini-avatar">{driver?.name.slice(0, 1)}</span><div><strong>{driver?.name}</strong><small>{driver?.phone}</small></div></div></td>
                        <td><div className="vehicle-cell"><strong>{vehicle?.plate}</strong><small>{vehicle?.model}</small></div></td>
                        <td><TemperatureValue shipment={shipment} /><small className="temp-state-label">{temperatureLabels[shipment.temperatureState]}</small></td>
                        <td><span className="range-value">{shipment.minTemperature}° ~ {shipment.maxTemperature}°</span></td>
                        <td><div className="eta-cell"><strong>{formatDateTime(shipment.eta)}</strong><small>{shipment.status === 'delayed' ? '지연 예상' : '예정'}</small></div></td>
                        <td>{shipment.alertCount > 0 ? <span className={`alert-count ${shipment.temperatureState}`}>{shipment.alertCount}</span> : <span className="no-alert">—</span>}</td>
                        <td><button className="row-open" aria-label={`${shipment.id} 상세 열기`} onClick={() => openDetail(shipment)}><ChevronRight size={17} /></button></td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
              {visibleShipments.length === 0 && <div className="table-empty"><Search size={26} /><strong>조건에 맞는 운송이 없습니다.</strong><span>필터를 다시 확인해 주세요.</span></div>}
            </div>
            <div className="table-footer"><span>전체 {visibleShipments.length}건 모두 표시 중</span><span><CircleGauge size={14} /> 데이터 자동 갱신 30초</span></div>
          </section>
        </main>
      </div>

      {notificationsOpen && (
        <>
          <button className="drawer-backdrop" aria-label="알림 닫기" onClick={() => setNotificationsOpen(false)} />
          <aside className="drawer notification-drawer" data-testid="notifications-surface" aria-label="알림 센터">
            <div className="drawer-header">
              <div><p className="section-kicker">실시간 이벤트</p><h2>알림 센터 <span>{alerts.length}</span></h2></div>
              <button className="drawer-close" onClick={() => setNotificationsOpen(false)} aria-label="닫기"><X size={20} /></button>
            </div>
            <div className="notification-summary">
              <div><strong>{unreadCount}</strong><span>읽지 않음</span></div>
              <div><strong>{alerts.filter((alert) => alert.resolution !== 'resolved').length}</strong><span>처리 대기</span></div>
              <button onClick={() => setAlerts((current) => current.map((alert) => ({ ...alert, read: true })))}>모두 읽음</button>
            </div>
            <div className="notification-list">
              {alerts.map((alert) => (
                <article key={alert.id} className={`notification-card severity-${alert.severity} ${alert.read ? 'is-read' : ''}`} data-testid={`notification-${alert.id}`}>
                  <div className="notification-card-top">
                    <div className="severity-icon">{alert.severity === 'critical' ? <AlertTriangle size={17} /> : alert.severity === 'warning' ? <Clock3 size={17} /> : <Activity size={17} />}</div>
                    <div className="notification-copy"><div><strong>{alert.title}</strong><span>{formatDateTime(alert.createdAt)}</span></div><p>{alert.message}</p></div>
                  </div>
                  <div className="notification-meta">
                    <button className="shipment-pill" onClick={() => { const shipment = shipments.find((item) => item.id === alert.shipmentId); if (shipment) openDetail(shipment); setNotificationsOpen(false) }}>{alert.shipmentId} <ChevronRight size={13} /></button>
                    <div className="notification-controls">
                      <button data-testid={`notification-toggle-read-${alert.id}`} onClick={() => updateAlert(alert.id, (current) => ({ ...current, read: !current.read }))}>
                        {alert.read ? '안 읽음' : '읽음'}
                      </button>
                      <span data-testid={`notification-state-${alert.id}`} data-state={alert.read ? 'read' : 'unread'}>{alert.read ? '읽음' : '안 읽음'}</span>
                      <button data-testid={`notification-toggle-resolution-${alert.id}`} onClick={() => updateAlert(alert.id, (current) => ({ ...current, resolution: cycleResolution(current.resolution) }))}>상태 변경</button>
                      <span className={`resolution resolution-${alert.resolution}`} data-testid={`notification-resolution-${alert.id}`} data-state={alert.resolution}>{resolutionLabels[alert.resolution]}</span>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </aside>
        </>
      )}

      {detailShipment && (
        <>
          <button className="drawer-backdrop" aria-label="상세 닫기" onClick={() => setDetailId(null)} />
          <aside className="drawer detail-drawer" data-testid="shipment-detail" aria-label={`${detailShipment.id} 운송 상세`}>
            <div className="drawer-header detail-header">
              <div><p className="section-kicker">{detailShipment.id}</p><h2>{detailShipment.cargoName}</h2><span className="detail-tracking">{detailShipment.trackingCode}</span></div>
              <button className="drawer-close" onClick={() => setDetailId(null)} aria-label="닫기"><X size={20} /></button>
            </div>
            <div className="detail-status-strip"><StatusBadge shipment={detailShipment} /><span><Clock3 size={14} /> 도착 {formatDateTime(detailShipment.eta)}</span><span><Bell size={14} /> 알림 {detailShipment.alertCount}건</span></div>

            {saveSuccess && <div className="save-success" data-testid="save-success"><CheckCircle2 size={17} /> 배차 및 운송 정보를 저장했습니다.</div>}

            {editing && dispatchForm ? (
              <form className="dispatch-form" onSubmit={saveDispatch}>
                <div className="form-section-heading"><div><p className="section-kicker">운송 정보</p><h3>배차 및 운송 수정</h3></div><span>필수 항목 *</span></div>
                {validationError && <div className="validation-error" data-testid="validation-error"><AlertTriangle size={16} /> {validationError}</div>}
                <div className="form-grid">
                  <label>기사명 *<input data-testid="dispatch-driver-name" value={dispatchForm.driverName} onChange={(event) => setDispatchForm({ ...dispatchForm, driverName: event.target.value })} /></label>
                  <label>연락처 *<input data-testid="dispatch-phone" value={dispatchForm.phone} onChange={(event) => setDispatchForm({ ...dispatchForm, phone: event.target.value })} /></label>
                  <label className="full-width">운송장 번호 *<input data-testid="dispatch-tracking" value={dispatchForm.trackingCode} onChange={(event) => setDispatchForm({ ...dispatchForm, trackingCode: event.target.value })} /></label>
                  <label className="full-width custom-select-label">배차 기사 *
                    <button type="button" className="driver-control" data-testid="driver-control" aria-expanded={driverOptionsOpen} onClick={() => setDriverOptionsOpen((open) => !open)}>
                      <span><span className="mini-avatar">{driversById.get(dispatchForm.driverId)?.name.slice(0, 1)}</span><span><strong>{driversById.get(dispatchForm.driverId)?.name}</strong><small>{dispatchForm.driverId} · {driversById.get(dispatchForm.driverId)?.homeHubId}</small></span></span><ChevronDown size={16} />
                    </button>
                    {driverOptionsOpen && (
                      <div className="driver-options" data-testid="driver-options">
                        <div className="driver-options-header"><span><Users size={15} /> 전체 기사 {drivers.length}명</span><small>선택 시 연락처가 함께 반영됩니다.</small></div>
                        {drivers.map((driver) => (
                          <button type="button" key={driver.id} data-testid={`driver-option-${driver.id}`} className={driver.id === dispatchForm.driverId ? 'selected-driver' : ''} onClick={() => selectDriver(driver)}>
                            <span className="mini-avatar">{driver.name.slice(0, 1)}</span><span><strong>{driver.name}</strong><small>{driver.id} · {driver.phone}</small></span>{driver.id === dispatchForm.driverId && <Check size={16} />}
                          </button>
                        ))}
                      </div>
                    )}
                  </label>
                  <label>차량 *<select value={dispatchForm.vehicleId} onChange={(event) => setDispatchForm({ ...dispatchForm, vehicleId: event.target.value })}>{initialData.vehicles.map((vehicle) => <option key={vehicle.id} value={vehicle.id}>{vehicle.plate} · {vehicle.model}</option>)}</select></label>
                  <label>운송 상태 *<select value={dispatchForm.status} onChange={(event) => setDispatchForm({ ...dispatchForm, status: event.target.value as ShipmentStatus })}>{Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
                  <label>출발지 *<select value={dispatchForm.originHubId} onChange={(event) => setDispatchForm({ ...dispatchForm, originHubId: event.target.value })}>{initialData.hubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</select></label>
                  <label>도착지 *<select value={dispatchForm.destinationHubId} onChange={(event) => setDispatchForm({ ...dispatchForm, destinationHubId: event.target.value })}>{initialData.hubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</select></label>
                  <label>최저 온도 (°C) *<input type="number" step="0.1" data-testid="dispatch-min-temperature" value={dispatchForm.minTemperature} onChange={(event) => setDispatchForm({ ...dispatchForm, minTemperature: event.target.value })} /></label>
                  <label>최고 온도 (°C) *<input type="number" step="0.1" data-testid="dispatch-max-temperature" value={dispatchForm.maxTemperature} onChange={(event) => setDispatchForm({ ...dispatchForm, maxTemperature: event.target.value })} /></label>
                  <label className="full-width">운송 메모<textarea rows={4} data-testid="dispatch-notes" value={dispatchForm.notes} onChange={(event) => setDispatchForm({ ...dispatchForm, notes: event.target.value })} placeholder="특이사항을 입력하세요." /></label>
                </div>
                <div className="form-actions"><button type="button" className="ghost-button" data-testid="cancel-dispatch" onClick={() => { setEditing(false); setValidationError(''); setDriverOptionsOpen(false) }}>취소</button><button type="submit" className="primary-button" data-testid="save-dispatch"><Check size={16} /> 변경사항 저장</button></div>
              </form>
            ) : (
              <div className="detail-scroll-area">
                <section className="detail-section current-section">
                  <div className="detail-section-heading"><div><p className="section-kicker">현재 정보</p><h3>배차 및 운송</h3></div><button className="edit-button" data-testid="edit-dispatch" onClick={beginEditing}><Edit3 size={15} /> 수정</button></div>
                  <div className="info-grid">
                    <div><span>배차 기사</span><strong data-testid="dispatch-driver">{driversById.get(detailShipment.driverId)?.name}</strong><small>{driversById.get(detailShipment.driverId)?.phone}</small></div>
                    <div><span>차량</span><strong>{vehiclesById.get(detailShipment.vehicleId)?.plate}</strong><small>{vehiclesById.get(detailShipment.vehicleId)?.model}</small></div>
                    <div className="route-info"><span>운송 구간</span><strong>{hubsById.get(detailShipment.originHubId)?.name} <ChevronRight size={13} /> {hubsById.get(detailShipment.destinationHubId)?.name}</strong><small>{detailShipment.destinationAddress}</small></div>
                    <div><span>허용 온도</span><strong>{detailShipment.minTemperature}°C ~ {detailShipment.maxTemperature}°C</strong><small>현재 {detailShipment.currentTemperature === null ? '수신 불가' : `${detailShipment.currentTemperature.toFixed(1)}°C`}</small></div>
                  </div>
                  {detailShipment.notes && <div className="notes-block"><strong>운송 메모</strong><p>{detailShipment.notes}</p></div>}
                </section>

                <section className="detail-section">
                  <div className="detail-section-heading"><div><p className="section-kicker">센서 데이터</p><h3>최근 온도 추이</h3></div><span className={`temperature-state-chip ${detailShipment.temperatureState}`}>{temperatureLabels[detailShipment.temperatureState]}</span></div>
                  <ShipmentMiniChart events={initialData.eventsByShipment[detailShipment.id]} shipment={detailShipment} />
                  <div className="chart-caption"><span><i className="allowed-key" />허용 범위</span><span><i className="current-key" />실측 온도</span></div>
                </section>

                <section className="detail-section">
                  <div className="detail-section-heading"><div><p className="section-kicker">장비 통신</p><h3>센서 이벤트</h3></div><Gauge size={18} /></div>
                  <div className="sensor-event-list">
                    {initialData.eventsByShipment[detailShipment.id].filter((event) => event.kind === 'sensor').slice(0, 5).map((event) => (
                      <div key={event.id}><span className="timeline-icon"><WifiOff size={14} /></span><div><strong>{event.title}</strong><p>{event.detail}</p></div><time>{formatDateTime(event.occurredAt)}</time></div>
                    ))}
                  </div>
                </section>

                <section className="detail-section history-section">
                  <div className="detail-section-heading"><div><p className="section-kicker">운영 기록</p><h3>전체 조치 이력 <span>{initialData.eventsByShipment[detailShipment.id].length}</span></h3></div></div>
                  <div className="timeline-list">
                    {initialData.eventsByShipment[detailShipment.id].map((event) => (
                      <div className="timeline-event" key={event.id}>
                        <div className={`timeline-marker kind-${event.kind}`}>{event.kind === 'temperature' ? <Thermometer size={14} /> : event.kind === 'location' ? <MapPin size={14} /> : event.kind === 'sensor' ? <Activity size={14} /> : <ShieldCheck size={14} />}</div>
                        <div><strong>{event.title}{event.temperature !== null && <em>{event.temperature.toFixed(1)}°C</em>}</strong><p>{event.detail}</p><time>{formatDateTime(event.occurredAt)}</time></div>
                      </div>
                    ))}
                  </div>
                </section>
              </div>
            )}
          </aside>
        </>
      )}
    </div>
  )
}
