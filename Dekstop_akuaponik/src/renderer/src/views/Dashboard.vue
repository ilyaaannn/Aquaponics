<script setup lang="ts">
/**
 * Dashboard View — Futuristic Glassmorphism Monitoring Dashboard
 * Features: ECharts Gauge Charts, Floating Sensor Badges, IoT Network Lines,
 * Neon Control Panel, and Dark Immersive Theme.
 * Responsive: Scales down proportionally on small desktop LCD screens.
 */
import { computed, ref, onMounted, onUnmounted } from 'vue'
import GaugeChart from '../components/GaugeChart.vue'
import ControlPanel from '../components/ControlPanel.vue'
import { useSensorData } from '../composables/useSensorData'
import { useSerial } from '../composables/useSerial'

const { sensorData, dataReceived, isPumpOn, isOxygenOn } =
  useSensorData()
const { sendCommand, isConnected } = useSerial()

// === Responsive Scaling for Small Desktop LCD Screens ===
const windowWidth = ref(window.innerWidth)
const windowHeight = ref(window.innerHeight)

function handleResize(): void {
  windowWidth.value = window.innerWidth
  windowHeight.value = window.innerHeight
}

onMounted(() => {
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
})

// Compute scale factor: base design is 1400px wide and 850px high. Below that, scale down.
// Minimum scale ~0.45 for very small screens
const dashboardScale = computed(() => {
  const w = windowWidth.value
  const h = windowHeight.value
  
  // Calculate scale required for width and height separately
  const scaleW = w / 1400
  const scaleH = h / 850
  
  // Take the smaller scale to ensure it fits both horizontally and vertically without scrolling
  const scale = Math.min(scaleW, scaleH)
  
  if (scale >= 1) return 1
  return Math.max(0.45, scale)
})

// Gauge size is fixed because the parent container scales the entire layout proportionally
const gaugeSize = computed(() => 160)

// Handle pump toggle
async function handlePumpToggle(newState: boolean): Promise<void> {
  await sendCommand(newState ? 'POMPA:1' : 'POMPA:0')
}

// Handle oxygen toggle
async function handleOxygenToggle(newState: boolean): Promise<void> {
  await sendCommand(newState ? 'OKSIGEN:1' : 'OKSIGEN:0')
}

// Floating sensor badge configurations
const floatingSensors = computed(() => [
  {
    title: 'Level Air', value: sensorData.value.water_lvl, unit: 'cm',
    icon: 'waves', neonColor: '#5294ff', glowColor: 'rgba(82, 148, 255, 0.2)'
  },
  {
    title: 'Kekeruhan', value: sensorData.value.turbidity, unit: 'NTU',
    icon: 'eye', neonColor: '#c4a1ff', glowColor: 'rgba(196, 161, 255, 0.2)'
  },
  {
    title: 'DO', value: sensorData.value.do, unit: 'mg/L',
    icon: 'bubble', neonColor: '#33eeff', glowColor: 'rgba(51, 238, 255, 0.2)'
  }
])
</script>

<template>
  <div class="dashboard-viewport overflow-y-auto h-full scroll-smooth">
    <div
      class="dashboard-scale-wrapper p-4 lg:p-6 xl:p-8 space-y-6 xl:space-y-8 flex flex-col min-h-full"
      :style="{ zoom: dashboardScale }"
    >
    <!-- No extra header here, moved to Top Nav -->

    <!-- ===== No Data Warning ===== -->
    <div v-if="!dataReceived && !isConnected" class="glass-card p-14 text-center animate-fade-in border-2 border-white/40 bg-slate-900/80">
      <!-- Animated IoT icon -->
      <div class="relative w-24 h-24 mx-auto mb-8">
        <div class="absolute inset-0 rounded-full bg-white/10 animate-pulse-slow"></div>
        <div class="absolute inset-2 rounded-full bg-white/20 flex items-center justify-center">
          <svg class="w-10 h-10 text-white/80" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" opacity="0.4" fill="currentColor"/>
            <path d="M7 13c0-2.76 2.24-5 5-5s5 2.24 5 5" stroke-linecap="round"/>
            <circle cx="12" cy="14" r="2.5" fill="currentColor"/>
          </svg>
        </div>
        <!-- Orbiting ring -->
        <div class="absolute inset-0 border-2 border-white/20 rounded-full animate-spin-slow"></div>
      </div>
      <h3 class="text-xl md:text-2xl font-bold text-white mb-3">Menunggu Koneksi Data</h3>
      <p class="text-base font-bold text-white max-w-lg mx-auto leading-relaxed">
        Silakan hubungkan perangkat melalui Serial Port di panel atas untuk mulai menerima data sensor secara real-time.
      </p>
      <div class="mt-8 mx-auto w-32 h-1 rounded-full bg-gradient-to-r from-transparent via-white/40 to-transparent"></div>
    </div>

    <!-- ===== MAIN CONTENT ===== -->
    <div v-if="dataReceived || isConnected" class="space-y-6 md:space-y-8 flex-1 flex flex-col">

      <!-- ===== ROW 1: Floating Sensors + Gauges + Control Panel ===== -->
      <div class="flex flex-row gap-6 flex-1 items-stretch">

        <!-- LEFT: Floating Sensor Badges (Redesigned for visibility) -->
        <div class="w-48 flex flex-col items-stretch gap-4 lg:gap-6 h-full min-h-0">
          <div
            v-for="(sensor, idx) in floatingSensors"
            :key="sensor.title"
            class="sensor-badge group flex-1 w-full flex flex-col items-center justify-center p-3 xl:py-4 rounded-2xl bg-slate-900/80 border-2 border-white/20 shadow-2xl backdrop-blur-xl"
            :class="{
              'animate-float': idx === 0,
              'animate-float-delay-1': idx === 1,
              'animate-float-delay-2': idx === 2
            }"
            :style="{ '--badge-glow': sensor.glowColor }"
          >
            <!-- Icon -->
            <div class="mb-2 flex-shrink-0 bg-white/10 p-2 rounded-xl border border-white/20">
              <svg v-if="sensor.icon === 'waves'" class="w-6 h-6" :style="{ color: sensor.neonColor }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <path d="M2 6c.6.5 1.2 1 2.5 1C7 7 7 5 9.5 5c2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1" />
                <path d="M2 12c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1" />
                <path d="M2 18c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1" />
              </svg>
              <svg v-else-if="sensor.icon === 'eye'" class="w-6 h-6" :style="{ color: sensor.neonColor }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                <circle cx="12" cy="12" r="3.5" />
              </svg>
              <svg v-else-if="sensor.icon === 'bubble'" class="w-6 h-6" :style="{ color: sensor.neonColor }" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <circle cx="12" cy="12" r="10" />
                <circle cx="12" cy="12" r="4.5" />
                <circle cx="8" cy="8" r="2" fill="currentColor" opacity="0.6"/>
              </svg>
            </div>
            
            <!-- Content -->
            <div class="flex flex-col text-center w-full min-w-0">
              <div class="flex items-end justify-center gap-1 w-full min-w-0">
                <span class="text-xl lg:text-2xl xl:text-3xl font-extrabold tracking-tight drop-shadow-lg truncate" :style="{ color: sensor.neonColor }">
                  {{ sensor.value.toFixed(1) }}
                </span>
                <span class="text-xs font-bold text-white mb-0.5">{{ sensor.unit }}</span>
              </div>
              <span class="text-[10px] lg:text-xs xl:text-sm font-bold text-white mt-1 uppercase tracking-wider truncate">{{ sensor.title }}</span>
            </div>
            
            <div class="block absolute -right-6 top-1/2 w-6 h-1 rounded-full"
                 :style="{ background: `linear-gradient(90deg, ${sensor.neonColor}80, transparent)` }"></div>
          </div>
        </div>

        <!-- CENTER: Main Gauge Panel -->
        <div class="flex-1 glass-card p-4 lg:p-6 xl:p-8 bg-slate-900/80 border-2 border-white/20 shadow-2xl rounded-3xl flex flex-col backdrop-blur-xl h-full min-h-0">
          <div class="flex flex-col justify-center">
            <div class="flex items-center gap-3 mb-6 bg-white/10 p-3 rounded-xl w-fit border border-white/20">
              <div class="w-3 h-3 rounded-full bg-neon-green" style="box-shadow: 0 0 12px rgba(57,255,20,0.8);"></div>
              <h2 class="text-xs lg:text-sm xl:text-base font-bold text-white uppercase tracking-widest">Parameter Utama</h2>
            </div>

            <!-- Gauge Grid -->
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 lg:gap-4 xl:gap-6">
              <div class="flex flex-col items-center bg-slate-800/80 rounded-2xl p-2 lg:p-3 border border-white/20 shadow-inner">
                <GaugeChart title="Suhu Air" :value="sensorData.temp_water" unit="°C" :min="15" :max="40" color="green" :size="gaugeSize" />
              </div>
              <div class="flex flex-col items-center bg-slate-800/80 rounded-2xl p-2 lg:p-3 border border-white/20 shadow-inner">
                <GaugeChart title="pH" :value="sensorData.ph" unit="pH" :min="0" :max="14" color="cyan" :size="gaugeSize" />
              </div>
              <div class="flex flex-col items-center bg-slate-800/80 rounded-2xl p-2 lg:p-3 border border-white/20 shadow-inner">
                <GaugeChart title="TDS" :value="sensorData.tds" unit="ppm" :min="0" :max="1000" color="amber" :size="gaugeSize" />
              </div>
              <div class="flex flex-col items-center bg-slate-800/80 rounded-2xl p-2 lg:p-3 border border-white/20 shadow-inner">
                <GaugeChart title="Suhu Udara" :value="sensorData.temp_air" unit="°C" :min="15" :max="50" color="rose" :size="gaugeSize" />
              </div>
            </div>
          </div>

          <!-- Secondary parameters row -->
          <div class="mt-4 lg:mt-6 xl:mt-8 pt-4 lg:pt-6 border-t-2 border-white/30 flex-1 flex flex-col">
            <div class="flex flex-row justify-center gap-2 lg:gap-3 xl:gap-4 flex-1 items-stretch">
              <!-- Kelembaban -->
              <div class="flex-1 min-w-[100px] flex items-center gap-2 lg:gap-3 px-2 lg:px-3 xl:px-4 py-2.5 lg:py-3.5 rounded-xl bg-black/20 border border-white/10 shadow-md h-full">
                <div class="w-7 h-7 lg:w-8 lg:h-8 xl:w-10 xl:h-10 rounded-lg lg:rounded-xl bg-neon-cyan/20 flex items-center justify-center flex-shrink-0 border border-neon-cyan/30">
                  <svg class="w-4 h-4 md:w-5 md:h-5 text-neon-cyan drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
                    <path d="M8 14h8" stroke-linecap="round" />
                  </svg>
                </div>
                <div class="w-full">
                  <div class="text-xs lg:text-sm xl:text-base font-extrabold text-white">{{ sensorData.humidity.toFixed(1) }}<span class="text-[10px] lg:text-xs text-white/90 ml-1">%</span></div>
                  <div class="text-[9px] lg:text-[10px] xl:text-xs font-bold text-white uppercase leading-tight mt-0.5">Kelembaban</div>
                </div>
              </div>
              <!-- CO2 -->
              <div class="flex-1 min-w-[100px] flex items-center gap-2 lg:gap-3 px-2 lg:px-3 xl:px-4 py-2.5 lg:py-3.5 rounded-xl bg-slate-800/80 border-2 border-white/20 shadow-md h-full">
                <div class="w-7 h-7 lg:w-8 lg:h-8 xl:w-10 xl:h-10 rounded-lg lg:rounded-xl bg-emerald-500/20 flex items-center justify-center flex-shrink-0 border border-emerald-500/30">
                  <svg class="w-4 h-4 md:w-5 md:h-5 text-emerald-400 drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M17.7 7.7a2.5 2.5 0 1 1 1.8 4.3H2" stroke-linecap="round"/>
                    <path d="M9.6 4.6A2 2 0 1 1 11 8H2" stroke-linecap="round"/>
                  </svg>
                </div>
                <div class="w-full">
                  <div class="text-xs lg:text-sm xl:text-base font-extrabold text-white">{{ sensorData.co2.toFixed(0) }}<span class="text-[10px] lg:text-xs text-white/90 ml-1">ppm</span></div>
                  <div class="text-[9px] lg:text-[10px] xl:text-xs font-bold text-white uppercase leading-tight mt-0.5">CO₂</div>
                </div>
              </div>
              <!-- eCO2 -->
              <div class="flex-1 min-w-[100px] flex items-center gap-2 lg:gap-3 px-2 lg:px-3 xl:px-4 py-2.5 lg:py-3.5 rounded-xl bg-slate-800/80 border-2 border-white/20 shadow-md h-full">
                <div class="w-7 h-7 lg:w-8 lg:h-8 xl:w-10 xl:h-10 rounded-lg lg:rounded-xl bg-violet-500/20 flex items-center justify-center flex-shrink-0 border border-violet-500/30">
                  <svg class="w-4 h-4 md:w-5 md:h-5 text-violet-400 drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z" />
                  </svg>
                </div>
                <div class="w-full">
                  <div class="text-xs lg:text-sm xl:text-base font-extrabold text-white">{{ sensorData.eco2.toFixed(0) }}<span class="text-[10px] lg:text-xs text-white/90 ml-1">ppm</span></div>
                  <div class="text-[9px] lg:text-[10px] xl:text-xs font-bold text-white uppercase leading-tight mt-0.5">eCO₂</div>
                </div>
              </div>
              <!-- TVOC -->
              <div class="flex-1 min-w-[100px] flex items-center gap-2 lg:gap-3 px-2 lg:px-3 xl:px-4 py-2.5 lg:py-3.5 rounded-xl bg-slate-800/80 border-2 border-white/20 shadow-md h-full">
                <div class="w-7 h-7 lg:w-8 lg:h-8 xl:w-10 xl:h-10 rounded-lg lg:rounded-xl bg-amber-500/20 flex items-center justify-center flex-shrink-0 border border-amber-500/30">
                  <svg class="w-4 h-4 md:w-5 md:h-5 text-amber-400 drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z" />
                  </svg>
                </div>
                <div class="w-full">
                  <div class="text-xs lg:text-sm xl:text-base font-extrabold text-white">{{ sensorData.tvoc.toFixed(0) }}<span class="text-[10px] lg:text-xs text-white/90 ml-1">ppb</span></div>
                  <div class="text-[9px] lg:text-[10px] xl:text-xs font-bold text-white uppercase leading-tight mt-0.5">TVOC</div>
                </div>
              </div>
              <!-- pH Volts -->
              <div class="flex-1 min-w-[100px] flex items-center gap-2 lg:gap-3 px-2 lg:px-3 xl:px-4 py-2.5 lg:py-3.5 rounded-xl bg-slate-800/80 border-2 border-white/20 shadow-md h-full">
                <div class="w-7 h-7 lg:w-8 lg:h-8 xl:w-10 xl:h-10 rounded-lg lg:rounded-xl bg-blue-500/20 flex items-center justify-center flex-shrink-0 border border-blue-500/30">
                  <svg class="w-4 h-4 md:w-5 md:h-5 text-blue-400 drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
                  </svg>
                </div>
                <div class="w-full">
                  <div class="text-xs lg:text-sm xl:text-base font-extrabold text-white">{{ sensorData.ph_volts.toFixed(2) }}<span class="text-[10px] lg:text-xs text-white/90 ml-1">V</span></div>
                  <div class="text-[9px] lg:text-[10px] xl:text-xs font-bold text-white uppercase leading-tight mt-0.5">pH Volts</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ROW 2: BOTTOM Control Panel Full Width -->
      <div class="w-full shrink-0">
        <ControlPanel
          :pump-status="isPumpOn"
          :oxygen-status="isOxygenOn"
          @toggle-pump="handlePumpToggle"
          @toggle-oxygen="handleOxygenToggle"
        />
      </div>
    </div>
    </div>
  </div>
</template>
