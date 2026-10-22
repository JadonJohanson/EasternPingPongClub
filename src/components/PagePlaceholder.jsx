// A temporary stand-in used by pages we have not built yet. Each real page
// replaces its placeholder in a later phase of the build plan.
export default function PagePlaceholder({ title, children }) {
  return (
    <div className="page">
      <h1>{title}</h1>
      <p className="muted">{children}</p>
    </div>
  )
}
