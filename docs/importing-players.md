# Adding players from a spreadsheet

Only a player's **name** goes into the public `players` table. Emails and
Eastern IDs stay out of it (they live only in the officer-only `signups` table).

1. Save your list as CSV with the columns `name,email,eastern_id,skill_level`
   (same rules as the Sign Up form). `sample-data/fake-members.csv` is a
   made-up example.
2. Run (no passwords or keys needed, it only reads the file):
   `node scripts/csv-to-players-sql.mjs members.csv --out add-players.sql`
   Bad rows are listed with their line number and skipped.
3. Open the Supabase dashboard for the dev project, SQL editor, paste the
   contents of `add-players.sql`, and run it.
4. Running it twice is safe: names that already exist are skipped.

Keep real member files on your own computer, never in the repo. Delete the fake
sample players from the dev database before real launch.
