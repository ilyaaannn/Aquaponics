/**
 * useSerial — Composable for serial port communication
 * Manages connection state, port listing, and command sending.
 */

import { ref, onMounted, onUnmounted } from 'vue'

export interface PortInfo {
  path: string
  manufacturer?: string
  serialNumber?: string
  vendorId?: string
  productId?: string
}

// ── Singleton connection state, shared across every useSerial() caller ──
const isConnected = ref(false)
const currentPort = ref('')
const lastError = ref('')

// ── Reference-counted IPC listener registration ──
let listenerRefCount = 0
let unsubscribeStatusChange: (() => void) | null = null
let unsubscribeError: (() => void) | null = null

function acquireListeners(): void {
  listenerRefCount++
  if (listenerRefCount === 1) {
    unsubscribeStatusChange = window.api.serial.onStatusChange((status) => {
      isConnected.value = status.connected
      currentPort.value = status.port
    })
    unsubscribeError = window.api.serial.onError((error) => {
      lastError.value = error.message
    })
  }
}

function releaseListeners(): void {
  listenerRefCount = Math.max(0, listenerRefCount - 1)
  if (listenerRefCount === 0) {
    unsubscribeStatusChange?.()
    unsubscribeError?.()
    unsubscribeStatusChange = null
    unsubscribeError = null
  }
}

export function useSerial() {
  const availablePorts = ref<PortInfo[]>([])
  const isScanning = ref(false)
  const isConnecting = ref(false)

  /** Scan for available serial ports */
  async function scanPorts(): Promise<void> {
    isScanning.value = true
    lastError.value = ''
    try {
      availablePorts.value = await window.api.serial.listPorts()
    } catch (err: unknown) {
      lastError.value = err instanceof Error ? err.message : 'Failed to scan ports'
    } finally {
      isScanning.value = false
    }
  }

  /** Connect to a port */
  async function connect(portPath: string, baudRate: number = 115200): Promise<boolean> {
    isConnecting.value = true
    lastError.value = ''
    try {
      const result = await window.api.serial.connect(portPath, baudRate)
      if (result.success) {
        isConnected.value = true
        currentPort.value = portPath
      } else {
        lastError.value = result.message
      }
      return result.success
    } catch (err: unknown) {
      lastError.value = err instanceof Error ? err.message : 'Connection failed'
      return false
    } finally {
      isConnecting.value = false
    }
  }

  /** Disconnect from the current port */
  async function disconnect(): Promise<void> {
    try {
      await window.api.serial.disconnect()
      isConnected.value = false
      currentPort.value = ''
    } catch (err: unknown) {
      lastError.value = err instanceof Error ? err.message : 'Disconnect failed'
    }
  }

  /** Send a command to the microcontroller */
  async function sendCommand(command: string): Promise<boolean> {
    try {
      const result = await window.api.serial.sendCommand(command)
      if (!result.success) {
        lastError.value = result.message
      }
      return result.success
    } catch (err: unknown) {
      lastError.value = err instanceof Error ? err.message : 'Command failed'
      return false
    }
  }

  onMounted(async () => {
    acquireListeners()
    // Check current status on mount
    try {
      const status = await window.api.serial.getStatus()
      isConnected.value = status.connected
      currentPort.value = status.port
    } catch {
      // Ignore - status check failed
    }
  })

  onUnmounted(() => {
    releaseListeners()
  })

  return {
    isConnected,
    currentPort,
    availablePorts,
    isScanning,
    isConnecting,
    lastError,
    scanPorts,
    connect,
    disconnect,
    sendCommand
  }
}