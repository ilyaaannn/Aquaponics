<script setup lang="ts">
/**
 * Header — Top bar component
 * Glassmorphism header with serial connection controls.
 */
import { ref, onMounted, onUnmounted } from 'vue'
import { useSerial } from '../composables/useSerial'
import { useSensorData } from '../composables/useSensorData'

const { isConnected, currentPort } = useSerial()
const { lastUpdateFormatted, dataReceived } = useSensorData()

const networkIP = ref<string | null>(null)
const networkIface = ref<string | null>(null)
let ipRefreshTimer: ReturnType<typeof setInterval> | null = null

// Fetch WiFi IP on mount and refresh every 30 seconds
async function fetchNetworkIP(): Promise<void> {
  try {
    const result = await window.api.system.getNetworkIP()
    networkIP.value = result.ip
    networkIface.value = result.iface
  } catch {
    networkIP.value = null
    networkIface.value = null
  }
}

onMounted(() => {
  fetchNetworkIP()
  ipRefreshTimer = setInterval(fetchNetworkIP, 30000)
})

onUnmounted(() => {
  if (ipRefreshTimer) {
    clearInterval(ipRefreshTimer)
    ipRefreshTimer = null
  }
})

// Window Controls
async function handleMinimize(): Promise<void> {
  await window.api.windowControls.minimize()
}

async function handleClose(): Promise<void> {
  await window.api.windowControls.close()
}
</script>

<template>
  <header class="w-full h-auto lg:h-14 py-2 lg:py-0 bg-slate-950/80 backdrop-blur-xl border-b-2 border-white/20 px-3 lg:px-4 flex flex-col lg:flex-row items-center justify-between gap-2 transition-all duration-300 z-50">
    <!-- Left: Page title & Logo -->
    <div class="flex items-center gap-2 lg:gap-3 w-full lg:w-auto">
      <!-- App Logo -->
      <div class="flex items-center justify-center w-8 h-8 rounded-lg bg-gradient-to-br from-neon-cyan to-neon-green/50 p-[1.5px] shadow-[0_0_15px_rgba(51,238,255,0.3)]">
        <div class="w-full h-full bg-black/90 rounded-md flex items-center justify-center">
          <svg class="w-5 h-5 text-neon-cyan drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" stroke-linejoin="round"/>
          </svg>
        </div>
      </div>
      <h2 class="text-lg lg:text-xl xl:text-2xl font-black text-transparent bg-clip-text bg-gradient-to-r from-white to-slate-400 tracking-tighter drop-shadow-sm uppercase">
        AQUA<span class="text-neon-cyan drop-shadow-[0_0_8px_rgba(51,238,255,0.8)]">PHONIK</span>
      </h2>
      <!-- Live indicator & Time -->
      <div class="ml-1 lg:ml-2 flex items-center gap-2 px-2 py-1 lg:px-4 lg:py-1.5 rounded-full bg-black/40 border border-white/10 shadow-inner">
        <span
          class="w-2 h-2 rounded-full transition-all"
          :class="dataReceived ? 'bg-neon-green animate-pulse' : 'bg-slate-400'"
          :style="dataReceived ? 'box-shadow: 0 0 10px rgba(57,255,20,0.8)' : ''"
        ></span>
        <span class="text-[10px] md:text-xs font-mono font-bold text-white tracking-widest">
          {{ isConnected ? lastUpdateFormatted : 'OFFLINE' }}
        </span>
      </div>

      <!-- WiFi IP Address -->
      <div class="ml-1 lg:ml-2 flex items-center gap-2 px-2 py-1 lg:px-3 lg:py-1.5 rounded-full border shadow-inner transition-all duration-300"
        :class="networkIP ? 'bg-neon-cyan/5 border-neon-cyan/20' : 'bg-black/40 border-white/10'"
      >
        <!-- WiFi Icon -->
        <svg class="w-3.5 h-3.5 transition-colors" :class="networkIP ? 'text-neon-cyan' : 'text-slate-500'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M5 12.55a11 11 0 0 1 14.08 0" />
          <path d="M1.42 9a16 16 0 0 1 21.16 0" />
          <path d="M8.53 16.11a6 6 0 0 1 6.95 0" />
          <line x1="12" y1="20" x2="12.01" y2="20" />
        </svg>
        <span v-if="networkIP" class="text-[10px] md:text-xs font-mono font-bold text-neon-cyan tracking-wide" :style="'text-shadow: 0 0 8px rgba(51,238,255,0.4)'">
          {{ networkIP }}
        </span>
        <span v-else class="text-[10px] md:text-xs font-mono font-bold text-slate-500 tracking-wide">
          No Network
        </span>
      </div>
    </div>

    <!-- Right: Connection Status & Window controls -->
    <div class="flex flex-wrap items-center justify-center lg:justify-end gap-1.5 lg:gap-2 w-full lg:w-auto">

      <!-- Status dot -->
      <div class="flex items-center gap-2 ml-1">
        <span :class="isConnected ? 'status-dot-connected' : 'status-dot-disconnected'"></span>
        <div class="flex flex-col">
          <span class="text-[10px] font-medium" :class="isConnected ? 'text-neon-green/80' : 'text-white/30'">
            {{ isConnected ? 'Connected' : 'Disconnected' }}
          </span>
          <span v-if="isConnected" class="text-[9px] text-white/30 font-mono">{{ currentPort }}</span>
        </div>
      </div>

      <!-- Window Controls -->
      <div class="flex items-center gap-1.5 ml-2 pl-3 border-l-2 border-white/10">
        <button
          @click="handleMinimize"
          class="flex items-center justify-center w-8 h-8 rounded-lg bg-black/40 border border-white/10 text-white/60 hover:text-white hover:bg-white/10 transition-all duration-200"
          title="Minimize"
        >
          <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
        </button>
        <button
          @click="handleClose"
          class="flex items-center justify-center w-8 h-8 rounded-lg bg-black/40 border border-white/10 text-white/60 hover:text-white hover:bg-neon-red/80 hover:border-neon-red/50 hover:shadow-[0_0_15px_rgba(255,23,68,0.5)] transition-all duration-200"
          title="Exit"
        >
          <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </button>
      </div>
    </div>
  </header>
</template>
