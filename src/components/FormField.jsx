import './FormField.css'

// One labelled form field with an optional hint and error message. Used by
// the Sign Up form and, later, the Contact and Play forms.
//
// `children` is a function that receives the `aria-describedby` text and
// returns the actual input (an <input> or <select>). Giving the input the same
// `id` makes clicking the label focus it, and `aria-describedby` links the hint
// and error text to the input so screen readers read them out.
export default function FormField({ id, label, hint, error, children }) {
  const describedBy = [hint && `${id}-hint`, error && `${id}-error`]
    .filter(Boolean)
    .join(' ')

  return (
    <div className="field">
      <label htmlFor={id} className="field__label">
        {label}
      </label>
      {hint && (
        <p id={`${id}-hint`} className="field__hint">
          {hint}
        </p>
      )}
      {children(describedBy || undefined)}
      {error && (
        <p id={`${id}-error`} className="field__error" role="alert">
          {error}
        </p>
      )}
    </div>
  )
}
