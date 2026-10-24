// The rules for the Sign Up form. They mirror the database's own rules (the
// `signups_*_valid` checks in the migration) so visitors get a friendly message
// right away. The database still enforces them, so nobody can skip these checks
// by editing the page.

// The skill levels, in order. `value` is what is stored; `label` is shown.
export const SKILL_LEVELS = [
  { value: 'beginner', label: 'Beginner' },
  { value: 'intermediate', label: 'Intermediate' },
  { value: 'advanced', label: 'Advanced' },
  { value: 'expert', label: 'Expert' },
  { value: 'master', label: 'Master' },
]

// name@easternct.edu or name@my.easternct.edu (upper or lower case).
const SCHOOL_EMAIL = /^[^@\s]+@(my\.)?easternct\.edu$/i
// Exactly 8 digits.
const EASTERN_ID = /^[0-9]{8}$/

// Cleans up what was typed: removes spaces around the text.
export function cleanSignup(values) {
  return {
    name: values.name.trim(),
    email: values.email.trim(),
    eastern_id: values.easternId.trim(),
    skill_level: values.skillLevel,
  }
}

// Returns an object with one message per field that has a problem, e.g.
// { email: 'Please use your school email...' }. An empty object means valid.
export function validateSignup(values) {
  const clean = cleanSignup(values)
  const errors = {}

  if (clean.name.length === 0) {
    errors.name = 'Please enter your name.'
  } else if (clean.name.length > 100) {
    errors.name = 'Please use 100 characters or fewer.'
  }

  if (!SCHOOL_EMAIL.test(clean.email) || clean.email.length > 254) {
    errors.email =
      'Please use your school email (ending in @easternct.edu or @my.easternct.edu).'
  }

  if (!EASTERN_ID.test(clean.eastern_id)) {
    errors.easternId = 'Your Eastern ID is exactly 8 digits, numbers only.'
  }

  if (!SKILL_LEVELS.some((level) => level.value === clean.skill_level)) {
    errors.skillLevel = 'Please choose your skill level.'
  }

  return errors
}
