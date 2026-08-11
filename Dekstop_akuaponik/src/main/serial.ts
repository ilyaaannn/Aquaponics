/**
 * Serial Port Manager — Aquaphonik Desktop
 * Handles scanning, connecting, reading, and writing to serial ports.
 * Communicates with Vue renderer via IPC through the main process.
 */

import { SerialPort } from 'serialport'
import { ReadlineParser } from '@serialport/parser-readline'
import { BrowserWindow } from 'electron'

let port: SerialPort | null = null
let parser: ReadlineParser | null = null
let dataCallback: ((data: Record<string, number>) => void) | null = null

/**
 * Register a callback to receive parsed sensor data (used by main process for DB logging)
 */
export function onData(callback: (data: Record<string, number>) => void): void {
  dataCallback = callback
}

export interface SerialPortInfo {
  path: string
  manufacturer?: string
  serialNumber?: string
  pnpId?: string
  vendorId?: string
  productId?: string
}

/**
 * Scan all available COM/Serial ports
 */
export async function listPorts(): Promise<SerialPortInfo[]> {
  try {
    const ports = await SerialPort.list()
    return ports.map((p) => ({
      path: p.path,
      manufacturer: p.manufacturer,
      serialNumber: p.serialNumber,
      pnpId: p.pnpId,
      vendorId: p.vendorId,
      productId: p.productId
    }))
  } catch (error) {
    console.error('[Serial] Error listing ports:', error)
    return []
  }
}

/**
 * Connect to a specific serial port
 */
export function connectPort(
  portPath: string,
  baudRate: number = 115200
): Promise<{ success: boolean; message: string }> {
  return new Promise((resolve) => {
    // Disconnect existing port first
    if (port && port.isOpen) {
      port.close()
      port = null
      parser = null
    }

    try {
      port = new SerialPort({
        path: portPath,
        baudRate: baudRate,
        autoOpen: false
      })

      // Create readline parser (JSON comes line by line from ESP32)
      parser = new ReadlineParser({ delimiter: '\n' })
      port.pipe(parser)

      // Listen for parsed data (each line = one JSON payload)
      parser.on('data', (rawLine: string) => {
        handleSerialData(rawLine.trim())
      })

      // Handle port errors
      port.on('error', (err) => {
        console.error('[Serial] Port error:', err.message)
        sendToRenderer('serial:error', { message: err.message })
      })

      // Handle port close
      port.on('close', () => {
        console.log('[Serial] Port closed')
        sendToRenderer('serial:status', { connected: false, port: '' })
      })

      // Open the port
      port.open((err) => {
        if (err) {
          console.error('[Serial] Failed to open port:', err.message)
          resolve({ success: false, message: err.message })
        } else {
          console.log(`[Serial] Connected to ${portPath} @ ${baudRate} baud`)
          sendToRenderer('serial:status', { connected: true, port: portPath })
          resolve({ success: true, message: `Connected to ${portPath}` })
        }
      })
    } catch (error: unknown) {
      const errMsg = error instanceof Error ? error.message : 'Unknown error'
      console.error('[Serial] Connection error:', errMsg)
      resolve({ success: false, message: errMsg })
    }
  })
}

/**
 * Disconnect from the current serial port
 */
export function disconnectPort(): Promise<{ success: boolean; message: string }> {
  return new Promise((resolve) => {
    if (port && port.isOpen) {
      port.close((err) => {
        if (err) {
          resolve({ success: false, message: err.message })
        } else {
          port = null
          parser = null
          resolve({ success: true, message: 'Disconnected' })
        }
      })
    } else {
      resolve({ success: true, message: 'Already disconnected' })
    }
  })
}

/**
 * Send a command string to the microcontroller
 * Examples: "POMPA:1", "POMPA:0", "OKSIGEN:1", "OKSIGEN:0"
 */
export function sendCommand(command: string): { success: boolean; message: string } {
  if (!port || !port.isOpen) {
    return { success: false, message: 'Serial port not connected' }
  }

  try {
    port.write(command + '\n', (err) => {
      if (err) {
        console.error('[Serial] Write error:', err.message)
        sendToRenderer('serial:error', { message: `Write failed: ${err.message}` })
      } else {
        console.log(`[Serial] Sent command: ${command}`)
      }
    })
    return { success: true, message: `Command sent: ${command}` }
  } catch (error: unknown) {
    const errMsg = error instanceof Error ? error.message : 'Unknown error'
    return { success: false, message: errMsg }
  }
}

/**
 * Get current connection status
 */
export function getStatus(): { connected: boolean; port: string } {
  return {
    connected: port !== null && port.isOpen,
    port: port?.path || ''
  }
}

/**
 * Handle incoming serial data — parse JSON and forward to renderer
 */
function handleSerialData(rawLine: string): void {
  // Skip empty lines or debug messages
  if (!rawLine || !rawLine.startsWith('{')) {
    return
  }

  try {
    const data = JSON.parse(rawLine)
    // Forward parsed sensor data to the renderer
    sendToRenderer('serial:data', data)
    // Also forward to the registered callback (for database logging)
    if (dataCallback) {
      dataCallback(data)
    }
  } catch {
    // Not valid JSON — could be debug output from MCU, ignore silently
    console.log('[Serial] Non-JSON data:', rawLine.substring(0, 80))
  }
}

/**
 * Send data to the renderer process via IPC
 */
function sendToRenderer(channel: string, data: unknown): void {
  const windows = BrowserWindow.getAllWindows()
  windows.forEach((win) => {
    if (!win.isDestroyed()) {
      win.webContents.send(channel, data)
    }
  })
}

/**
 * Cleanup on app quit
 */
export function cleanup(): void {
  if (port && port.isOpen) {
    port.close()
  }
  port = null
  parser = null
}
