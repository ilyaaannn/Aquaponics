<script setup lang="ts">
/**
 * Sidebar — Navigation sidebar component
 * Futuristic glassmorphism design with neon active indicators.
 */
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'

const route = useRoute()
const router = useRouter()

interface NavItem {
  name: string
  path: string
  icon: string
  label: string
}

const navItems: NavItem[] = [
  { name: 'dashboard', path: '/', icon: 'dashboard', label: 'Dashboard' },
  { name: 'history', path: '/history', icon: 'history', label: 'History' },
  { name: 'settings', path: '/settings', icon: 'settings', label: 'Settings' }
]

const currentRoute = computed(() => route.name)

function navigateTo(path: string): void {
  router.push(path)
}
</script>

<template>
  <aside class="w-full h-14 md:h-[60px] flex flex-row bg-slate-950/90 backdrop-blur-3xl border-t-2 border-white/30 shadow-[0_-10px_40px_rgba(0,0,0,0.5)] transition-all duration-300">
    <!-- Navigation Items -->
    <nav class="flex-1 flex flex-row justify-around items-center px-2 sm:px-6 md:px-12">
      <button
        v-for="item in navItems"
        :key="item.name"
        :class="[
          'relative w-16 sm:w-24 md:w-32 flex flex-col items-center justify-center gap-1 py-1 rounded-2xl transition-all duration-300',
          currentRoute === item.name
            ? 'text-white'
            : 'text-white/60 hover:text-white/90 hover:bg-white/5'
        ]"
        @click="navigateTo(item.path)"
      >
        <!-- Active Pill Background (Android style) -->
        <div
          v-if="currentRoute === item.name"
          class="absolute inset-0 bg-white/10 rounded-2xl border border-white/20 shadow-[inset_0_0_20px_rgba(255,255,255,0.05)]"
        ></div>

        <!-- Neon active indicator top border (Alternative to pill) -->
        <div
          v-if="currentRoute === item.name"
          class="absolute top-0 left-1/2 -translate-x-1/2 w-10 h-[3px] rounded-b-full"
          style="background: linear-gradient(90deg, #39ff14, #00e5ff); box-shadow: 0 0 10px rgba(57, 255, 20, 0.8);"
        ></div>

        <!-- Icons -->
        <div class="relative z-10 p-1 rounded-xl transition-all duration-300"
             :class="currentRoute === item.name ? 'bg-gradient-to-br from-neon-green/20 to-neon-cyan/20' : ''">
          <svg v-if="item.icon === 'dashboard'" class="w-4 h-4 md:w-5 md:h-5 flex-shrink-0" :class="currentRoute === item.name ? 'text-neon-green drop-shadow-md' : 'text-white'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <rect x="3" y="3" width="7" height="7" rx="1.5" />
            <rect x="14" y="3" width="7" height="7" rx="1.5" />
            <rect x="3" y="14" width="7" height="7" rx="1.5" />
            <rect x="14" y="14" width="7" height="7" rx="1.5" />
          </svg>
          <svg v-else-if="item.icon === 'history'" class="w-4 h-4 md:w-5 md:h-5 flex-shrink-0" :class="currentRoute === item.name ? 'text-neon-cyan drop-shadow-md' : 'text-white'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 7v5l3 3" stroke-linecap="round" />
          </svg>
          <svg v-else-if="item.icon === 'settings'" class="w-4 h-4 md:w-5 md:h-5 flex-shrink-0" :class="currentRoute === item.name ? 'text-white drop-shadow-md' : 'text-white'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <circle cx="12" cy="12" r="3" />
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
          </svg>
        </div>
        <span class="relative z-10 text-[9px] md:text-[10px] font-bold tracking-wide" :class="currentRoute === item.name ? 'text-white' : 'text-white/80'">{{ item.label }}</span>
      </button>
    </nav>
  </aside>
</template>
