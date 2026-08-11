/**
 * Aquaphonik Desktop — Main Process Entry
 * Electron main process that creates the window and registers all IPC handlers
 * for serial port communication and database operations.
 */

import { app, shell, BrowserWindow, ipcMain, dialog } from 'electron'
import { join } from 'path'
import ExcelJS from 'exceljs'
import { networkInterfaces } from 'os'
import { electronApp, optimizer, is } from '@electron-toolkit/utils'
import icon from '../../resources/icon.png?asset'

// Main process modules
import {
  listPorts,
  connectPort,
  disconnectPort,
  sendCommand,
  getStatus,
  onData as onSerialData,
  cleanup as serialCleanup
} from './serial'
import {
  initDatabase,
  insertSensorLog,
  getLatestLogs,
  getLogsByDateRange,
  getLogCount,
  deleteOldLogs,
  closeDatabase
} from './database'
// Server: Modul komunikasi REST API dan Socket.IO dengan Flutter Mobile
import { initServer, publishSensorData, closeServer } from './express-api'

// --- Data Logging Interval ---
// We receive data every ~2 seconds from the MCU, but we only save to DB
// at a configurable interval to prevent database bloat.
let logIntervalMinutes = 1 // Default: save every 1 minute
let lastLogTimestamp = 0

function createWindow(): void {
  const mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 800,
    minHeight: 500,
    show: false,
    autoHideMenuBar: true,
    title: 'AquaPhonik Desktop',
    // Untuk Linux (Raspberry Pi), jalankan dalam mode fullscreen secara default
    ...(process.platform === 'linux' ? { icon, fullscreen: true, kiosk: true } : {}),
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false
    }
  })

  mainWindow.on('ready-to-show', () => {
    if (process.platform === 'linux') {
      mainWindow.maximize()
    }
    mainWindow.show()
  })

  mainWindow.webContents.setWindowOpenHandler((details) => {
    shell.openExternal(details.url)
    return { action: 'deny' }
  })

  // HMR for renderer based on electron-vite cli.
  if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
    mainWindow.loadURL(process.env['ELECTRON_RENDERER_URL'])
  } else {
    mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }
}

// =====================================================
// Register IPC Handlers
// =====================================================
function registerIpcHandlers(): void {
  // --- Serial Port Handlers ---

  /**
   * Scan available COM/Serial ports
   */
  ipcMain.handle('serial:list-ports', async () => {
    return await listPorts()
  })

  /**
   * Connect to a serial port
   */
  ipcMain.handle('serial:connect', async (_event, portPath: string, baudRate?: number) => {
    return await connectPort(portPath, baudRate)
  })

  /**
   * Disconnect from the serial port
   */
  ipcMain.handle('serial:disconnect', async () => {
    return await disconnectPort()
  })

  /**
   * Send a command to the microcontroller
   */
  ipcMain.handle('serial:send-command', (_event, command: string) => {
    return sendCommand(command)
  })

  /**
   * Get current serial connection status
   */
  ipcMain.handle('serial:get-status', () => {
    return getStatus()
  })

  // --- Database Handlers ---

  /**
   * Get latest sensor logs
   */
  ipcMain.handle('db:get-latest-logs', (_event, limit?: number) => {
    return getLatestLogs(limit)
  })

  /**
   * Get logs by date range
   */
  ipcMain.handle('db:get-logs-by-date', (_event, startDate: string, endDate: string) => {
    return getLogsByDateRange(startDate, endDate)
  })

  /**
   * Get total log count
   */
  ipcMain.handle('db:get-log-count', () => {
    return getLogCount()
  })

  /**
   * Delete old logs
   */
  ipcMain.handle('db:delete-old-logs', (_event, daysToKeep?: number) => {
    return deleteOldLogs(daysToKeep)
  })

  // --- Settings Handlers ---

  /**
   * Set the log interval (in minutes)
   */
  ipcMain.handle('settings:set-log-interval', (_event, minutes: number) => {
    logIntervalMinutes = Math.max(1, minutes)
    return { success: true, interval: logIntervalMinutes }
  })

  /**
   * Get current log interval
   */
  ipcMain.handle('settings:get-log-interval', () => {
    return { interval: logIntervalMinutes }
  })

  // --- System Handlers ---

  /**
   * Get the current WiFi/LAN IP address
   * Prioritizes wlan0 (Raspberry Pi WiFi), then eth0, then any non-internal IPv4
   */
  ipcMain.handle('system:get-network-ip', () => {
    const nets = networkInterfaces()
    // Priority order for interface names
    const priorityInterfaces = ['wlan0', 'wlan1', 'Wi-Fi', 'eth0', 'en0', 'Ethernet']

    // First, try priority interfaces
    for (const name of priorityInterfaces) {
      const iface = nets[name]
      if (iface) {
        for (const net of iface) {
          if (net.family === 'IPv4' && !net.internal) {
            return { ip: net.address, iface: name }
          }
        }
      }
    }

    // Fallback: any non-internal IPv4
    for (const [name, iface] of Object.entries(nets)) {
      if (iface) {
        for (const net of iface) {
          if (net.family === 'IPv4' && !net.internal) {
            return { ip: net.address, iface: name }
          }
        }
      }
    }

    return { ip: null, iface: null }
  })

  // --- Window Controls Handlers ---

  ipcMain.handle('window:minimize', () => {
    const win = BrowserWindow.getFocusedWindow()
    if (win) win.minimize()
  })

  ipcMain.handle('window:close', () => {
    app.quit()
  })

  // --- Export Handlers ---

  /**
   * Export sensor data to Excel (.xlsx) file
   * Receives data array and date range info, creates styled workbook,
   * prompts user for save location via native dialog.
   */
  ipcMain.handle(
    'export:excel',
    async (
      _event,
      data: Array<Record<string, number | string>>,
      dateRange: { start: string; end: string }
    ) => {
      if (!data || data.length === 0) {
        return { success: false, message: 'Tidak ada data untuk diekspor' }
      }

      // Show save dialog
      const defaultName = `AquaPhonik_Data_${dateRange.start}_to_${dateRange.end}.xlsx`
      
      const result = await dialog.showSaveDialog({
        title: 'Simpan Data Sensor ke Excel',
        defaultPath: defaultName,
        filters: [
          { name: 'Excel Files', extensions: ['xlsx'] },
          { name: 'All Files', extensions: ['*'] }
        ]
      })

      if (result.canceled || !result.filePath) {
        return { success: false, message: 'Export dibatalkan' }
      }

      try {
        const workbook = new ExcelJS.Workbook()
        workbook.creator = 'AquaPhonik Desktop'
        workbook.created = new Date()

        const worksheet = workbook.addWorksheet('Sensor Data', {
          properties: { defaultRowHeight: 22 }
        })

        // Define columns
        worksheet.columns = [
          { header: 'No', key: 'no', width: 6 },
          { header: 'Waktu', key: 'timestamp', width: 22 },
          { header: 'Suhu Air (°C)', key: 'temp_water', width: 15 },
          { header: 'pH', key: 'ph', width: 10 },
          { header: 'TDS (ppm)', key: 'tds', width: 12 },
          { header: 'DO (mg/L)', key: 'do_value', width: 12 },
          { header: 'Turbidity', key: 'turbidity', width: 12 },
          { header: 'Water Level', key: 'water_lvl', width: 13 },
          { header: 'CO2 (ppm)', key: 'co2', width: 12 },
          { header: 'eCO2 (ppm)', key: 'eco2', width: 12 },
          { header: 'TVOC (ppb)', key: 'tvoc', width: 12 },
          { header: 'Suhu Udara (°C)', key: 'temp_air', width: 16 },
          { header: 'Kelembapan (%)', key: 'humidity', width: 15 },
          { header: 'Pompa', key: 'pump_status', width: 10 },
          { header: 'Oksigen', key: 'oxy_status', width: 10 }
        ]

        // Style header row
        const headerRow = worksheet.getRow(1)
        headerRow.height = 28
        headerRow.eachCell((cell) => {
          cell.font = {
            bold: true,
            color: { argb: 'FFFFFFFF' },
            size: 11,
            name: 'Calibri'
          }
          cell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FF0D7377' } // Dark teal (AquaPhonik theme)
          }
          cell.alignment = {
            horizontal: 'center',
            vertical: 'middle',
            wrapText: true
          }
          cell.border = {
            top: { style: 'thin', color: { argb: 'FF0A5C5F' } },
            bottom: { style: 'thin', color: { argb: 'FF0A5C5F' } },
            left: { style: 'thin', color: { argb: 'FF0A5C5F' } },
            right: { style: 'thin', color: { argb: 'FF0A5C5F' } }
          }
        })

        // Add data rows
        data.forEach((row, index) => {
          const formattedTime = new Date(row.timestamp as string).toLocaleString('id-ID', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
          })

          const dataRow = worksheet.addRow({
            no: index + 1,
            timestamp: formattedTime,
            temp_water: Number(row.temp_water || 0),
            ph: Number(row.ph || 0),
            tds: Number(row.tds || 0),
            do_value: Number(row.do_value || 0),
            turbidity: Number(row.turbidity || 0),
            water_lvl: Number(row.water_lvl || 0),
            co2: Number(row.co2 || 0),
            eco2: Number(row.eco2 || 0),
            tvoc: Number(row.tvoc || 0),
            temp_air: Number(row.temp_air || 0),
            humidity: Number(row.humidity || 0),
            pump_status: Number(row.pump_status) === 1 ? 'ON' : 'OFF',
            oxy_status: Number(row.oxy_status) === 1 ? 'ON' : 'OFF'
          })

          // Alternate row coloring
          const bgColor = index % 2 === 0 ? 'FFF0FAFA' : 'FFFFFFFF'
          dataRow.eachCell((cell) => {
            cell.fill = {
              type: 'pattern',
              pattern: 'solid',
              fgColor: { argb: bgColor }
            }
            cell.border = {
              top: { style: 'thin', color: { argb: 'FFD0D0D0' } },
              bottom: { style: 'thin', color: { argb: 'FFD0D0D0' } },
              left: { style: 'thin', color: { argb: 'FFD0D0D0' } },
              right: { style: 'thin', color: { argb: 'FFD0D0D0' } }
            }
            cell.alignment = { horizontal: 'center', vertical: 'middle' }
            cell.font = { size: 10, name: 'Calibri' }
          })
        })

        // Add summary info row at the bottom
        const emptyRow = worksheet.addRow([])
        emptyRow.height = 10

        const summaryRow = worksheet.addRow([
          '',
          `Exported: ${new Date().toLocaleString('id-ID')}`,
          '',
          '',
          `Period: ${dateRange.start} s/d ${dateRange.end}`,
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          `Total: ${data.length} records`
        ])
        summaryRow.eachCell((cell) => {
          cell.font = { italic: true, size: 9, color: { argb: 'FF888888' }, name: 'Calibri' }
        })

        // Freeze header row
        worksheet.views = [{ state: 'frozen', ySplit: 1 }]

        // Auto-filter on header
        worksheet.autoFilter = {
          from: { row: 1, column: 1 },
          to: { row: 1, column: 15 }
        }

        // Write file
        await workbook.xlsx.writeFile(result.filePath)

        console.log(`[Export] Excel saved to: ${result.filePath}`)
        return {
          success: true,
          message: `Berhasil menyimpan ${data.length} data ke Excel`,
          filePath: result.filePath
        }
      } catch (error) {
        console.error('[Export] Excel error:', error)
        return {
          success: false,
          message: `Gagal menyimpan: ${(error as Error).message}`
        }
      }
    }
  )

  // --- Register serial data callback for conditional DB logging + MQTT publish ---
  onSerialData((data) => {
    const now = Date.now()
    const intervalMs = logIntervalMinutes * 60 * 1000

    // Socket.IO: Publish data sensor realtime ke Flutter setiap kali data masuk
    publishSensorData(data)

    // Database: Simpan ke PostgreSQL hanya sesuai interval yang dikonfigurasi
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
      })
      lastLogTimestamp = now
    }
  })
}

// =====================================================
// App Lifecycle
// =====================================================
app.whenReady().then(async () => {
  electronApp.setAppUserModelId('com.aquaphonik.desktop')

  // DevTools shortcut
  app.on('browser-window-created', (_, window) => {
    optimizer.watchWindowShortcuts(window)
  })

  // Initialize database — MUST await so pool is ready before IPC handlers and window
  await initDatabase()

  // Initialize Server (Express + Socket.IO) untuk komunikasi dengan Flutter
  initServer()

  // Register all IPC handlers
  registerIpcHandlers()

  // Create the main window
  createWindow()

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

// Cleanup on quit
app.on('before-quit', () => {
  serialCleanup()
  closeServer()
  closeDatabase()
})
