import { Link } from 'react-router-dom'
import { CLUB_NAME } from '../siteConfig.js'
import './Home.css'

export default function Home() {
  return (
    <div className="page home">
      <h1 className="home__title">{CLUB_NAME}</h1>

      {/* Phase 9 replaces this with the real next event, read from the
          database. */}
      <section className="card home__next-event" aria-label="Next event">
        <p className="home__label">Next event</p>
        <p className="home__event-name">Coming soon</p>
        <p className="muted">Check back for the next club night.</p>
      </section>

      {/* Link is React Router's version of <a>. It changes the page without
          reloading the whole site. */}
      <Link to="/signup" className="button">
        Join us
      </Link>
    </div>
  )
}
