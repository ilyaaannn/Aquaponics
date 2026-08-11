<script setup lang="ts">
/**
 * App.vue — Root component
 * Layout: Immersive fullscreen BG + Sidebar + Header + RouterView
 * Theme: Futuristic Glassmorphism with real-world aquaponics background
 */
import Sidebar from './components/Sidebar.vue'
import Header from './components/Header.vue'
import { useRoute } from 'vue-router'
import { computed, ref } from 'vue'
import bgImage from './assets/bg-aquaponics.png'

const route = useRoute()

const pageTitle = computed(() => {
  return (route.meta?.title as string) || 'Dashboard'
})

// === Bottom Navigation Toggle ===
const showSidebar = ref(true)

function toggleSidebar(): void {
  showSidebar.value = !showSidebar.value
}
</script>

<template>
  <div class="relative h-screen w-screen overflow-hidden text-white">
    <!-- Immersive Fullscreen Background -->
    <div
      class="absolute inset-0 bg-cover bg-center bg-no-repeat"
      :style="{ backgroundImage: `url(${bgImage})` }"
    >
      <!-- Dark overlay for readability in outdoor environment -->
      <div class="absolute inset-0 bg-slate-950/40 backdrop-blur-sm"></div>
    </div>

    <!-- Main Layout (over background) -->
    <div class="relative z-10 flex flex-col h-full w-full">
      <!-- Main Content Area -->
      <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
        <!-- Header -->
        <Header>
          <template #title>{{ pageTitle }}</template>
        </Header>

        <!-- Page Content with transition -->
        <main class="flex-1 overflow-hidden pb-4 relative">
          <router-view v-slot="{ Component }">
            <transition name="page" mode="out-in">
              <component :is="Component" />
            </transition>
          </router-view>
          
          <!-- Floating Toggle Sidebar Button -->
          <button
            @click="toggleSidebar"
            class="absolute bottom-4 right-6 z-[60] w-10 h-10 rounded-full flex items-center justify-center transition-all duration-300 shadow-lg border backdrop-blur-md"
            :class="showSidebar ? 'bg-white/10 text-white/50 border-white/10 hover:bg-white/20 hover:text-white' : 'bg-neon-cyan/20 text-neon-cyan border-neon-cyan/30 shadow-[0_0_15px_rgba(51,238,255,0.3)] hover:bg-neon-cyan/30'"
            :title="showSidebar ? 'Sembunyikan Navigasi' : 'Tampilkan Navigasi'"
          >
            <!-- Chevron Down when shown -->
            <svg v-if="showSidebar" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M6 9l6 6 6-6"/>
            </svg>
            <!-- Chevron Up when hidden -->
            <svg v-else class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M18 15l-6-6-6 6"/>
            </svg>
          </button>
        </main>
      </div>

      <!-- Bottom Nav -->
      <transition name="sidebar">
        <Sidebar v-show="showSidebar" class="z-50 shrink-0" />
      </transition>
    </div>

    <!-- Ambient glow particles (decorative) -->
    <div class="absolute top-1/4 left-1/4 w-96 h-96 bg-aqua-500/10 rounded-full blur-3xl animate-pulse-slow pointer-events-none"></div>
    <div class="absolute bottom-1/4 right-1/4 w-80 h-80 bg-ocean-500/10 rounded-full blur-3xl animate-pulse-slow pointer-events-none" style="animation-delay: 1s;"></div>
  </div>
</template>
