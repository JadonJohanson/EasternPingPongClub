// Rules for the Contact form. They mirror the database's `contact_*_valid`
// checks, so visitors get friendly messages and the database still has the
// final say.

export const MAX_MESSAGE_LENGTH = 2000

// Something@something.something, with no spaces. (Real email checking is
// impossible without sending an email, so we only catch obvious typos.)
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

// Removes spaces around the text and uses the database column names.
export function cleanContact(values) {
  return {
    name: values.name.trim(),
    email: values.email.trim(),
    message: values.message.trim(),
  }
}

// Returns one message per field with a problem. An empty object means valid.
export function validateContact(values) {
  const clean = cleanContact(values)
  const errors = {}

  if (clean.name.length === 0) {
    errors.name = 'Please enter your name.'
  } else if (clean.name.length > 100) {
    errors.name = 'Please use 100 characters or fewer.'
  }

  if (!EMAIL.test(clean.email) || clean.email.length > 254) {
    errors.email = 'Please enter a valid email address so we can reply.'
  }

  if (clean.message.length === 0) {
    errors.message = 'Please write a message.'
  } else if (clean.message.length > MAX_MESSAGE_LENGTH) {
    errors.message = `Please keep your message under ${MAX_MESSAGE_LENGTH} characters.`
  }

  return errors
}
