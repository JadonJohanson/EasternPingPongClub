import './AsyncState.css'

// Shows the right thing while data is loading, when it failed, or when there
// is nothing to show. Pages wrap their data in this so every page behaves the
// same way (the "loading / empty / error states" from the build plan).
//
//   <AsyncState status={status} isEmpty={!data} onRetry={retry}
//               emptyMessage="No events yet.">
//     ...drawn only when there is data...
//   </AsyncState>
export default function AsyncState({
  status,
  isEmpty = false,
  onRetry,
  emptyMessage = 'Nothing here yet.',
  errorMessage = 'Something went wrong loading this. Please try again.',
  children,
}) {
  if (status === 'loading') {
    // role="status" lets screen readers announce the change politely.
    return (
      <p className="async-state muted" role="status">
        Loading…
      </p>
    )
  }

  if (status === 'error') {
    return (
      <div className="async-state" role="alert">
        <p>{errorMessage}</p>
        {onRetry && (
          <button
            type="button"
            className="async-state__retry"
            onClick={onRetry}
          >
            Try again
          </button>
        )}
      </div>
    )
  }

  if (isEmpty) {
    return <p className="async-state muted">{emptyMessage}</p>
  }

  return children
}
