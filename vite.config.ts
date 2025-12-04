import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
  },
  // Ensure env vars are exposed correctly if needed, though process.env usually works in Vite with define
  define: {
    'process.env': process.env
  }
})