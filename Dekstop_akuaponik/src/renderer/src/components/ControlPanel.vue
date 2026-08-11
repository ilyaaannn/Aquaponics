<script setup lang="ts">
/**
 * ControlPanel — Toggle switches for Pump and Oxygen control
 * Sends serial commands to the microcontroller.
 */
import { ref, watch } from 'vue'

const props = defineProps<{
  pumpStatus: boolean
  oxygenStatus: boolean
}>()

const emit = defineEmits<{
  (e: 'toggle-pump', value: boolean): void
  (e: 'toggle-oxygen', value: boolean): void
}>()

const pumpLoading = ref(false)
const oxyLoading = ref(false)

// Local state to handle optimistic UI
const localPump = ref(props.pumpStatus)
const localOxy = ref(props.oxygenStatus)

// Sync with props
watch(() => props.pumpStatus, (val) => { localPump.value = val; pumpLoading.value = false })
watch(() => props.oxygenStatus, (val) => { localOxy.value = val; oxyLoading.value = false })

function togglePump(): void {
  pumpLoading.value = true
  const newState = !localPump.value
  localPump.value = newState
  emit('toggle-pump', newState)
}

function toggleOxygen(): void {
  oxyLoading.value = true
  const newState = !localOxy.value
  localOxy.value = newState
  emit('toggle-oxygen', !props.oxygenStatus)
}
</script>

<template>
  <div class="glass-card p-4 lg:p-5 xl:p-6 w-full transition-colors duration-300 bg-slate-900/80 border-2 border-white/20 shadow-2xl rounded-3xl backdrop-blur-xl flex flex-col">
    <div class="flex items-center gap-3 mb-5 bg-white/10 p-3 rounded-xl w-fit border border-white/20">
      <svg class="w-5 h-5 text-emerald-400 drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor"
        stroke-width="2.5">
        <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
        <line x1="8" y1="21" x2="16" y2="21" />
        <line x1="12" y1="17" x2="12" y2="21" />
      </svg>
      <h2 class="text-xs lg:text-sm xl:text-base font-bold text-white uppercase tracking-wider">Control Panel</h2>
    </div>

    <div class="flex flex-col sm:flex-row gap-3 lg:gap-5 xl:gap-6 w-full">
      <!-- Water Pump Control -->
      <div
        class="flex-1 flex items-center justify-between p-3 lg:p-4 xl:p-5 rounded-2xl border transition-all duration-300 shadow-lg hover:shadow-xl"
        :class="pumpStatus ? 'bg-aqua-500/20 border-aqua-400/50' : 'bg-slate-800/80 border-white/20'">
        <div class="flex items-center gap-3 lg:gap-4 xl:gap-5">
          <div class="w-10 h-10 lg:w-12 lg:h-12 xl:w-14 xl:h-14 rounded-xl flex items-center justify-center transition-colors duration-300 shadow-inner border"
            :class="pumpStatus ? 'bg-aqua-500/30 text-aqua-400 border-aqua-400/30' : 'bg-white/10 text-white/90 border-white/20'">
            <svg class="w-5 h-5 lg:w-6 lg:h-6 xl:w-7 xl:h-7 drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
            </svg>
          </div>
          <div>
            <h3 class="text-sm lg:text-base xl:text-lg font-extrabold text-white transition-colors">Pompa Air</h3>
            <p class="text-[10px] lg:text-xs xl:text-sm font-bold text-white/90 mt-0.5 uppercase tracking-wide">Sirkulasi air</p>
          </div>
        </div>

        <button class="relative inline-flex h-7 w-12 lg:h-8 lg:w-14 xl:h-10 xl:w-20 items-center rounded-full transition-colors focus:outline-none focus:ring-4 focus:ring-aqua-500/30 flex-shrink-0"
          :class="pumpStatus ? 'bg-aqua-500 shadow-[0_0_15px_rgba(58,205,148,0.6)]' : 'bg-white/20'"
          :disabled="pumpLoading" @click="togglePump">
          <span v-if="pumpLoading" class="absolute inset-0 flex items-center justify-center">
            <span class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
          </span>
          <span v-else class="inline-block h-5 w-5 lg:h-6 lg:w-6 xl:h-8 xl:w-8 transform rounded-full bg-white transition-transform shadow-md"
            :class="pumpStatus ? 'translate-x-6 lg:translate-x-7 xl:translate-x-11' : 'translate-x-1'"></span>
        </button>
      </div>

      <!-- Oxygen Pump Control -->
      <div
        class="flex-1 flex items-center justify-between p-3 lg:p-4 xl:p-5 rounded-2xl border transition-all duration-300 shadow-lg hover:shadow-xl"
        :class="oxygenStatus ? 'bg-ocean-500/20 border-ocean-400/50' : 'bg-slate-800/80 border-white/20'">
        <div class="flex items-center gap-3 lg:gap-4 xl:gap-5">
          <div class="w-10 h-10 lg:w-12 lg:h-12 xl:w-14 xl:h-14 rounded-xl flex items-center justify-center transition-colors duration-300 shadow-inner border"
            :class="oxygenStatus ? 'bg-ocean-500/30 text-ocean-400 border-ocean-400/30' : 'bg-white/10 text-white/90 border-white/20'">
            <svg class="w-5 h-5 lg:w-6 lg:h-6 xl:w-7 xl:h-7 drop-shadow-md" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <path d="M9.59 4.59A2 2 0 1 1 11 8H2m10.59 11.41A2 2 0 1 0 14 16H2m15.73-8.27A2.5 2.5 0 1 1 19.5 12H2" stroke-linecap="round"/>
            </svg>
          </div>
          <div>
            <h3 class="text-sm lg:text-base xl:text-lg font-extrabold text-white transition-colors">Pompa O²</h3>
            <p class="text-[10px] lg:text-xs xl:text-sm font-bold text-white/90 mt-0.5 uppercase tracking-wide">Aerasi kolam</p>
          </div>
        </div>

        <button class="relative inline-flex h-7 w-12 lg:h-8 lg:w-14 xl:h-10 xl:w-20 items-center rounded-full transition-colors focus:outline-none focus:ring-4 focus:ring-ocean-500/30 flex-shrink-0"
          :class="oxygenStatus ? 'bg-ocean-500 shadow-[0_0_15px_rgba(54,150,252,0.6)]' : 'bg-white/20'"
          :disabled="oxyLoading" @click="toggleOxygen">
          <span v-if="oxyLoading" class="absolute inset-0 flex items-center justify-center">
            <span class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
          </span>
          <span v-else class="inline-block h-5 w-5 lg:h-6 lg:w-6 xl:h-8 xl:w-8 transform rounded-full bg-white transition-transform shadow-md"
            :class="oxygenStatus ? 'translate-x-6 lg:translate-x-7 xl:translate-x-11' : 'translate-x-1'"></span>
        </button>
      </div>
    </div>
  </div>
</template>
