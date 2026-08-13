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
