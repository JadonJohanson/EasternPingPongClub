import { validateSignup } from '../../src/lib/signupValidation.js'

// Helpers for turning a members spreadsheet (saved as CSV) into SQL that adds
// the people to the `players` table. Kept in its own file, away from the
// command-line script, so it can be unit tested.

// Reads CSV text into a list of rows, each an object keyed by the header names.
// Handles quoted values ("Last, First"), doubled quotes ("") inside quotes,
// Windows line endings and the invisible marker Excel adds at the very start.
export function parseCsv(text) {
  const clean = text.replace(/^\uFEFF/, '')
  const rows = []
  let row = []
  let field = ''
  let inQuotes = false

  for (let i = 0; i < clean.length; i++) {
    const char = clean[i]
    if (inQuotes) {
      if (char === '"' && clean[i + 1] === '"') {
        field += '"'
        i++
      } else if (char === '"') {
        inQuotes = false
      } else {
        field += char
      }
    } else if (char === '"') {
      inQuotes = true
    } else if (char === ',') {
      row.push(field)
      field = ''
    } else if (char === '\n' || char === '\r') {
      if (char === '\r' && clean[i + 1] === '\n') i++
      row.push(field)
      rows.push(row)
      row = []
      field = ''
    } else {
      field += char
    }
  }
  // The last line may not end with a newline.
  if (field !== '' || row.length > 0) {
    row.push(field)
    rows.push(row)
  }

  const [header = [], ...body] = rows.filter((r) =>
    r.some((cell) => cell.trim() !== ''),
  )
  const keys = header.map((name) => name.trim().toLowerCase())
  return body.map((cells) =>
    Object.fromEntries(keys.map((key, i) => [key, (cells[i] ?? '').trim()])),
  )
}

// Checks every row with the SAME rules as the Sign Up form, and works out
// which names to add. Returns { names, problems } where each problem says which
// line of the file (line 1 is the header) and what is wrong.
export function prepareImport(rows) {
  const names = []
  const problems = []
  const seen = new Set()

  rows.forEach((row, index) => {
    const line = index + 2
    const errors = validateSignup({
      name: row.name ?? '',
      email: row.email ?? '',
      easternId: row.eastern_id ?? '',
      skillLevel: (row.skill_level ?? '').toLowerCase(),
    })
    // A player's display name is limited to 80 characters (database rule).
    const name = (row.name ?? '').trim()
    if (name.length > 80) errors.name = 'Name is longer than 80 characters.'

    if (Object.keys(errors).length > 0) {
      problems.push({ line, message: Object.values(errors).join(' ') })
      return
    }

    const key = name.toLowerCase()
    if (seen.has(key)) {
      problems.push({
        line,
        message: `"${name}" appears more than once in the file.`,
      })
      return
    }
    seen.add(key)
    names.push(name)
  })

  return { names, problems }
}

// Builds one INSERT statement. Names that already exist in `players`
// (ignoring upper/lower case) are skipped, so running it twice is harmless.
export function toSql(names) {
  if (names.length === 0) return '-- Nothing to add.\n'
  // In SQL text, a single quote is written twice: O'Connor becomes 'O''Connor'.
  const values = names
    .map((name) => `  ('${name.replaceAll("'", "''")}')`)
    .join(',\n')
  return `insert into public.players (display_name)
select v.display_name
from (values
${values}
) as v (display_name)
where not exists (
  select 1 from public.players p where lower(p.display_name) = lower(v.display_name)
);
`
}
