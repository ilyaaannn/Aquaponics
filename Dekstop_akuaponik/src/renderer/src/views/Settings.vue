<script setup lang="ts">
/**
 * Settings View — Configure serial port, database log interval,
 * and data retention policies.
 * Theme: Futuristic Glassmorphism
 */
import { ref, onMounted, watch } from 'vue'
import { useSerial } from '../composables/useSerial'

// Serial setup
const {
  isConnected,
  currentPort,
  availablePorts,
  isScanning,
  isConnecting,
  lastError,
  scanPorts,
  connect,
  disconnect
} = useSerial()

const selectedPort = ref('')
const selectedBaudRate = ref(115200)
const baudRates = [9600, 19200, 38400, 57600, 115200, 230400]

// Auto-scan ports on mount
scanPorts()

// Watch for available ports to auto-select and auto-connect
watch(availablePorts, async (ports) => {
  if (ports.length > 0 && !selectedPort.value && !isConnected.value && !isConnecting.value) {
    selectedPort.value = ports[0].path
    // Auto connect using the selected default baud rate
    await connect(selectedPort.value, selectedBaudRate.value)
  }
})

async function handleConnect(): Promise<void> {
  if (isConnected.value) {
    await disconnect()
  } else if (selectedPort.value) {
    await connect(selectedPort.value, selectedBaudRate.value)
  }
}

async function handleScan(): Promise<void> {
  await scanPorts()
}

const logInterval = ref(1)
const retentionDays = ref(30)
const isSaving = ref(false)
const saveMessage = ref('')
const logCount = ref(0)
const isDeleting = ref(false)
const deleteMessage = ref('')

async function loadSettings(): Promise<void> {
  try {
    const result = await window.api.settings.getLogInterval()
    logInterval.value = result.interval
    logCount.value = await window.api.database.getLogCount()
  } catch (err) {
    console.error('Failed to load settings:', err)
  }
}

async function saveLogInterval(): Promise<void> {
  isSaving.value = true
  saveMessage.value = ''
  try {
    const result = await window.api.settings.setLogInterval(logInterval.value)
    if (result.success) {
      saveMessage.value = `✓ Interval disimpan: setiap ${result.interval} menit`
    }
  } catch (err) {
    saveMessage.value = '✗ Gagal menyimpan pengaturan'
  } finally {
    isSaving.value = false
    setTimeout(() => {
      saveMessage.value = ''
    }, 3000)
  }
}

async function cleanupOldData(): Promise<void> {
  isDeleting.value = true
  deleteMessage.value = ''
  try {
    const deleted = await window.api.database.deleteOldLogs(retentionDays.value)
    deleteMessage.value = `✓ ${deleted} record dihapus`
    logCount.value = await window.api.database.getLogCount()
  } catch (err) {
    deleteMessage.value = '✗ Gagal menghapus data'
  } finally {
    isDeleting.value = false
    setTimeout(() => {
      deleteMessage.value = ''
    }, 3000)
  }
}

onMounted(() => {
  loadSettings()
})
</script>

<template>
  <div class="p-4 md:p-6 space-y-4 md:space-y-6 overflow-y-auto h-full max-w-4xl mx-auto">
    <!-- Header removed, handled by Top Nav -->

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 md:gap-6 h-full pb-4">
      <!-- Left Column: Database Settings -->
      <div class="glass-card p-4 md:p-5 space-y-4 bg-black/40 border border-white/10 shadow-2xl backdrop-blur-md rounded-3xl flex flex-col justify-between">
      <div class="flex items-center gap-3 bg-white/5 p-3 rounded-xl w-fit border border-white/10">
        <div class="w-10 h-10 rounded-xl bg-neon-green/20 flex items-center justify-center border border-neon-green/30">
          <svg class="w-5 h-5 text-neon-green drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <ellipse cx="12" cy="5" rx="9" ry="3" />
            <path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3" />
            <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5" />
          </svg>
        </div>
        <h2 class="text-lg font-extrabold text-white uppercase tracking-widest">Database</h2>
      </div>

      <!-- Stats -->
      <div class="flex gap-4">
        <div class="flex-1 p-3 md:p-4 rounded-2xl bg-black/40 border border-white/20 shadow-inner">
          <p class="text-[10px] md:text-xs font-bold text-white uppercase tracking-widest mb-1">Total Records</p>
          <p class="text-2xl md:text-3xl font-extrabold text-gradient drop-shadow-lg">{{ logCount.toLocaleString() }}</p>
        </div>
      </div>

      <!-- Log Interval -->
      <div class="space-y-2">
        <label class="text-xs md:text-sm font-bold text-white uppercase tracking-wider">Interval Penyimpanan Data</label>
        <p class="text-xs font-medium text-slate-300 leading-relaxed max-w-2xl">
          Disimpan ke database setiap interval ini.
        </p>
        <div class="flex items-center gap-3">
          <select
            v-model="logInterval"
            class="flex-1 px-3 py-2 rounded-xl bg-black/40 border border-white/30 text-sm md:text-base font-bold text-white shadow-inner outline-none focus:border-neon-cyan focus:ring-2 focus:ring-neon-cyan/30 transition-all appearance-none cursor-pointer"
          >
            <option :value="1" class="bg-slate-900">Setiap 1 menit</option>
            <option :value="2" class="bg-slate-900">Setiap 2 menit</option>
            <option :value="5" class="bg-slate-900">Setiap 5 menit</option>
            <option :value="10" class="bg-slate-900">Setiap 10 menit</option>
            <option :value="15" class="bg-slate-900">Setiap 15 menit</option>
            <option :value="30" class="bg-slate-900">Setiap 30 menit</option>
            <option :value="60" class="bg-slate-900">Setiap 1 jam</option>
          </select>
          <button @click="saveLogInterval" :disabled="isSaving" class="px-4 py-2 rounded-xl text-sm md:text-base font-bold text-white bg-gradient-to-r from-neon-green to-emerald-500 border border-white/20 shadow-[0_0_15px_rgba(57,255,20,0.4)] hover:shadow-[0_0_25px_rgba(57,255,20,0.6)] transition-all whitespace-nowrap">
            {{ isSaving ? 'Menyimpan...' : 'Simpan' }}
          </button>
        </div>
        <p v-if="saveMessage" class="text-sm font-bold" :class="saveMessage.startsWith('✓') ? 'text-neon-green drop-shadow-md' : 'text-neon-red drop-shadow-md'">
          {{ saveMessage }}
        </p>
      </div>

      <!-- Data Retention / Cleanup -->
      <div class="space-y-2 pt-4 border-t border-white/20">
        <label class="text-xs md:text-sm font-bold text-white uppercase tracking-wider">Pembersihan Data Lama</label>
        <p class="text-xs font-medium text-slate-300 leading-relaxed max-w-2xl">
          Hapus data yang lebih lama untuk menghemat ruang.
        </p>
        <div class="flex items-center gap-3">
          <select
            v-model="retentionDays"
            class="flex-1 px-3 py-2 rounded-xl bg-black/40 border border-white/30 text-sm md:text-base font-bold text-white shadow-inner outline-none focus:border-neon-cyan focus:ring-2 focus:ring-neon-cyan/30 transition-all appearance-none cursor-pointer"
          >
            <option :value="7" class="bg-slate-900">Lebih dari 7 hari</option>
            <option :value="14" class="bg-slate-900">Lebih dari 14 hari</option>
            <option :value="30" class="bg-slate-900">Lebih dari 30 hari</option>
            <option :value="60" class="bg-slate-900">Lebih dari 60 hari</option>
            <option :value="90" class="bg-slate-900">Lebih dari 90 hari</option>
          </select>
          <button
            @click="cleanupOldData"
            :disabled="isDeleting"
            class="px-4 py-2 rounded-xl text-sm md:text-base font-bold text-white bg-gradient-to-r from-neon-red to-red-600 border border-white/20 shadow-[0_0_15px_rgba(255,77,121,0.4)] hover:shadow-[0_0_25px_rgba(255,77,121,0.6)] transition-all whitespace-nowrap"
          >
            {{ isDeleting ? 'Menghapus...' : 'Hapus Data' }}
          </button>
        </div>
        <p v-if="deleteMessage" class="text-sm font-bold" :class="deleteMessage.startsWith('✓') ? 'text-neon-green drop-shadow-md' : 'text-neon-red drop-shadow-md'">
          {{ deleteMessage }}
        </p>
      </div>
      </div>

      <!-- Right Column: Serial & About -->
      <div class="flex flex-col gap-4 md:gap-6 h-full">
        <!-- Serial Port Info -->
        <div class="glass-card p-4 md:p-5 space-y-4 bg-black/40 border border-white/10 shadow-2xl backdrop-blur-md rounded-3xl flex-1">
      <div class="flex items-center gap-3 bg-white/5 p-3 rounded-xl w-fit border border-white/10">
        <div class="w-10 h-10 rounded-xl bg-neon-cyan/20 flex items-center justify-center border border-neon-cyan/30">
          <svg class="w-5 h-5 text-neon-cyan drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <rect x="2" y="2" width="20" height="8" rx="2" />
            <rect x="2" y="14" width="20" height="8" rx="2" />
            <circle cx="6" cy="6" r="1.5" fill="currentColor" />
            <circle cx="6" cy="18" r="1.5" fill="currentColor" />
          </svg>
        </div>
        <h2 class="text-lg font-extrabold text-white uppercase tracking-widest">Serial Port</h2>
      </div>

      <!-- Serial Controls inside Settings -->
      <div v-if="lastError" class="flex items-center gap-2 px-3 py-2 rounded-lg bg-neon-red/10 border border-neon-red/20 mb-2">
        <svg class="w-4 h-4 text-neon-red" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10" />
          <path d="M12 8v4m0 4h.01" stroke-linecap="round" />
        </svg>
        <span class="text-xs font-medium text-neon-red/90">{{ lastError }}</span>
      </div>

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-3">
          <label class="text-xs font-bold text-white uppercase tracking-wider w-20">Port</label>
          <div class="flex flex-1 gap-2">
            <select
              v-model="selectedPort"
              class="flex-1 px-3 py-2 rounded-xl bg-black/40 border border-white/20 text-sm font-bold text-white outline-none focus:border-neon-cyan/50 transition-all appearance-none cursor-pointer shadow-inner"
              :disabled="isConnected"
            >
              <option value="" disabled class="bg-slate-900">Pilih Port</option>
              <option
                v-for="port in availablePorts"
                :key="port.path"
                :value="port.path"
                class="bg-slate-900"
              >
                {{ port.path }} {{ port.manufacturer ? `(${port.manufacturer})` : '' }}
              </option>
            </select>
            <button
              class="px-3 py-2 rounded-xl bg-white/[0.06] border border-white/[0.1] text-white/80 hover:text-white hover:bg-white/[0.1] transition-all duration-200"
              :class="{ 'animate-spin': isScanning }"
              :disabled="isScanning"
              title="Scan Ports"
              @click="handleScan"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.3" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </button>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <label class="text-xs font-bold text-white uppercase tracking-wider w-20">Baud Rate</label>
          <select
            v-model="selectedBaudRate"
            class="flex-1 px-3 py-2 rounded-xl bg-black/40 border border-white/20 text-sm font-bold text-white outline-none focus:border-neon-cyan/50 transition-all appearance-none cursor-pointer shadow-inner"
            :disabled="isConnected"
          >
            <option v-for="baud in baudRates" :key="baud" :value="baud" class="bg-slate-900">
              {{ baud }}
            </option>
          </select>
        </div>

        <div class="flex items-center gap-3 pt-2">
          <button
            class="flex-1 px-4 py-2.5 rounded-xl font-bold text-sm transition-all duration-300 flex items-center justify-center gap-2 border"
            :class="
              isConnected
                ? 'bg-neon-red/10 text-neon-red border-neon-red/30 hover:bg-neon-red/20 shadow-[0_0_15px_rgba(255,23,68,0.2)]'
                : 'bg-gradient-to-r from-neon-green to-emerald-500 text-white border-white/20 hover:shadow-[0_0_20px_rgba(57,255,20,0.4)]'
            "
            :disabled="isConnecting || (!selectedPort && !isConnected)"
            @click="handleConnect"
          >
            <span v-if="isConnecting" class="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin"></span>
            <template v-else>
              {{ isConnected ? 'Putuskan Koneksi' : 'Hubungkan' }}
            </template>
          </button>
        </div>
      </div>
        </div>

        <!-- About -->
        <div class="glass-card p-4 md:p-5 bg-black/40 border border-white/10 shadow-2xl backdrop-blur-md rounded-3xl">
      <div class="flex flex-col sm:flex-row sm:items-center gap-3 md:gap-4 mb-2 md:mb-3">
        <div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-neon-green/80 to-neon-cyan/80 flex items-center justify-center border border-white/30"
             style="box-shadow: 0 0 20px rgba(57, 255, 20, 0.4);">
          <svg class="w-8 h-8 text-black" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" opacity="0.4" fill="currentColor"/>
            <circle cx="12" cy="14" r="2.5" fill="currentColor"/>
          </svg>
        </div>
        <div>
          <h3 class="text-xl font-extrabold text-white tracking-wide">AquaPhonik Desktop</h3>
          <p class="text-sm font-bold text-slate-200 mt-1 uppercase tracking-widest">v1.0.0 • Aquaponics Monitoring & Control</p>
        </div>
      </div>
        <p class="text-xs md:text-sm font-medium text-slate-300 mt-2">
          Built with Electron + Vue 3 + Vite • Tailwind CSS • ECharts • SerialPort • SQLite
        </p>
      </div>
    </div>
    </div>
  </div>
</template>
