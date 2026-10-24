// Turns a members CSV into a SQL file you can paste into the Supabase SQL
// editor to add the people to the `players` table.
//
//   node scripts/csv-to-players-sql.mjs sample-data/fake-members.csv
//   node scripts/csv-to-players-sql.mjs members.csv --out add-players.sql
//
// Only the NAME is copied into `players` (that table is public). Emails and
// Eastern IDs in the file are checked but never copied anywhere.
// No passwords or keys are involved: this only reads a file and writes SQL.
import { readFileSync, writeFileSync } from 'node:fs'
import { parseCsv, prepareImport, toSql } from './lib/playersImport.js'

const args = process.argv.slice(2)
const file = args.find((arg) => !arg.startsWith('--'))
const outIndex = args.indexOf('--out')
const outFile = outIndex >= 0 ? args[outIndex + 1] : null

if (!file) {
  console.error(
    'Usage: node scripts/csv-to-players-sql.mjs <members.csv> [--out add-players.sql]',
  )
  process.exit(1)
}

const { names, problems } = prepareImport(parseCsv(readFileSync(file, 'utf8')))

for (const problem of problems) {
  console.error(`Line ${problem.line}: ${problem.message}`)
}
console.error(
  `${names.length} player(s) ready to add, ${problems.length} row(s) skipped.`,
)

// Messages go to the error stream so that, when no --out is given, the output
// on screen is just the SQL.
const sql = toSql(names)
if (outFile) {
  writeFileSync(outFile, sql)
  console.error(`Wrote ${outFile}`)
} else {
  console.log(sql)
}
process.exit(problems.length > 0 ? 2 : 0)
