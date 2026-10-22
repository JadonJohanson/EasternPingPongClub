import { useState } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import { CLUB_NAME } from '../siteConfig.js'
import './Layout.css'

// Every link in the sidebar. To add or rename a page in the menu, edit this
// list (and add a matching <Route> in App.jsx).
const NAV_ITEMS = [
  { to: '/', label: 'Home' },
  { to: '/schedule', label: 'Schedule' },
  { to: '/results', label: 'Results' },
  { to: '/players', label: 'Players' },
  { to: '/play', label: 'Play' },
  { to: '/info', label: 'Info' },
  { to: '/signup', label: 'Sign Up' },
  { to: '/contact', label: 'Contact' },
]

// The width at which the sidebar stops floating over the page (phones) and
// starts sitting beside it (laptops). Keep in sync with Layout.css.
const DESKTOP_QUERY = '(min-width: 900px)'

function isDesktop() {
  return window.matchMedia(DESKTOP_QUERY).matches
}

// The frame around every page: a top bar with a hamburger button, the
// collapsible sidebar, and the page itself.
export default function Layout() {
  // useState remembers a value between renders. Here: is the sidebar open?
  // It starts open on a laptop and closed on a phone. The function form
  // `() => isDesktop()` makes React run the check only once, on first load.
  const [isOpen, setIsOpen] = useState(() => isDesktop())

  // On a phone, tapping a link should close the menu so the page is visible.
  function handleNavClick() {
    if (!isDesktop()) setIsOpen(false)
  }

  return (
    <div className={`layout ${isOpen ? 'layout--open' : ''}`}>
      <header className="topbar">
        <button
          type="button"
          className="topbar__menu"
          onClick={() => setIsOpen(!isOpen)}
          aria-label={isOpen ? 'Close menu' : 'Open menu'}
          aria-expanded={isOpen}
          aria-controls="sidebar"
        >
          {/* Three bars drawn with a text character keeps this dependency-free. */}
          ☰
        </button>
        <span className="topbar__title">{CLUB_NAME}</span>
      </header>

      <nav id="sidebar" className="sidebar" aria-label="Main">
        <ul>
          {NAV_ITEMS.map((item) => (
            <li key={item.to}>
              {/* NavLink adds the class "active" to the link of the page you
                  are on, which the CSS uses to highlight it. `end` stops
                  "Home" from counting as active on every page. */}
              <NavLink
                to={item.to}
                end={item.to === '/'}
                onClick={handleNavClick}
              >
                {item.label}
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>

      {/* On phones, a dark layer behind the open menu. Tapping it closes the menu. */}
      <div
        className="backdrop"
        onClick={() => setIsOpen(false)}
        aria-hidden="true"
      />

      <main className="content">
        {/* Outlet is where React Router puts the current page. */}
        <Outlet />
      </main>
    </div>
  )
}
