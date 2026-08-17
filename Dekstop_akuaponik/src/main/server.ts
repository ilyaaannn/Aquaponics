/**
 * server.ts — Aquaponik Headless Server (Produksi, 24/7)
 */

import {
  listPorts,
  connectPort,
  getStatus as getSerialStatus,
  onData as onSerialData,
  serialEvents,
  cleanup as serialCleanup
} from './serial'
import { initDatabase, insertSensorLog, closeDatabase } from './database'
import { initServer, publishSensorData, closeServer } from './express-api'
import { initRedisCache, closeRedisCache } from './redis-cache'

// ── Konfigurasi ────────────────────────────────────────────────────────
const SERIAL_PORT = process.env.SERIAL_PORT || ''
const SERIAL_BAUD = Number(process.env.SERIAL_BAUD) || 115200
const SERIAL_RETRY_MS = Number(process.env.SERIAL_RETRY_MS) || 5000
const LOG_INTERVAL_MINUTES = Number(process.env.LOG_INTERVAL_MINUTES) || 1

let lastLogTimestamp = 0
let shuttingDown = false
let serialWatcherTimer: NodeJS.Timeout | null = null
let connectAttempts = 0

function log(msg: string): void {
  console.log(`[${new Date().toISOString()}] ${msg}`)
}

/** Log "menunggu/ambigu" cukup sesekali saja, bukan tiap 5 detik terus-menerus. */
function logThrottled(msg: string): void {
  if (connectAttempts % 12 === 1) log(msg) // ~sekali semenit kalau retry=5s
}

/** sambungkan ke serial port. */
async function attemptSerialConnect(): Promise<void> {
  if (shuttingDown) return
  connectAttempts++

  const status = getSerialStatus()
  if (status.connected) return // sudah tersambung, tidak perlu apa-apa

  let targetPort = SERIAL_PORT

  if (!targetPort) {
    const ports = await listPorts()
    if (ports.length === 1) {
      targetPort = ports[0].path
      log(`SERIAL_PORT tidak diset di env, auto-detect: ${targetPort}`)
    } else if (ports.length === 0) {
      logThrottled('Belum ada serial port terdeteksi. Pastikan Arduino menyala & USB tersambung...')
      return
    } else {
      logThrottled(
        `Ditemukan ${ports.length} serial port sekaligus (${ports.map((p) => p.path).join(', ')}). ` +
          `Set environment variable SERIAL_PORT ke salah satunya agar tidak ambigu.`
      )
      return
    }
  }

  const result = await connectPort(targetPort, SERIAL_BAUD)
  if (result.success) {
    log(`✓ Serial terhubung: ${targetPort} @ ${SERIAL_BAUD} baud`)
  } else {
    logThrottled(
      `Gagal konek ke ${targetPort}: ${result.message}. Mencoba lagi tiap ${SERIAL_RETRY_MS / 1000}s...`
    )
  }
}

/** Loop pengawas: cek & sambungkan ulang serial secara berkala. */
function startSerialWatcher(): void {
  attemptSerialConnect()
  serialWatcherTimer = setInterval(attemptSerialConnect, SERIAL_RETRY_MS)
}

/**
 * Setiap data sensor masuk dari serial:
 *  1. Broadcast real-time ke mobile (Socket.IO 'sensor/realtime' + cache
 *     Redis TTL 1 jam) — persis kecepatan kabel, ~2 detik.
 *  2. Simpan ke PostgreSQL, dibatasi interval (default 1 menit) supaya
 *     tabel tidak membengkak walau data masuk tiap ~2 detik.
 * Perintah kontrol aktuator dari mobile (Socket.IO 'actuator/command')
 * ditangani langsung di express-api.ts lewat sendCommand()
 */
function wireSerialToBackend(): void {
  onSerialData((data) => {
    publishSensorData(data)

    const now = Date.now()
    const intervalMs = LOG_INTERVAL_MINUTES * 60 * 1000
    if (now - lastLogTimestamp >= intervalMs) {
      insertSensorLog({
        temp_water: data.temp_water ?? 0,
        ph: data.ph ?? 0,
        ph_volts: data.ph_volts ?? 0,
        tds: data.tds ?? 0,
        do_value: data.do ?? 0,
        turbidity: data.turbidity ?? 0,
        water_lvl: data.water_lvl ?? 0,
        co2: data.co2 ?? 0,
        eco2: data.eco2 ?? 0,
        tvoc: data.tvoc ?? 0,
        temp_air: data.temp_air ?? 0,
        humidity: data.humidity ?? 0,
        pump_status: data.pump_status ?? 0,
        oxy_status: data.oxy_status ?? 0
      }).catch((err) => log(`Gagal simpan log ke PostgreSQL: ${(err as Error).message}`))
      lastLogTimestamp = now
    }
  })

  // Observability di log PM2/aaPanel — bukan wajib secara fungsi, cuma supaya gampang dipantau tanpa perlu buka database/redis manual.
  serialEvents.on('serial:status', (s: { connected: boolean; port: string }) => {
    log(s.connected ? `Status serial: TERHUBUNG (${s.port})` : 'Status serial: TERPUTUS')
  })
  serialEvents.on('serial:error', (e: { message: string }) => {
    log(`Error serial: ${e.message}`)
  })
}

async function main(): Promise<void> {
  log(' Aquaponik Headless Server — memulai...')

  await initDatabase()
  await initRedisCache()
  initServer()

  wireSerialToBackend()
  startSerialWatcher()

  log(
    'Server siap. Menunggu data Arduino & koneksi mobile app (2 detik desktop, via server ini)...'
  )
}

// ── Graceful shutdown ──────────────────────────────────────────────────
async function shutdown(signal: string): Promise<void> {
  if (shuttingDown) return
  shuttingDown = true
  log(`Menerima ${signal}, mematikan service dengan rapi...`)

  if (serialWatcherTimer) clearInterval(serialWatcherTimer)
  serialCleanup()
  closeServer()
  await closeDatabase()
  await closeRedisCache()

  log('Selesai dimatikan dengan rapi.')
  process.exit(0)
}

process.on('SIGTERM', () => shutdown('SIGTERM'))
process.on('SIGINT', () => shutdown('SIGINT'))

// Jangan biarkan proses mati diam-diam tanpa jejak log — PM2 akan tetap auto-restart, tapi kita perlu tahu PENYEBABNYA dari log sebelum itu terjadi.
process.on('uncaughtException', (err) => {
  console.error('[FATAL] Uncaught Exception:', err)
})
process.on('unhandledRejection', (reason) => {
  console.error('[FATAL] Unhandled Rejection:', reason)
})

main().catch((err) => {
  console.error('[FATAL] Gagal start server:', err)
  process.exit(1)
})
