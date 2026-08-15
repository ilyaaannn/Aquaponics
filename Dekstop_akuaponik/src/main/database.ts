/**
 * Database Manager — Aquaphonik Desktop
 * Handles PostgreSQL database initialization, sensor data logging, and queries.
 * Uses 'pg' for asynchronous operations.
 */

import { Pool } from 'pg'

let pool: Pool | null = null

export interface SensorLog {
  id?: number
  timestamp: string | Date
  temp_water: number
  ph: number
  ph_volts: number
  tds: number
  do_value: number
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

/**
 * Initialize the database connection
 */
export async function initDatabase(): Promise<void> {
  console.log('[Database] Connecting to PostgreSQL...')

  pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'aquaphonik',
    password: '123456', // Password dari user
    port: 5432
  })

  // Create sensor_logs table if not exists
  const createTableQuery = `
    CREATE TABLE IF NOT EXISTS sensor_logs (
      id SERIAL PRIMARY KEY,
      timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      temp_water REAL DEFAULT 0,
      ph REAL DEFAULT 0,
      ph_volts REAL DEFAULT 0,
      tds REAL DEFAULT 0,
      do_value REAL DEFAULT 0,
      turbidity REAL DEFAULT 0,
      water_lvl REAL DEFAULT 0,
      co2 REAL DEFAULT 0,
      eco2 REAL DEFAULT 0,
      tvoc REAL DEFAULT 0,
      temp_air REAL DEFAULT 0,
      humidity REAL DEFAULT 0,
      pump_status INTEGER DEFAULT 0,
      oxy_status INTEGER DEFAULT 0
    )
  `

  try {
    await pool.query(createTableQuery)
    console.log('[Database] Table sensor_logs initialized')

    // Create index for faster timestamp queries
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_sensor_logs_timestamp
      ON sensor_logs(timestamp DESC)
    `)
    console.log('✅ [Database] Berhasil terhubung ke PostgreSQL (Database: aquaphonik)!')
    console.log('✅ [Database] Tabel sensor_logs siap digunakan.')
  } catch (error) {
    console.error('❌ [Database] Gagal terhubung ke PostgreSQL:', error)
  }
}

/**
 * Insert sensor data into the database
 */
export async function insertSensorLog(data: Omit<SensorLog, 'id' | 'timestamp'>): Promise<SensorLog | null> {
  if (!pool) {
    console.error('[Database] Not initialized')
    return null
  }

  try {
    const query = `
      INSERT INTO sensor_logs (
        temp_water, ph, ph_volts, tds, do_value, turbidity, water_lvl,
        co2, eco2, tvoc, temp_air, humidity, pump_status, oxy_status
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
      ) RETURNING *
    `
    const values = [
      data.temp_water || 0,
      data.ph || 0,
      data.ph_volts || 0,
      data.tds || 0,
      data.do_value || 0,
      data.turbidity || 0,
      data.water_lvl || 0,
      data.co2 || 0,
      data.eco2 || 0,
      data.tvoc || 0,
      data.temp_air || 0,
      data.humidity || 0,
      data.pump_status || 0,
      data.oxy_status || 0
    ]

    const result = await pool.query(query, values)
    return result.rows[0] as SensorLog
  } catch (error) {
    console.error('[Database] Insert error:', error)
    return null
  }
}

/**
 * Get the latest N sensor logs
 */
export async function getLatestLogs(limit: number = 100): Promise<SensorLog[]> {
  if (!pool) return []

  try {
    const query = 'SELECT * FROM sensor_logs ORDER BY timestamp DESC LIMIT $1'
    const result = await pool.query(query, [limit])
    return result.rows as SensorLog[]
  } catch (error) {
    console.error('[Database] Query error:', error)
    return []
  }
}

/**
 * Get sensor logs within a date range
 */
export async function getLogsByDateRange(startDate: string, endDate: string): Promise<SensorLog[]> {
  if (!pool) return []

  try {
    const query = 'SELECT * FROM sensor_logs WHERE timestamp BETWEEN $1 AND $2 ORDER BY timestamp DESC'
    const result = await pool.query(query, [startDate, endDate])
    return result.rows as SensorLog[]
  } catch (error) {
    console.error('[Database] Query error:', error)
    return []
  }
}

/**
 * Get log count
 */
export async function getLogCount(): Promise<number> {
  if (!pool) return 0

  try {
    const query = 'SELECT COUNT(*) as count FROM sensor_logs'
    const result = await pool.query(query)
    return parseInt(result.rows[0].count, 10)
  } catch (error) {
    console.error('[Database] Count error:', error)
    return 0
  }
}

/**
 * Delete old logs (retention policy, e.g., older than 30 days)
 */
export async function deleteOldLogs(daysToKeep: number = 30): Promise<number> {
  if (!pool) return 0

  try {
    const query = "DELETE FROM sensor_logs WHERE timestamp < NOW() - INTERVAL '" + daysToKeep + " days'"
    const result = await pool.query(query)
    return result.rowCount || 0
  } catch (error) {
    console.error('[Database] Delete error:', error)
    return 0
  }
}

/**
 * Close the database connection
 */
export async function closeDatabase(): Promise<void> {
  if (pool) {
    await pool.end()
    pool = null
    console.log('[Database] Connection closed')
  }
}
