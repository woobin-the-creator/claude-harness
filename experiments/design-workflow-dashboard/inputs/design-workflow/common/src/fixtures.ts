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
