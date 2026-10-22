import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter } from 'react-router-dom'
import './theme.css'
import './index.css'
import App from './App.jsx'

// HashRouter keeps the page name after a "#" in the URL
// (for example .../EasternPingPongClub/#/players).
// GitHub Pages cannot serve a different file for every page name, so with a
// normal router, refreshing the browser on /players would show a 404 error.
// Everything after the "#" is handled by the browser alone, so refresh and
// shared links always work.
createRoot(document.getElementById('root')).render(
  <StrictMode>
    <HashRouter>
      <App />
    </HashRouter>
  </StrictMode>,
)
