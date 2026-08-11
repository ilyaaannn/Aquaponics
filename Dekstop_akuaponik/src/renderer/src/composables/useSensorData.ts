/**
 * useSensorData — Composable for real-time sensor data management
 * Receives data from the serial port and maintains reactive state.
 */

import { ref, computed, onMounted, onUnmounted } from 'vue'

export interface SensorData {
  temp_water: number
  ph: number
  ph_volts: number
  tds: number
  do: number
  turbidity: number
  water_lvl: number
  co2: number
  eco2: number
  tvoc: number
  temp_air: number
  humidity: number
  pump_status: number
  oxy_status: number
}

// Chart history — store last N data points for the live chart
const MAX_CHART_POINTS = 30

export function useSensorData() {
  const sensorData = ref<SensorData>({
    temp_water: 0,
    ph: 0,
    ph_volts: 0,
    tds: 0,
    do: 0,
    turbidity: 0,
    water_lvl: 0,
    co2: 0,
    eco2: 0,
    tvoc: 0,
    temp_air: 0,
    humidity: 0,
    pump_status: 0,
    oxy_status: 0
  })

  const lastUpdated = ref<Date | null>(null)
  const dataReceived = ref(false)

  // Chart history arrays
  const chartHistory = ref<{
    labels: string[]
    temp_water: number[]
    ph: number[]
    tds: number[]
    do_val: number[]
    temp_air: number[]
    humidity: number[]
  }>({
    labels: [],
    temp_water: [],
    ph: [],
    tds: [],
    do_val: [],
    temp_air: [],
    humidity: []
  })

  // Computed: pump & oxygen status as boolean
  const isPumpOn = computed(() => sensorData.value.pump_status === 1)
  const isOxygenOn = computed(() => sensorData.value.oxy_status === 1)

  // Computed: formatted last update time
  const lastUpdateFormatted = computed(() => {
    if (!lastUpdated.value) return 'No data'
    return lastUpdated.value.toLocaleTimeString('id-ID', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })
  })

  /**
   * Handle incoming sensor data
   */
  function handleData(data: Record<string, number>): void {
    sensorData.value = {
      temp_water: data.temp_water ?? 0,
      ph: data.ph ?? 0,
      ph_volts: data.ph_volts ?? 0,
      tds: data.tds ?? 0,
      do: data.do ?? 0,
      turbidity: data.turbidity ?? 0,
      water_lvl: data.water_lvl ?? 0,
      co2: data.co2 ?? 0,
      eco2: data.eco2 ?? 0,
      tvoc: data.tvoc ?? 0,
      temp_air: data.temp_air ?? 0,
      humidity: data.humidity ?? 0,
      pump_status: data.pump_status ?? 0,
      oxy_status: data.oxy_status ?? 0
    }

    lastUpdated.value = new Date()
    dataReceived.value = true

    // Update chart history
    const now = new Date()
    const timeLabel = now.toLocaleTimeString('id-ID', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })

    const h = chartHistory.value
    h.labels.push(timeLabel)
    h.temp_water.push(data.temp_water ?? 0)
    h.ph.push(data.ph ?? 0)
    h.tds.push(data.tds ?? 0)
    h.do_val.push(data.do ?? 0)
    h.temp_air.push(data.temp_air ?? 0)
    h.humidity.push(data.humidity ?? 0)

    // Trim to max points
    if (h.labels.length > MAX_CHART_POINTS) {
      h.labels.shift()
      h.temp_water.shift()
      h.ph.shift()
      h.tds.shift()
      h.do_val.shift()
      h.temp_air.shift()
      h.humidity.shift()
    }
  }

  onMounted(() => {
    window.api.serial.onData(handleData)
  })

  onUnmounted(() => {
    // Listeners will be cleaned up by useSerial
  })

  return {
    sensorData,
    lastUpdated,
    lastUpdateFormatted,
    dataReceived,
    chartHistory,
    isPumpOn,
    isOxygenOn
  }
}
