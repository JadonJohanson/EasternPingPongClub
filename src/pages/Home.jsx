import { Link } from 'react-router-dom'
import NextEvent from '../components/NextEvent.jsx'
import { CLUB_NAME } from '../siteConfig.js'
import './Home.css'

export default function Home() {
  return (
    <div className="page home">
      <h1 className="home__title">{CLUB_NAME}</h1>

      {/* Reads the soonest upcoming event from the database. */}
      <NextEvent />

      {/* Link is React Router's version of <a>. It changes the page without
          reloading the whole site. */}
      <Link to="/signup" className="button">
        Join us
      </Link>
    </div>
  )
}
