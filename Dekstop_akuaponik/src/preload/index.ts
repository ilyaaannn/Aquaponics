/**
 * Aquaphonik Desktop — Preload Script
 * Securely exposes Electron IPC APIs to the Vue renderer process
 * via contextBridge.
 */

import { contextBridge, ipcRenderer } from 'electron'
import { electronAPI } from '@electron-toolkit/preload'

// Custom API for the Aquaphonik app
const aquaphonikAPI = {
  // ---- Serial Port ----
  serial: {
    /** Scan available serial/COM ports */
    listPorts: (): Promise<
      Array<{
        path: string
        manufacturer?: string
        serialNumber?: string
        vendorId?: string
        productId?: string
      }>
    > => ipcRenderer.invoke('serial:list-ports'),

    /** Connect to a specific serial port */
    connect: (
      portPath: string,
      baudRate?: number
    ): Promise<{ success: boolean; message: string }> =>
      ipcRenderer.invoke('serial:connect', portPath, baudRate),

    /** Disconnect from the current serial port */
    disconnect: (): Promise<{ success: boolean; message: string }> =>
      ipcRenderer.invoke('serial:disconnect'),

    /** Send a control command to the microcontroller */
    sendCommand: (command: string): Promise<{ success: boolean; message: string }> =>
      ipcRenderer.invoke('serial:send-command', command),

    /** Get current connection status */
    getStatus: (): Promise<{ connected: boolean; port: string }> =>
      ipcRenderer.invoke('serial:get-status'),

    /** Listen for incoming sensor data from serial */
    onData: (callback: (data: Record<string, number>) => void): void => {
      ipcRenderer.on('serial:data', (_event, data) => callback(data))
    },

    /** Listen for serial status changes */
    onStatusChange: (callback: (status: { connected: boolean; port: string }) => void): void => {
      ipcRenderer.on('serial:status', (_event, status) => callback(status))
    },

    /** Listen for serial errors */
    onError: (callback: (error: { message: string }) => void): void => {
      ipcRenderer.on('serial:error', (_event, error) => callback(error))
    },

    /** Remove all serial listeners */
    removeAllListeners: (): void => {
      ipcRenderer.removeAllListeners('serial:data')
      ipcRenderer.removeAllListeners('serial:status')
      ipcRenderer.removeAllListeners('serial:error')
    }
  },

  // ---- Database ----
  database: {
    /** Get latest sensor logs */
    getLatestLogs: (
      limit?: number
    ): Promise<
      Array<{
        id: number
        timestamp: string
        temp_water: number
        ph: number
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
      }>
    > => ipcRenderer.invoke('db:get-latest-logs', limit),

    /** Get logs by date range */
    getLogsByDateRange: (
      startDate: string,
      endDate: string
    ): Promise<Array<Record<string, number | string>>> =>
      ipcRenderer.invoke('db:get-logs-by-date', startDate, endDate),

    /** Get total number of log entries */
    getLogCount: (): Promise<number> => ipcRenderer.invoke('db:get-log-count'),

    /** Delete logs older than N days */
    deleteOldLogs: (daysToKeep?: number): Promise<number> =>
      ipcRenderer.invoke('db:delete-old-logs', daysToKeep)
  },

  // ---- Settings ----
  settings: {
    /** Set the database log interval in minutes */
    setLogInterval: (minutes: number): Promise<{ success: boolean; interval: number }> =>
      ipcRenderer.invoke('settings:set-log-interval', minutes),

    /** Get the current log interval */
    getLogInterval: (): Promise<{ interval: number }> =>
      ipcRenderer.invoke('settings:get-log-interval')
  },

  // ---- System ----
  system: {
    /** Get the current WiFi/LAN IP address */
    getNetworkIP: (): Promise<{ ip: string | null; iface: string | null }> =>
      ipcRenderer.invoke('system:get-network-ip')
  },

  // ---- Window ----
  windowControls: {
    /** Minimize the application window */
    minimize: (): Promise<void> => ipcRenderer.invoke('window:minimize'),

    /** Close the application */
    close: (): Promise<void> => ipcRenderer.invoke('window:close')
  },

  // ---- Export ----
  export: {
    /** Export sensor data to Excel file */
    toExcel: (
      data: Array<Record<string, number | string>>,
      dateRange: { start: string; end: string }
    ): Promise<{ success: boolean; message: string; filePath?: string }> =>
      ipcRenderer.invoke('export:excel', data, dateRange)
  }
}

// Expose APIs securely via contextBridge
if (process.contextIsolated) {
  try {
    contextBridge.exposeInMainWorld('electron', electronAPI)
    contextBridge.exposeInMainWorld('api', aquaphonikAPI)
  } catch (error) {
    console.error(error)
  }
} else {
  // @ts-ignore (define in dts)
  window.electron = electronAPI
  // @ts-ignore (define in dts)
  window.api = aquaphonikAPI
}
