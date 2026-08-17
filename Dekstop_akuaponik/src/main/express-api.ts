import express from 'express'
import { createServer } from 'http'
import { Server } from 'socket.io'
import cors from 'cors'
import { getLatestLogs, getLogsByDateRange } from './database'
import { sendCommand, getStatus as getSerialStatus } from './serial'
import {
  cacheSensorData,
  getLatestCachedData,
  normalizeSensorPayload,
  pingRedis
} from './redis-cache'

let io: Server | null = null
let httpServer: ReturnType<typeof createServer> | null = null

const PORT = 8000

export function initServer(): void {
  const app = express()
  // Trust proxy sangat penting jika berada di belakang Cloudflare Tunnel
  app.set('trust proxy', 1)

  app.use(
    cors({
      origin: '*',
      methods: ['GET', 'POST', 'OPTIONS', 'PUT', 'DELETE'],
      allowedHeaders: ['Content-Type', 'Authorization']
    })
  )
  app.use(express.json())

  // --- Health check — dipakai tombol "Tes Ulang" di halaman Setting Flutter ---
  app.get('/api/health', async (_req, res) => {
    try {
      const redisOk = await pingRedis()
      const serial = getSerialStatus()
      res.json({
        status: 'healthy',
        server: 'desktop',
        redis: redisOk ? 'connected' : 'disconnected',
        serial: serial.connected ? 'connected' : 'disconnected',
        serial_port: serial.port || null,
        timestamp: new Date().toISOString()
      })
    } catch (err) {
      res.status(500).json({ status: 'unhealthy', error: (err as Error).message })
    }
  })

  // --- Data sensor terkini dari cache Redis (fallback saat baru reconnect) ---
  app.get('/api/current', async (_req, res) => {
    try {
      const data = await getLatestCachedData()
      if (data) {
        res.json(data)
      } else {
        res.status(404).json({ error: 'Belum ada data tersimpan di cache' })
      }
    } catch (err) {
      res.status(500).json({ error: (err as Error).message })
    }
  })

  // --- REST API untuk Request History ---
  app.get('/api/history', async (req, res) => {
    try {
      const limit = parseInt(req.query.limit as string) || 50
      const startDate = req.query.start_date as string | undefined
      const endDate = req.query.end_date as string | undefined

      let logs: unknown[]
      if (startDate && endDate) {
        logs = await getLogsByDateRange(startDate, endDate)
      } else {
        logs = await getLatestLogs(limit)
      }

      res.json({
        status: 'success',
        count: logs.length,
        data: logs
      })
    } catch (err) {
      console.error('❌ [API] Gagal fetch history:', err)
      res.status(500).json({
        status: 'error',
        message: 'Internal server error saat mengambil data dari database',
        data: []
      })
    }
  })

  // --- Inisialisasi Socket.IO Server ---
  httpServer = createServer(app)
  io = new Server(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      credentials: true
    }
  })

  io.on('connection', (socket) => {
    console.log(`🔌 [Socket.IO] Klien terhubung: ${socket.id}`)

    // Kirim data terakhir dari cache Redis begitu client connect
    getLatestCachedData()
      .then((data) => {
        if (data) socket.emit('sensor/realtime', data)
      })
      .catch(() => {
        /* cache belum tersedia, biarkan menunggu data pertama dari serial */
      })

    // Mendengarkan perintah aktuator dari Flutter
    socket.on('actuator/command', (payload: { command: string }) => {
      console.log(`📥 [Socket.IO] Perintah aktuator diterima:`, payload)
      if (payload && payload.command) {
        const result = sendCommand(payload.command)
        console.log(`🔧 [Socket.IO] Perintah "${payload.command}" => ${result.message}`)
      }
    })

    socket.on('disconnect', () => {
      console.log(`⚠️ [Socket.IO] Klien terputus: ${socket.id}`)
    })
  })

  httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 [Server] Express & Socket.IO berjalan di http://0.0.0.0:${PORT}`)
  })
}

/** Publish data sensor realtime melalui Socket.IO + simpan ke cache Redis (1 jam). */
export function publishSensorData(data: Record<string, number>): void {
  const normalized = normalizeSensorPayload(data)

  // Cache ke Redis (fire-and-forget — tidak menunda broadcast Socket.IO)
  cacheSensorData(normalized).catch((err) => console.error('[Redis] Gagal cache data sensor:', err))

  if (io) {
    io.emit('sensor/realtime', normalized)
  }
}

export function closeServer(): void {
  if (io) {
    io.close()
    console.log('[Socket.IO] Server ditutup')
  }
  if (httpServer) {
    httpServer.close()
    console.log('[Express] Server ditutup')
  }
}
