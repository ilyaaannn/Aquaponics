<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  title: string
  value: number
  unit: string
  icon: string
  accent?: string
  min?: number
  max?: number
  precision?: number
}>()

const formattedValue = computed(() => {
  return props.precision !== undefined ? props.value.toFixed(props.precision) : props.value.toFixed(1)
})

const percentage = computed(() => {
  if (props.min === undefined || props.max === undefined) return 0
  const val = Math.min(props.max, Math.max(props.min, props.value))
  return ((val - props.min) / (props.max - props.min)) * 100
})

function getGlowColor(accent?: string): string {
  switch (accent) {
    case 'aqua': return 'rgba(23, 181, 122, 0.15)'
    case 'ocean': return 'rgba(54, 150, 252, 0.15)'
    case 'amber': return 'rgba(245, 158, 11, 0.15)'
    case 'rose': return 'rgba(244, 63, 94, 0.15)'
    case 'violet': return 'rgba(139, 92, 246, 0.15)'
    case 'cyan': return 'rgba(6, 182, 212, 0.15)'
    case 'emerald': return 'rgba(16, 185, 129, 0.15)'
    default: return 'rgba(23, 181, 122, 0.15)'
  }
}
</script>

<template>
  <div
    class="glass-card-hover p-5 relative overflow-hidden group"
    :style="{ background: `linear-gradient(135deg, ${getGlowColor(accent)}, transparent)` }"
  >
    <!-- Background decoration -->
    <div class="absolute -right-4 -top-4 w-24 h-24 rounded-full opacity-10 group-hover:opacity-20 transition-opacity duration-500"
         :style="{ background: `radial-gradient(circle, ${getGlowColor(accent)}, transparent)` }">
    </div>

    <!-- Header: icon + title -->
    <div class="flex items-center gap-2 mb-3">
      <div
        class="w-8 h-8 rounded-lg flex items-center justify-center transition-colors"
        :class="{
          'bg-aqua-100/50 text-aqua-600 dark:bg-aqua-500/20 dark:text-aqua-400': accent === 'aqua',
          'bg-ocean-100/50 text-ocean-600 dark:bg-ocean-500/20 dark:text-ocean-400': accent === 'ocean',
          'bg-emerald-100/50 text-emerald-600 dark:bg-emerald-500/20 dark:text-emerald-400': accent === 'emerald',
          'bg-rose-100/50 text-rose-600 dark:bg-rose-500/20 dark:text-rose-400': accent === 'rose',
          'bg-amber-100/50 text-amber-600 dark:bg-amber-500/20 dark:text-amber-400': accent === 'amber',
          'bg-violet-100/50 text-violet-600 dark:bg-violet-500/20 dark:text-violet-400': accent === 'violet',
          'bg-cyan-100/50 text-cyan-600 dark:bg-cyan-500/20 dark:text-cyan-400': accent === 'cyan'
        }"
      >
        <!-- Thermometer -->
        <svg v-if="icon === 'thermometer'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M14 14.76V3.5a2.5 2.5 0 0 0-5 0v11.26a4.5 4.5 0 1 0 5 0z" />
        </svg>
        <!-- Droplet / pH -->
        <svg v-else-if="icon === 'droplet'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
        </svg>
        <!-- Zap / TDS -->
        <svg v-else-if="icon === 'zap'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
        </svg>
        <!-- Bubble / DO -->
        <svg v-else-if="icon === 'bubble'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10" />
          <circle cx="12" cy="12" r="4" />
          <circle cx="8" cy="8" r="1.5" fill="currentColor" opacity="0.5"/>
        </svg>
        <!-- Eye / Turbidity -->
        <svg v-else-if="icon === 'eye'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
          <circle cx="12" cy="12" r="3" />
        </svg>
        <!-- Waves / Water Level -->
        <svg v-else-if="icon === 'waves'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M2 6c.6.5 1.2 1 2.5 1C7 7 7 5 9.5 5c2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1" />
          <path d="M2 12c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1" />
          <path d="M2 18c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1" />
        </svg>
        <!-- Wind / CO2 -->
        <svg v-else-if="icon === 'wind'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M17.7 7.7a2.5 2.5 0 1 1 1.8 4.3H2" stroke-linecap="round"/>
          <path d="M9.6 4.6A2 2 0 1 1 11 8H2" stroke-linecap="round"/>
          <path d="M12.6 19.4A2 2 0 1 0 14 16H2" stroke-linecap="round"/>
        </svg>
        <!-- Humidity -->
        <svg v-else-if="icon === 'humidity'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" />
          <path d="M8 14h8" stroke-linecap="round" />
          <path d="M10 11l4 6" stroke-linecap="round" />
        </svg>
        <!-- Cloud / Eco2/TVOC -->
        <svg v-else-if="icon === 'cloud'" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z" />
        </svg>
        <!-- Default circle -->
        <svg v-else class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10" />
        </svg>
      </div>

      <span class="text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">{{ title }}</span>
    </div>

    <!-- Value display -->
    <div class="flex items-baseline gap-1 relative z-10 mt-1">
      <span class="sensor-value">{{ formattedValue }}</span>
      <span class="text-sm font-medium text-slate-500 dark:text-slate-500 ml-1">{{ unit }}</span>
    </div>

    <!-- Progress bar (optional) -->
    <div v-if="min !== undefined && max !== undefined" class="mt-4 relative z-10">
      <div class="h-1.5 w-full bg-slate-200 dark:bg-slate-800 rounded-full overflow-hidden">
        <div 
          class="h-full rounded-full transition-all duration-1000 ease-out"
          :class="{
            'bg-gradient-to-r from-aqua-600 to-aqua-400 dark:from-aqua-500 dark:to-aqua-400': accent === 'aqua' || !accent,
            'bg-gradient-to-r from-ocean-600 to-ocean-400 dark:from-ocean-500 dark:to-ocean-400': accent === 'ocean',
            'bg-gradient-to-r from-emerald-600 to-emerald-400 dark:from-emerald-500 dark:to-emerald-400': accent === 'emerald',
            'bg-gradient-to-r from-rose-600 to-rose-400 dark:from-rose-500 dark:to-rose-400': accent === 'rose',
            'bg-gradient-to-r from-amber-600 to-amber-400 dark:from-amber-500 dark:to-amber-400': accent === 'amber',
            'bg-gradient-to-r from-violet-600 to-violet-400 dark:from-violet-500 dark:to-violet-400': accent === 'violet',
            'bg-gradient-to-r from-cyan-600 to-cyan-400 dark:from-cyan-500 dark:to-cyan-400': accent === 'cyan'
          }"
          :style="{ width: `${percentage}%` }"
        ></div>
      </div>
      <div class="flex justify-between mt-1.5">
        <span class="text-[10px] text-slate-500 dark:text-slate-600 font-medium">{{ min }}</span>
        <span class="text-[10px] text-slate-500 dark:text-slate-600 font-medium">{{ max }}</span>
      </div>
    </div>
  </div>
</template>
