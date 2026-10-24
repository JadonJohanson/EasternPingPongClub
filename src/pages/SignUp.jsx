import { useState } from 'react'
import { Link } from 'react-router-dom'
import FormField from '../components/FormField.jsx'
import Honeypot from '../components/Honeypot.jsx'
import { submitSignup } from '../data/signups.js'
import { isSupabaseConfigured } from '../lib/supabase.js'
import {
  SKILL_LEVELS,
  cleanSignup,
  validateSignup,
} from '../lib/signupValidation.js'
import './SignUp.css'

const EMPTY_FORM = { name: '', email: '', easternId: '', skillLevel: '' }

export default function SignUp() {
  // `values` remembers what the visitor typed. Each input below is "controlled":
  // React owns its value and updates it on every keystroke.
  const [values, setValues] = useState(EMPTY_FORM)
  // One message per field with a problem, e.g. { email: '...' }.
  const [errors, setErrors] = useState({})
  // 'idle' (typing), 'sending', 'done' (success) or 'failed' (server problem).
  const [status, setStatus] = useState('idle')
  // A hidden field that real visitors never see or fill in. Simple bots fill
  // in every field, so a filled-in value means "probably a bot".
  const [website, setWebsite] = useState('')

  // Returns a function that saves what was typed into the given field.
  const update = (field) => (event) => {
    setValues((current) => ({ ...current, [field]: event.target.value }))
  }

  async function handleSubmit(event) {
    // Stops the browser's default form behaviour (reloading the page).
    event.preventDefault()
    if (status === 'sending') return // ignore double taps

    const problems = validateSignup(values)
    setErrors(problems)
    if (Object.keys(problems).length > 0) return

    setStatus('sending')

    // A bot filled the hidden field: pretend it worked, but send nothing.
    if (website) {
      setStatus('done')
      return
    }

    try {
      await submitSignup(cleanSignup(values))
      setValues(EMPTY_FORM)
      setStatus('done')
    } catch (error) {
      console.error('Sign up failed', error)
      setStatus('failed')
    }
  }

  if (status === 'done') {
    return (
      <div className="page signup">
        <h1>You&apos;re signed up!</h1>
        <p>
          Thanks for joining. An officer will be in touch, and you can check the
          home page for the next event.
        </p>
        <Link to="/" className="button">
          Back to home
        </Link>
      </div>
    )
  }

  return (
    <div className="page signup">
      <h1>Sign Up</h1>
      <p className="muted">
        Join the club! Your email and Eastern ID are only seen by club officers.
      </p>

      {!isSupabaseConfigured && (
        <p className="card" role="status">
          The database is not connected yet, so the form cannot be submitted.
          Add your Supabase settings to a .env file (see .env.example).
        </p>
      )}

      {/* noValidate turns off the browser's own pop-up messages, so ours (which
          match the database rules) are the ones shown. */}
      <form onSubmit={handleSubmit} noValidate>
        <FormField id="name" label="Name" error={errors.name}>
          {(describedBy) => (
            <input
              id="name"
              type="text"
              autoComplete="name"
              value={values.name}
              onChange={update('name')}
              aria-invalid={Boolean(errors.name)}
              aria-describedby={describedBy}
            />
          )}
        </FormField>

        <FormField id="email" label="School email" error={errors.email}>
          {(describedBy) => (
            <input
              id="email"
              type="email"
              autoComplete="email"
              placeholder="you@my.easternct.edu"
              value={values.email}
              onChange={update('email')}
              aria-invalid={Boolean(errors.email)}
              aria-describedby={describedBy}
            />
          )}
        </FormField>

        <FormField
          id="easternId"
          label="Eastern ID number"
          hint="8 digits."
          error={errors.easternId}
        >
          {(describedBy) => (
            <input
              id="easternId"
              type="text"
              // Opens the number keypad on phones. (type="number" would drop
              // leading zeros and add spinner arrows, so we do not use it.)
              inputMode="numeric"
              autoComplete="off"
              maxLength={8}
              value={values.easternId}
              onChange={update('easternId')}
              aria-invalid={Boolean(errors.easternId)}
              aria-describedby={describedBy}
            />
          )}
        </FormField>

        <FormField
          id="skillLevel"
          label="Skill level"
          error={errors.skillLevel}
        >
          {(describedBy) => (
            <select
              id="skillLevel"
              value={values.skillLevel}
              onChange={update('skillLevel')}
              aria-invalid={Boolean(errors.skillLevel)}
              aria-describedby={describedBy}
            >
              <option value="">Choose one…</option>
              {SKILL_LEVELS.map((level) => (
                <option key={level.value} value={level.value}>
                  {level.label}
                </option>
              ))}
            </select>
          )}
        </FormField>

        {/* Hidden field for bots (see the comment on `website` above). */}
        <Honeypot value={website} onChange={setWebsite} />

        {status === 'failed' && (
          <p className="signup__failed" role="alert">
            Sorry, we could not send your sign up. Please check your connection
            and try again.
          </p>
        )}

        <button
          type="submit"
          className="button signup__submit"
          disabled={status === 'sending' || !isSupabaseConfigured}
        >
          {status === 'sending' ? 'Sending…' : 'Sign up'}
        </button>
      </form>
    </div>
  )
}
