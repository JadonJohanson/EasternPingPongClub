import { Link } from 'react-router-dom'

// Shown when the address matches none of the routes in App.jsx.
export default function NotFound() {
  return (
    <div className="page">
      <h1>Page not found</h1>
      <p className="muted">We could not find that page.</p>
      <Link to="/">Back to the home page</Link>
    </div>
  )
}
