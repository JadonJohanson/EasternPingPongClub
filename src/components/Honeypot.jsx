import './Honeypot.css'

// A hidden form field that only bots fill in. Real visitors never see it
// (it is moved off-screen and hidden from screen readers), so if it has a
// value when the form is submitted, the form quietly sends nothing.
// A proper CAPTCHA is planned for later; this stops the simplest bots.
export default function Honeypot({ value, onChange }) {
  return (
    <div className="honeypot" aria-hidden="true">
      <label htmlFor="website">Leave this empty</label>
      <input
        id="website"
        type="text"
        tabIndex={-1}
        autoComplete="off"
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
    </div>
  )
}
