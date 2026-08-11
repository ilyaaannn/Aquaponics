import { ElectronAPI } from '@electron-toolkit/preload'

interface SerialAPI {
  listPorts: () => Promise<
    Array<{
      path: string
      manufacturer?: string
      serialNumber?: string
      vendorId?: string
      productId?: string
    }>
  >
  connect: (portPath: string, baudRate?: number) => Promise<{ success: boolean; message: string }>
  disconnect: () => Promise<{ success: boolean; message: string }>
  sendCommand: (command: string) => Promise<{ success: boolean; message: string }>
  getStatus: () => Promise<{ connected: boolean; port: string }>
  onData: (callback: (data: Record<string, number>) => void) => void
  onStatusChange: (callback: (status: { connected: boolean; port: string }) => void) => void
  onError: (callback: (error: { message: string }) => void) => void
  removeAllListeners: () => void
}

interface DatabaseAPI {
  getLatestLogs: (limit?: number) => Promise<Array<Record<string, number | string>>>
  getLogsByDateRange: (
    startDate: string,
    endDate: string
  ) => Promise<Array<Record<string, number | string>>>
  getLogCount: () => Promise<number>
  deleteOldLogs: (daysToKeep?: number) => Promise<number>
}

interface SettingsAPI {
  setLogInterval: (minutes: number) => Promise<{ success: boolean; interval: number }>
  getLogInterval: () => Promise<{ interval: number }>
}

interface SystemAPI {
  getNetworkIP: () => Promise<{ ip: string | null; iface: string | null }>
}

interface WindowControlsAPI {
  minimize: () => Promise<void>
  close: () => Promise<void>
}

interface ExportAPI {
  toExcel: (
    data: Array<Record<string, number | string>>,
    dateRange: { start: string; end: string }
  ) => Promise<{ success: boolean; message: string; filePath?: string }>
}

interface AquaphonikAPI {
  serial: SerialAPI
  database: DatabaseAPI
  settings: SettingsAPI
  system: SystemAPI
  export: ExportAPI
  windowControls: WindowControlsAPI
}

declare global {
  interface Window {
    electron: ElectronAPI
    api: AquaphonikAPI
  }
}
