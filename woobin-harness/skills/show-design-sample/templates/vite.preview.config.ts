import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath, URL } from 'node:url'

const previewRoot = fileURLToPath(new URL('.', import.meta.url))

export default defineConfig({
  root: previewRoot,
  base: './',
  plugins: [react()],
  resolve: { alias: { '@': fileURLToPath(new URL('../src', import.meta.url)) } },
  build: {
    outDir: fileURLToPath(new URL('./.dist', import.meta.url)),
    emptyOutDir: true,
  },
})
