import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        entryFileNames: `clover-[name].js`,
        chunkFileNames: `clover-[name].js`,
        assetFileNames: `[name].[ext]`
      }
    }
  },
})
