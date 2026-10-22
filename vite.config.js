import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],

  // GitHub Pages serves this site from a sub-folder:
  //   https://jadonjohanson.github.io/EasternPingPongClub/
  // `base` tells Vite to build every asset URL (JS, CSS, images) relative to
  // that folder. If you ever move to a custom domain (like
  // easternpingpong.club), change this to '/'.
  base: '/EasternPingPongClub/',
})
