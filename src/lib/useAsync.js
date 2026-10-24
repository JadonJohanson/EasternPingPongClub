import { useCallback, useEffect, useState } from 'react'

// A small "hook" that runs an async function (like a database request) and
// reports where it is:  { status, data, error, retry }
//
//   status 'loading'  the request is running
//   status 'error'    it failed (see `error`)
//   status 'success'  it finished (see `data`, which can be null or empty)
//
// A hook is a function whose name starts with "use" that can remember things
// (useState) and run code when a component appears (useEffect). Pages call
// this hook, then draw something different for each status.
export function useAsync(asyncFunction) {
  const [state, setState] = useState({
    status: 'loading',
    data: null,
    error: null,
  })
  // Changing this number makes the effect below run again (the "Try again" button).
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    // If the visitor leaves the page before the request finishes, we must not
    // update a page that is gone. `cancelled` guards against that.
    let cancelled = false

    asyncFunction().then(
      (data) => {
        if (!cancelled) setState({ status: 'success', data, error: null })
      },
      (error) => {
        if (!cancelled) setState({ status: 'error', data: null, error })
      },
    )

    return () => {
      cancelled = true
    }
  }, [asyncFunction, attempt])

  // "Try again": show the loading state right away, then run the request again.
  // (The loading state is set here, not inside the effect, which keeps React's
  // lint rules happy and the code easy to follow.)
  const retry = useCallback(() => {
    setState({ status: 'loading', data: null, error: null })
    setAttempt((n) => n + 1)
  }, [])
  return { ...state, retry }
}
