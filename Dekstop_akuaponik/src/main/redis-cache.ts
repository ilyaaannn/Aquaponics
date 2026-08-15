/**
 * Redis Cache — Aquaphonik Desktop
 *
 * Menyimpan data sensor real-time (yang datang dari kabel USB tiap ~2 detik)
 * ke Redis, agar:
 *  1. Klien mobile yang baru terkoneksi via Socket.IO langsung mendapat nilai
 *     terakhir tanpa menunggu siklus kirim berikutnya.
 *  2. Endpoint REST /api/current & /api/health punya sumber data yang cepat
 *     (tidak perlu query PostgreSQL untuk data live).
 *
 * TTL disamakan dengan sisi Python (server Smartfarm): 1 jam (3600 detik).
 * Key diberi prefix "desktop_" supaya tidak bentrok dengan key milik server
 * Python (mis. "current_water_data") walau berbagi instance Redis yang sama.
 */

import { createClient, RedisClientType } from 'redis'

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379'
const TTL_SECONDS = 3600 // 1 jam — samakan dengan sisi Smartfarm (Python)
const HISTORY_MAX_LEN = 1800 // ~1 jam data pada interval 2 detik (3600 / 2)

const CURRENT_KEY = 'desktop_current_sensor_data'
const HISTORY_KEY = 'desktop_sensor_history'

let client: RedisClientType | null = null
let isReady = false

/**
 * Arduino mengirim key "do" (lihat aquaponik.ino: doc["do"] = doValue), tapi
 * kolom Postgres & model Flutter (kDesktopParams) memakai nama "do_value".
 * Normalisasi di sini supaya payload live stream (Socket.IO/Redis) konsisten
 * dengan payload REST /api/history yang berasal dari Postgres.
 */
export function normalizeSensorPayload(
  raw: Record<string, unknown>
): Record<string, unknown> {
  const normalized: Record<string, unknown> = { ...raw }
  if ('do' in normalized && !('do_value' in normalized)) {
    normalized.do_value = normalized.do
    delete normalized.do
  }
  return normalized
}

export async function initRedisCache(): Promise<void> {
  try {
    client = createClient({ url: REDIS_URL })

    client.on('error', (err) => {
      console.error('[Redis] Error koneksi:', err.message)
      isReady = false
    })
    client.on('ready', () => {
      console.log('[Redis] ✓ Terhubung ke', REDIS_URL)
      isReady = true
    })
    client.on('end', () => {
      isReady = false
    })

    await client.connect()
  } catch (error) {
    console.error('[Redis] Gagal konek, cache real-time akan dilewati:', (error as Error).message)
    isReady = false
  }
}

/**
 * Simpan 1 pembacaan sensor ke Redis (nilai terkini + histori), masing-masing
 * dengan TTL 1 jam. Dipanggil setiap kali data baru masuk dari serial (~2 detik).
 */
export async function cacheSensorData(data: Record<string, unknown>): Promise<void> {
  if (!client || !isReady) return

  const payload = JSON.stringify({ ...data, cached_at: new Date().toISOString() })

  try {
    await client.set(CURRENT_KEY, payload, { EX: TTL_SECONDS })
    await client.lPush(HISTORY_KEY, payload)
    await client.lTrim(HISTORY_KEY, 0, HISTORY_MAX_LEN - 1)
    await client.expire(HISTORY_KEY, TTL_SECONDS)
  } catch (error) {
    console.error('[Redis] Gagal menyimpan cache sensor:', (error as Error).message)
  }
}

/** Ambil pembacaan terakhir dari cache (untuk /api/current & saat client baru connect) */
export async function getLatestCachedData(): Promise<Record<string, unknown> | null> {
  if (!client || !isReady) return null
  try {
    const raw = await client.get(CURRENT_KEY)
    return raw ? JSON.parse(raw) : null
  } catch (error) {
    console.error('[Redis] Gagal membaca cache sensor:', (error as Error).message)
    return null
  }
}

/** Ambil histori 1 jam terakhir dari Redis (dipakai kalau suatu saat perlu tanpa query Postgres) */
export async function getCachedHistory(limit = HISTORY_MAX_LEN): Promise<Record<string, unknown>[]> {
  if (!client || !isReady) return []
  try {
    const raw = await client.lRange(HISTORY_KEY, 0, limit - 1)
    return raw.map((item) => JSON.parse(item))
  } catch (error) {
    console.error('[Redis] Gagal membaca histori cache:', (error as Error).message)
    return []
  }
}

export function isRedisReady(): boolean {
  return isReady
}

export async function pingRedis(): Promise<boolean> {
  if (!client || !isReady) return false
  try {
    await client.ping()
    return true
  } catch {
    return false
  }
}

export async function closeRedisCache(): Promise<void> {
  if (client) {
    await client.quit()
    client = null
    isReady = false
  }
}
