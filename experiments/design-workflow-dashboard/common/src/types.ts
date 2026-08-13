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
