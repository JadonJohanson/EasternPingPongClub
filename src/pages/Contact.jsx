import { useState } from 'react'
import { Link } from 'react-router-dom'
import FormField from '../components/FormField.jsx'
import Honeypot from '../components/Honeypot.jsx'
import { sendContactMessage } from '../data/contactMessages.js'
import {
  cleanContact,
  MAX_MESSAGE_LENGTH,
  validateContact,
} from '../lib/contactValidation.js'
import { isSupabaseConfigured } from '../lib/supabase.js'
import './Contact.css'

const EMPTY_FORM = { name: '', email: '', message: '' }

// Same pattern as the Sign Up page: React remembers what was typed, checks it
// when the visitor presses Send, then saves it and shows a thank-you.
export default function Contact() {
  const [values, setValues] = useState(EMPTY_FORM)
  const [errors, setErrors] = useState({})
  // 'idle', 'sending', 'done' or 'failed'.
  const [status, setStatus] = useState('idle')
  // The hidden bot-trap field (see the Honeypot component).
  const [website, setWebsite] = useState('')

  const update = (field) => (event) => {
    setValues((current) => ({ ...current, [field]: event.target.value }))
  }

  async function handleSubmit(event) {
    event.preventDefault()
    if (status === 'sending') return

    const problems = validateContact(values)
    setErrors(problems)
    if (Object.keys(problems).length > 0) return

    setStatus('sending')

    // A bot filled the hidden field: pretend it worked, send nothing.
    if (website) {
      setStatus('done')
      return
    }

    try {
      await sendContactMessage(cleanContact(values))
      setValues(EMPTY_FORM)
      setStatus('done')
    } catch (error) {
      console.error('Contact message failed', error)
      setStatus('failed')
    }
  }

  if (status === 'done') {
    return (
      <div className="page contact">
        <h1>Message sent</h1>
        <p>
          Thanks for reaching out! An officer will get back to you by email.
        </p>
        <Link to="/" className="button">
          Back to home
        </Link>
      </div>
    )
  }

  return (
    <div className="page contact">
      <h1>Contact</h1>
      <p className="muted">
        Questions about the club? Send the officers a message. Only officers can
        read it.
      </p>

      {!isSupabaseConfigured && (
        <p className="card" role="status">
          The database is not connected yet, so messages cannot be sent. Add
          your Supabase settings to a .env file (see .env.example).
        </p>
      )}

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

        <FormField
          id="email"
          label="Your email"
          hint="Where should we reply?"
          error={errors.email}
        >
          {(describedBy) => (
            <input
              id="email"
              type="email"
              autoComplete="email"
              value={values.email}
              onChange={update('email')}
              aria-invalid={Boolean(errors.email)}
              aria-describedby={describedBy}
            />
          )}
        </FormField>

        <FormField id="message" label="Message" error={errors.message}>
          {(describedBy) => (
            <textarea
              id="message"
              value={values.message}
              onChange={update('message')}
              aria-invalid={Boolean(errors.message)}
              aria-describedby={describedBy}
            />
          )}
        </FormField>
        {/* Counts down so visitors know how much room is left. */}
        <p className="contact__count muted" aria-live="polite">
          {values.message.length} / {MAX_MESSAGE_LENGTH}
        </p>

        <Honeypot value={website} onChange={setWebsite} />

        {status === 'failed' && (
          <p className="contact__failed" role="alert">
            Sorry, we could not send your message. Please check your connection
            and try again.
          </p>
        )}

        <button
          type="submit"
          className="button contact__submit"
          disabled={status === 'sending' || !isSupabaseConfigured}
        >
          {status === 'sending' ? 'Sending…' : 'Send message'}
        </button>
      </form>
    </div>
  )
}
