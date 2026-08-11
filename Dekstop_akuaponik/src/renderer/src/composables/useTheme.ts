/**
 * useTheme — Composable to manage Light/Dark mode state.
 */
import { ref, onMounted, watch } from 'vue'

const isDarkMode = ref(true) // Default to dark mode

export function useTheme() {
  function toggleTheme() {
    isDarkMode.value = !isDarkMode.value
  }

  function applyTheme() {
    if (isDarkMode.value) {
      document.documentElement.classList.add('dark')
      localStorage.setItem('theme', 'dark')
    } else {
      document.documentElement.classList.remove('dark')
      localStorage.setItem('theme', 'light')
    }
  }

  onMounted(() => {
    // Check local storage or system preference on load
    const savedTheme = localStorage.getItem('theme')
    if (savedTheme) {
      isDarkMode.value = savedTheme === 'dark'
    } else {
      isDarkMode.value = window.matchMedia('(prefers-color-scheme: dark)').matches
    }
    applyTheme()
  })

  watch(isDarkMode, () => {
    applyTheme()
  })

  return {
    isDarkMode,
    toggleTheme
  }
}
