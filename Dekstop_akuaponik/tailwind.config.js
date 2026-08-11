/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/renderer/index.html', './src/renderer/src/**/*.{vue,js,ts,jsx,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      screens: {
        'xs': '480px',
        '3xl': '1920px',
      },
      colors: {
        // Aquaponik brand palette
        aqua: {
          50: '#edfcf5',
          100: '#d3f8e6',
          200: '#aaf0d1',
          300: '#73e3b5',
          400: '#3acd94',
          500: '#17b57a',
          600: '#0b9163',
          700: '#097451',
          800: '#0b5c42',
          900: '#0a4b37',
          950: '#052a1f'
        },
        ocean: {
          50: '#eff8ff',
          100: '#daeeff',
          200: '#bde2ff',
          300: '#90d2ff',
          400: '#5cb8ff',
          500: '#3696fc',
          600: '#2078f2',
          700: '#1862de',
          800: '#1a4fb4',
          900: '#1b448e',
          950: '#152b56'
        },
        neon: {
          green: '#54ff33',
          cyan: '#33eeff',
          amber: '#ffbd33',
          red: '#ff4d79',
          pink: '#ff6699',
          blue: '#5294ff'
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'Fira Code', 'monospace']
      },
      boxShadow: {
        glow: '0 0 20px rgba(57, 255, 20, 0.3)',
        'glow-cyan': '0 0 20px rgba(0, 229, 255, 0.3)',
        'glow-blue': '0 0 20px rgba(54, 150, 252, 0.3)',
        'glow-lg': '0 0 40px rgba(57, 255, 20, 0.2)',
        'neon-green': '0 0 12px rgba(57, 255, 20, 0.5), 0 0 4px rgba(57, 255, 20, 0.3)',
        'neon-cyan': '0 0 12px rgba(0, 229, 255, 0.5), 0 0 4px rgba(0, 229, 255, 0.3)',
        'neon-amber': '0 0 12px rgba(255, 171, 0, 0.5), 0 0 4px rgba(255, 171, 0, 0.3)',
        'neon-red': '0 0 12px rgba(255, 23, 68, 0.5), 0 0 4px rgba(255, 23, 68, 0.3)',
        glass: '0 8px 32px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.05)',
        'glass-lg': '0 16px 48px rgba(0, 0, 0, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.06)',
      },
      backgroundImage: {
        'gradient-aqua': 'linear-gradient(135deg, #39ff14 0%, #00e5ff 100%)',
        'gradient-neon': 'linear-gradient(135deg, #39ff14 0%, #00e5ff 50%, #2979ff 100%)',
        'gradient-dark': 'linear-gradient(135deg, #0a0f1a 0%, #152b56 100%)',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'pulse-neon': 'neonPulse 2s ease-in-out infinite',
        'fade-in': 'fadeIn 0.6s ease-out',
        'slide-up': 'slideUp 0.5s ease-out',
        'slide-in-left': 'slideInLeft 0.3s ease-out',
        'float': 'float 6s ease-in-out infinite',
        'float-slow': 'float 8s ease-in-out infinite',
        'glow': 'glowPulse 2s ease-in-out infinite alternate',
        'spin-slow': 'spin 8s linear infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'scale(0.95)' },
          '100%': { opacity: '1', transform: 'scale(1)' }
        },
        slideUp: {
          '0%': { transform: 'translateY(20px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' }
        },
        slideInLeft: {
          '0%': { transform: 'translateX(-20px)', opacity: '0' },
          '100%': { transform: 'translateX(0)', opacity: '1' }
        },
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-8px)' }
        },
        glowPulse: {
          '0%': { boxShadow: '0 0 5px rgba(57, 255, 20, 0.2)' },
          '100%': { boxShadow: '0 0 25px rgba(57, 255, 20, 0.5)' }
        },
        neonPulse: {
          '0%, 100%': { opacity: '1', boxShadow: '0 0 8px rgba(52, 211, 153, 0.6)' },
          '50%': { opacity: '0.85', boxShadow: '0 0 16px rgba(52, 211, 153, 0.9)' }
        }
      },
      backdropBlur: {
        xs: '2px',
      }
    }
  },
  plugins: []
}
