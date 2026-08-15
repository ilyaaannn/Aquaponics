/**
 * Power Manager — Aquaphonik Desktop
 * Mengelola fitur ON/OFF TAMPILAN aplikasi desktop TANPA menghentikan proses
 * di baliknya (pembacaan serial, kalibrasi, logging ke PostgreSQL, server
 * Express/Socket.IO untuk aplikasi mobile).
 */

import { BrowserWindow, Tray, Menu, globalShortcut, nativeImage, app } from 'electron'
import { createServer, Server as HttpServer } from 'http'
import icon from '../../resources/icon.png?asset'

const LOCAL_CONTROL_PORT = 8090
const LOCAL_CONTROL_HOST = '127.0.0.1'
const WAKE_SHORTCUT = 'Control+Alt+P'

let tray: Tray | null = null
let controlServer: HttpServer | null = null
let getWindow: (() => BrowserWindow | null) | null = null

/**Apakah tampilan aplikasi sedang terlihat (ON) saat ini. */
export function isAppVisible(): boolean {
  const win = getWindow?.()
  return !!win && !win.isDestroyed() && win.isVisible()
}

/**Tampilkan kembali window aplikasi (ON). */
export function showApp(): void {
  const win = getWindow?.()
  if (win && !win.isDestroyed()) {
    win.show()
    win.focus()
    console.log('[PowerManager] Aplikasi ditampilkan (ON)')
  }
  updateTrayMenu()
}

/**
 * Sembunyikan window aplikasi (OFF). Proses main process TIDAK dihentikan.
 */
export function hideApp(): void {
  const win = getWindow?.()
  if (win && !win.isDestroyed()) {
    win.hide()
    console.log('[PowerManager] Aplikasi disembunyikan (OFF) — proses background tetap berjalan')
  }
  updateTrayMenu()
}

export function toggleApp(): void {
  if (isAppVisible()) hideApp()
  else showApp()
}

function updateTrayMenu(): void {
  if (!tray || tray.isDestroyed()) return
  const visible = isAppVisible()

  const menu = Menu.buildFromTemplate([
    {
      label: visible ? 'Sembunyikan Tampilan (OFF)' : 'Tampilkan Aplikasi (ON)',
      click: toggleApp
    },
    { type: 'separator' },
    {
      label: 'Keluar Sepenuhnya (hentikan semua proses)',
      click: () => app.quit()
    }
  ])

  tray.setContextMenu(menu)
  tray.setToolTip(
    `AquaPhonik Desktop — ${visible ? 'Aktif' : 'Standby (proses background tetap berjalan)'}`
  )
}

/**
 * Inisialisasi Power Manager: tray icon, global shortcut, local control server.
 * Dipanggil SEKALI dari index.ts setelah window utama dibuat.
 */
export function initPowerManager(windowGetter: () => BrowserWindow | null): void {
  getWindow = windowGetter

  // --- Tray Icon ---
  try {
    tray = new Tray(nativeImage.createFromPath(icon))
    tray.setToolTip('AquaPhonik Desktop')
    tray.on('click', toggleApp)
    updateTrayMenu()
  } catch (err) {
    console.error('[PowerManager] Gagal membuat tray icon:', err)
  }

  // --- Global Keyboard Shortcut (jalur cadangan jika tray tidak tersedia) ---
  try {
    const registered = globalShortcut.register(WAKE_SHORTCUT, toggleApp)
    if (!registered) {
      console.error(`[PowerManager] Shortcut ${WAKE_SHORTCUT} gagal didaftarkan (mungkin bentrok)`)
    }
  } catch (err) {
    console.error('[PowerManager] Gagal mendaftarkan global shortcut:', err)
  }

  // --- Local Control Server (dipakai oleh scripts/gpio-switch/) ---
  controlServer = createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json')

    if (req.method === 'GET' && req.url === '/power/status') {
      res.writeHead(200)
      res.end(JSON.stringify({ visible: isAppVisible() }))
      return
    }

    if (req.method === 'POST' && req.url === '/power/on') {
      showApp()
      res.writeHead(200)
      res.end(JSON.stringify({ success: true, visible: true }))
      return
    }

    if (req.method === 'POST' && req.url === '/power/off') {
      hideApp()
      res.writeHead(200)
      res.end(JSON.stringify({ success: true, visible: false }))
      return
    }

    if (req.method === 'POST' && req.url === '/power/toggle') {
      toggleApp()
      res.writeHead(200)
      res.end(JSON.stringify({ success: true, visible: isAppVisible() }))
      return
    }

    res.writeHead(404)
    res.end(JSON.stringify({ error: 'Not found' }))
  })

  controlServer.on('error', (err) => {
    console.error('[PowerManager] Local control server error:', err)
  })

  controlServer.listen(LOCAL_CONTROL_PORT, LOCAL_CONTROL_HOST, () => {
    console.log(
      `[PowerManager] Local control API aktif di http://${LOCAL_CONTROL_HOST}:${LOCAL_CONTROL_PORT} (khusus lokal, tidak bisa diakses dari HP/jaringan luar)`
    )
  })
}

/**
 * Cleanup saat aplikasi BENAR-BENAR keluar (app.quit() lewat tombol Exit),
 * bukan saat OFF/hide biasa.
 */
export function cleanupPowerManager(): void {
  globalShortcut.unregisterAll()

  if (controlServer) {
    controlServer.close()
    controlServer = null
  }

  if (tray && !tray.isDestroyed()) {
    tray.destroy()
    tray = null
  }
}