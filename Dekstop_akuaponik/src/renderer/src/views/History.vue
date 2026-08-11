<script setup lang="ts">
/**
 * History View — Displays historical sensor data from PostgreSQL database.
 * Works independently of serial/USB connection — data is always available.
 * Supports filtering by date range and export to Excel.
 */
import { ref, onMounted, computed } from 'vue'

interface LogEntry {
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
}

const logs = ref<LogEntry[]>([])
const isLoading = ref(false)
const totalCount = ref(0)
const limit = ref(50)
const dbError = ref('')
const isExporting = ref(false)
const exportMessage = ref('')
const exportSuccess = ref(false)
let exportToastTimer: ReturnType<typeof setTimeout> | null = null

// Date filter
const startDate = ref('')
const endDate = ref('')

// Set default dates
const today = new Date()
const yesterday = new Date(today)
yesterday.setDate(yesterday.getDate() - 1)
startDate.value = yesterday.toISOString().split('T')[0]
endDate.value = today.toISOString().split('T')[0]

async function loadLatestLogs(): Promise<void> {
  isLoading.value = true
  dbError.value = ''
  try {
    logs.value = (await window.api.database.getLatestLogs(limit.value)) as unknown as LogEntry[]
    totalCount.value = await window.api.database.getLogCount()
  } catch (err) {
    console.error('Failed to load logs:', err)
    dbError.value = 'Gagal memuat data dari database. Pastikan PostgreSQL berjalan.'
  } finally {
    isLoading.value = false
  }
}

async function loadByDateRange(): Promise<void> {
  if (!startDate.value || !endDate.value) return
  isLoading.value = true
  dbError.value = ''
  try {
    logs.value = (await window.api.database.getLogsByDateRange(
      `${startDate.value} 00:00:00`,
      `${endDate.value} 23:59:59`
    )) as unknown as LogEntry[]
    totalCount.value = logs.value.length
  } catch (err) {
    console.error('Failed to load filtered logs:', err)
    dbError.value = 'Gagal memuat data berdasarkan filter. Pastikan PostgreSQL berjalan.'
  } finally {
    isLoading.value = false
  }
}

const formattedLogs = computed(() => {
  return logs.value.map((log) => ({
    ...log,
    formattedTime: new Date(log.timestamp).toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })
  }))
})

onMounted(() => {
  loadLatestLogs()
})

/**
 * Export current data to Excel file
 */
async function exportToExcel(): Promise<void> {
  if (logs.value.length === 0 || isExporting.value) return

  isExporting.value = true
  exportMessage.value = ''

  try {
    // Auto-detect date range from loaded data for accurate filenames
    let actualStart = startDate.value || 'latest'
    let actualEnd = endDate.value || 'latest'
    try {
      if (logs.value.length > 0) {
        const dates = logs.value.map(l => new Date(l.timestamp).getTime()).filter(t => !isNaN(t))
        if (dates.length > 0) {
          actualStart = new Date(Math.min(...dates)).toISOString().split('T')[0]
          actualEnd = new Date(Math.max(...dates)).toISOString().split('T')[0]
        }
      }
    } catch (e) {
      console.warn('Date parse error', e)
    }

    // Convert Vue proxies to plain objects to prevent IPC DataCloneError
    const rawData = JSON.parse(JSON.stringify(logs.value))

    const result = await window.api.export.toExcel(
      rawData,
      {
        start: actualStart,
        end: actualEnd
      }
    )

    exportMessage.value = result.message
    exportSuccess.value = result.success

    // Auto-hide toast after 4 seconds
    if (exportToastTimer) clearTimeout(exportToastTimer)
    exportToastTimer = setTimeout(() => {
      exportMessage.value = ''
    }, 4000)
  } catch (err) {
    exportMessage.value = 'Gagal mengekspor data'
    exportSuccess.value = false
    console.error('Export error:', err)
  } finally {
    isExporting.value = false
  }
}
</script>

<template>
  <div class="p-6 md:p-8 space-y-6 md:space-y-8 overflow-y-auto h-full">
    <!-- Header removed, handled by Top Nav -->

    <!-- Filters -->
    <div class="glass-card p-5 flex flex-wrap items-end gap-5 bg-black/40 border border-white/10 shadow-2xl backdrop-blur-md rounded-3xl">
      <div class="flex flex-col gap-1.5 w-full sm:w-auto">
        <label class="text-sm font-bold text-white uppercase tracking-wider">Dari Tanggal</label>
        <input v-model="startDate" type="date"
          class="w-full sm:w-auto px-4 py-2.5 rounded-xl bg-black/40 border border-white/30 text-base font-medium text-white shadow-inner outline-none focus:border-neon-cyan focus:ring-2 focus:ring-neon-cyan/30 transition-all" />
      </div>
      <div class="flex flex-col gap-1.5 w-full sm:w-auto">
        <label class="text-sm font-bold text-white uppercase tracking-wider">Sampai Tanggal</label>
        <input v-model="endDate" type="date"
          class="w-full sm:w-auto px-4 py-2.5 rounded-xl bg-black/40 border border-white/30 text-base font-medium text-white shadow-inner outline-none focus:border-neon-cyan focus:ring-2 focus:ring-neon-cyan/30 transition-all" />
      </div>
      <div class="flex gap-3 w-full sm:w-auto">
        <button @click="loadByDateRange" class="flex-1 sm:flex-none px-6 py-2.5 rounded-xl font-bold text-white bg-gradient-to-r from-neon-blue to-neon-cyan border border-white/20 shadow-[0_0_15px_rgba(51,238,255,0.4)] hover:shadow-[0_0_25px_rgba(51,238,255,0.6)] transition-all">
          Filter
        </button>
        <button @click="loadLatestLogs"
          class="flex-1 sm:flex-none px-5 py-2.5 rounded-xl font-bold text-white bg-white/10 border border-white/30 hover:bg-white/20 transition-all shadow-md">
          Latest {{ limit }}
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-3 w-full lg:w-auto lg:ml-auto">
        <div class="flex items-center gap-3 w-full sm:w-auto">
          <label class="text-sm font-bold text-white uppercase tracking-wider">Show:</label>
          <select v-model="limit"
            class="flex-1 sm:flex-none px-3 py-2 rounded-xl bg-black/40 border border-white/30 text-base font-medium text-white shadow-inner outline-none focus:border-neon-cyan"
            @change="loadLatestLogs">
            <option :value="25">25</option>
            <option :value="50">50</option>
            <option :value="100">100</option>
            <option :value="200">200</option>
            <option :value="500">500</option>
          </select>
        </div>

        <!-- Export Excel Button (icon-only) -->
        <button
          @click="exportToExcel"
          :disabled="logs.length === 0 || isExporting"
          title="Export ke Excel (.xlsx)"
          class="group relative p-2.5 rounded-xl font-bold text-white border transition-all duration-300 flex items-center justify-center overflow-hidden"
          :class="logs.length === 0 || isExporting
            ? 'bg-white/5 border-white/10 text-white/30 cursor-not-allowed'
            : 'bg-gradient-to-r from-emerald-600 to-emerald-400 border-emerald-300/50 shadow-[0_0_15px_rgba(16,185,129,0.5)] hover:shadow-[0_0_25px_rgba(16,185,129,0.7)] hover:from-emerald-500 hover:to-emerald-300 active:scale-[0.97]'"
        >
          <span v-if="isExporting" class="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
          <svg v-else class="w-5 h-5 transition-transform group-hover:scale-110 drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
        </button>
      </div>
    </div>

    <!-- Export toast notification -->
    <Transition name="toast">
      <div v-if="exportMessage"
        class="fixed top-6 right-6 z-[999] flex items-center gap-3 px-5 py-3.5 rounded-2xl shadow-2xl border backdrop-blur-xl transition-all duration-300"
        :class="exportSuccess
          ? 'bg-emerald-900/80 border-emerald-500/40 shadow-[0_0_30px_rgba(16,185,129,0.3)]'
          : 'bg-red-900/80 border-red-500/40 shadow-[0_0_30px_rgba(239,68,68,0.3)]'"
      >
        <!-- Icon -->
        <div class="w-8 h-8 rounded-full flex items-center justify-center"
          :class="exportSuccess ? 'bg-emerald-500/20' : 'bg-red-500/20'"
        >
          <svg v-if="exportSuccess" class="w-5 h-5 text-emerald-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12" />
          </svg>
          <svg v-else class="w-5 h-5 text-red-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
            <circle cx="12" cy="12" r="10" />
            <path d="M12 8v4m0 4h.01" />
          </svg>
        </div>
        <div class="flex flex-col">
          <span class="text-sm font-bold" :class="exportSuccess ? 'text-emerald-300' : 'text-red-300'">
            {{ exportSuccess ? 'Export Berhasil!' : 'Export Gagal' }}
          </span>
          <span class="text-xs" :class="exportSuccess ? 'text-emerald-400/70' : 'text-red-400/70'">
            {{ exportMessage }}
          </span>
        </div>
        <!-- Close button -->
        <button @click="exportMessage = ''" class="ml-2 p-1 rounded-lg hover:bg-white/10 transition-colors">
          <svg class="w-4 h-4 text-white/50" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M18 6L6 18M6 6l12 12" stroke-linecap="round" />
          </svg>
        </button>
      </div>
    </Transition>

    <!-- Data info bar -->
    <div class="flex items-center justify-between px-5 py-3 rounded-2xl bg-black/20 border border-white/5">
      <div class="flex items-center gap-3">
        <!-- Database status icon -->
        <div class="flex items-center gap-2 px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20">
          <svg class="w-3.5 h-3.5 text-emerald-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
            <ellipse cx="12" cy="5" rx="9" ry="3" />
            <path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3" />
            <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5" />
          </svg>
          <span class="text-[10px] font-bold text-emerald-400 uppercase tracking-wider">Database</span>
        </div>
        <span class="text-xs text-white/50">
          Menampilkan <span class="font-bold text-white/80">{{ logs.length }}</span> data
          <span v-if="totalCount > 0"> dari <span class="font-bold text-white/80">{{ totalCount }}</span> total</span>
        </span>
      </div>
      <span class="text-[10px] text-white/30 italic">
        Data tersimpan di database — tersedia tanpa koneksi USB
      </span>
    </div>

    <!-- Table -->
    <div class="glass-card overflow-hidden bg-black/40 border border-white/10 shadow-2xl rounded-3xl backdrop-blur-md">
      <!-- Loading -->
      <div v-if="isLoading" class="p-12 text-center">
        <div class="w-10 h-10 mx-auto border-4 border-neon-cyan border-t-transparent rounded-full animate-spin"></div>
        <p class="text-base font-bold text-white mt-4 tracking-wide">Memuat data...</p>
      </div>

      <!-- Database error state -->
      <div v-else-if="dbError" class="p-12 text-center">
        <div class="w-16 h-16 mx-auto rounded-full bg-red-500/10 border border-red-500/30 flex items-center justify-center mb-5">
          <svg class="w-8 h-8 text-red-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10" />
            <path d="M12 8v4m0 4h.01" stroke-linecap="round" />
          </svg>
        </div>
        <p class="text-lg font-bold text-red-300 mb-2">Database Error</p>
        <p class="text-sm text-white/60 max-w-md mx-auto">{{ dbError }}</p>
        <button @click="loadLatestLogs" class="mt-6 px-6 py-2.5 rounded-xl font-bold text-white bg-white/10 border border-white/20 hover:bg-white/20 transition-all">
          Coba Lagi
        </button>
      </div>

      <!-- Empty state -->
      <div v-else-if="logs.length === 0" class="p-12 text-center">
        <svg class="w-16 h-16 mx-auto text-white/50 mb-4" viewBox="0 0 24 24" fill="none"
          stroke="currentColor" stroke-width="2">
          <rect x="3" y="3" width="18" height="18" rx="2" />
          <path d="M3 9h18M9 3v18" />
        </svg>
        <p class="text-lg font-bold text-white/80">Belum ada data log tersimpan</p>
        <p class="text-sm text-white/40 mt-2 max-w-md mx-auto">
          Data sensor akan otomatis tersimpan saat perangkat terhubung.<br/>
          Histori yang sudah tersimpan akan tetap tampil meskipun USB tidak terhubung.
        </p>
      </div>

      <!-- Data table -->
      <div v-else class="overflow-x-auto">
        <table class="w-full text-base">
          <thead>
            <tr class="bg-black/40 border-b border-white/30">
              <th class="text-left px-5 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">Waktu</th>
              <th class="text-right px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">Suhu Air</th>
              <th class="text-right px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">pH</th>
              <th class="text-right px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">TDS</th>
              <th class="text-right px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">DO</th>
              <th class="text-right px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">Turb.</th>
              <th class="text-right px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">Level</th>
              <th class="text-right px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">Suhu Udara</th>
              <th class="text-right px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">Hum.</th>
              <th class="text-center px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest border-r border-white/10">Pompa</th>
              <th class="text-center px-4 py-4 text-sm font-extrabold text-white uppercase tracking-widest">O₂</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="log in formattedLogs" :key="log.id"
              class="border-b border-white/10 hover:bg-white/20 transition-colors duration-200">
              <td class="px-5 py-3.5 text-white font-mono font-bold text-sm whitespace-nowrap border-r border-white/10 bg-black/20">
                {{ log.formattedTime }}
              </td>
              <td class="text-right px-4 py-3.5 text-white font-bold drop-shadow-md border-r border-white/10">{{ log.temp_water.toFixed(1) }}°C</td>
              <td class="text-right px-4 py-3.5 text-white font-bold drop-shadow-md border-r border-white/10">{{ log.ph.toFixed(1) }}</td>
              <td class="text-right px-4 py-3.5 text-white font-bold drop-shadow-md border-r border-white/10">{{ log.tds.toFixed(0) }}</td>
              <td class="text-right px-4 py-3.5 text-white font-bold drop-shadow-md border-r border-white/10">{{ log.do_value.toFixed(0) }}</td>
              <td class="text-right px-4 py-3.5 text-white font-bold drop-shadow-md border-r border-white/10">{{ log.turbidity.toFixed(0) }}</td>
              <td class="text-right px-4 py-3.5 text-white font-bold drop-shadow-md border-r border-white/10">{{ log.water_lvl.toFixed(1) }}</td>
              <td class="text-right px-4 py-3.5 text-white font-bold drop-shadow-md border-r border-white/10">{{ log.temp_air.toFixed(1) }}°C</td>
              <td class="text-right px-4 py-3.5 text-white font-bold drop-shadow-md border-r border-white/10">{{ log.humidity.toFixed(1) }}%</td>
              <td class="text-center px-4 py-3.5 border-r border-white/10">
                <span class="inline-block px-3 py-1 rounded-full text-xs font-extrabold tracking-wider border" :class="log.pump_status
                    ? 'bg-aqua-500/30 text-aqua-300 border-aqua-400/50 shadow-[0_0_10px_rgba(58,205,148,0.5)]'
                    : 'bg-black/50 text-white/50 border-white/20'
                  ">
                  {{ log.pump_status ? 'ON' : 'OFF' }}
                </span>
              </td>
              <td class="text-center px-4 py-3.5">
                <span class="inline-block px-3 py-1 rounded-full text-xs font-extrabold tracking-wider border" :class="log.oxy_status
                    ? 'bg-ocean-500/30 text-ocean-300 border-ocean-400/50 shadow-[0_0_10px_rgba(54,150,252,0.5)]'
                    : 'bg-black/50 text-white/50 border-white/20'
                  ">
                  {{ log.oxy_status ? 'ON' : 'OFF' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Toast notification transitions */
.toast-enter-active {
  animation: toast-in 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}
.toast-leave-active {
  animation: toast-out 0.3s cubic-bezier(0.55, 0, 1, 0.45);
}
@keyframes toast-in {
  0% { opacity: 0; transform: translateX(100%) scale(0.9); }
  100% { opacity: 1; transform: translateX(0) scale(1); }
}
@keyframes toast-out {
  0% { opacity: 1; transform: translateX(0) scale(1); }
  100% { opacity: 0; transform: translateX(100%) scale(0.9); }
}
</style>
