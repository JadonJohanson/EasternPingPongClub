# Database guide

All club data lives in Supabase (Postgres). The database structure and its
security rules are written as **migration files** in `supabase/migrations/`,
never changed by hand in the Supabase dashboard. Tests in
`supabase/tests/database/` prove the security rules work.

## Where it lives

| Thing            | Value                                                                    |
| ---------------- | ------------------------------------------------------------------------ |
| Supabase project | `EasternPingPongClub-dev` (the **dev** project)                          |
| Project ref      | `dbuzjfoqhglaszkvdbww`                                                   |
| Region           | East US (North Virginia), `us-east-1`                                    |
| Postgres version | 17 (matches `major_version` in `supabase/config.toml`)                   |
| Plan             | Free (pauses after 7 days of inactivity; a keep-alive comes in Phase 11) |

A separate **prod** project is created later, once the structure is stable.

## The rules every table follows

1. **Row Level Security (RLS) is on for every table.** With RLS on, a row is
   only visible or changeable if a _policy_ allows it. A test fails if any
   table in `public` is missing RLS.
2. **Grants first, then policies.** This project has "Automatically expose
   new tables" switched off, so the website cannot touch a table until a
   migration grants it. Each table starts with
   `revoke all ... from anon, authenticated`, then grants only what is needed.
   Grants say which _kinds_ of action are allowed; policies say which _rows_.
3. **Officers come from a table, not from user metadata.** A user can edit
   their own metadata, so it can never be trusted. `private.is_officer()`
   looks the logged-in user up in the `officers` table.
4. **Tests for every table**: who is allowed and who is denied, for a visitor
   who is not logged in (`anon`), a logged-in non-officer, and an officer.
5. **Sign-ups are off.** Officers are created by hand (see below).

## What exists so far

| Table         | Who can read              | Who can change                                                                            |
| ------------- | ------------------------- | ----------------------------------------------------------------------------------------- |
| `players`     | everyone                  | officers (add, edit, delete)                                                              |
| `officers`    | you see only your own row | nobody through the website (added by hand)                                                |
| `settings`    | everyone                  | officers can edit (one row, never added or deleted)                                       |
| `matches`     | everyone                  | visitors can ADD casual matches; officers do the rest                                     |
| `match_games` | everyone                  | visitors can ADD games to a casual match made in the last 2 minutes; officers do the rest |

`settings` holds the starting rating (default 1000) and K factor (default 32).

### matches and match_games (step 2b)

- One flat `matches` table. `match_type` is `casual` or `tournament`.
  `tournament_id` is filled only for tournament rows (its foreign key is added
  in 2c when `tournaments` exists).
- Each side is exactly one of a player (`player_a_id` / `player_b_id`) or a typed
  guest name. Tournament matches need two real players. A player cannot play
  themselves, and a match needs at least one club player.
- `match_games` holds one row per game. A game is to 11, win by 2 (11-0 to
  11-9, or a 2-point gap above 11). The winner is worked out from the games.
- Visitors may insert casual matches only, and only the Play-form columns
  (they cannot set `id`, `created_at` or `tournament_id`). `created_at` must equal
  the current time and `played_at` must be within the last 30 days.
- Visitors may add games only to a casual match created in the last 2 minutes,
  so nobody can alter older results. The website saves the match, then its
  games, in two quick requests.
- Known limit: the database does not force a match to have a sensible number
  of games. The Phase 5 Play form (with its CAPTCHA and checks) handles that,
  and officers can fix mistakes.
- A player who has matches cannot be deleted (foreign key). Rename instead.

### Supabase's automatic-RLS helper

"Enable automatic RLS" makes Supabase create `public.rls_auto_enable()`, which
switches RLS on for new tables. A migration removes everyone's permission to
call it (Security Advisor warning). The automatic behavior still works.

## What is planned next

| Step | Adds                                                    |
| ---- | ------------------------------------------------------- |
| 2c   | `tournaments`, `tournament_entries`, `rating_history`   |
| 2d   | `events`, `signups`, `contact_messages`, fake seed data |

### Decisions behind 2b

- **Game-by-game scores.** Each game's points are stored (for example 11-7,
  9-11, 11-8) in `match_games`, one row per game. The match's games-won count
  is derived from those.
- **Guests are typed names, not players.** On a casual match a side is either
  a player (`player_id`) or a typed guest name. Guests never get a row in
  `players`, so that table stays writable by officers only. Guests do not
  appear in rankings or head-to-head records.
- **Spam protection comes in Phase 5.** The public "add casual match" rule is
  tightened then, when the CAPTCHA approach is chosen.

## Running things

### Run the database tests on your computer

This needs [Docker Desktop](https://www.docker.com/products/docker-desktop/)
installed and running. If you would rather not install it, skip this:
GitHub runs the same tests on every pull request.

```bash
npm install                # first time only
npx supabase start         # starts a throwaway local database (first run downloads images)
npx supabase test db       # runs everything in supabase/tests/database
npx supabase stop          # shuts it down
```

### Apply migrations to the dev project

Do this **after** a pull request with new migrations is merged. It needs your
database password, which you type yourself. Never paste it into chat.

```bash
npx supabase login                                      # opens a browser to authorize the CLI
npx supabase link --project-ref dbuzjfoqhglaszkvdbww    # may ask for the database password
npx supabase db push                                    # lists what will run, asks you to confirm
```

`db push` only applies migrations that have not been applied yet, so it is
safe to run again.

### Add an officer

Sign-ups are off, so an officer is created in two steps:

1. Supabase dashboard → **Authentication → Users → Add user → Create new
   user** (email and a password you choose, tick auto-confirm).
2. Dashboard → **SQL Editor**, then run this with that user's id (shown in the
   Users list):

   ```sql
   insert into public.officers (user_id) values ('PASTE-THE-USER-ID-HERE');
   ```

Open sign-ups on the hosted project are turned off in the dashboard under
**Authentication → Sign In / Providers** ("Allow new users to sign up").
`supabase/config.toml` already has them off for local work. We do this before
the first officer login exists (Phase 6).

## Adding a table (checklist)

1. `npx supabase migration new <short_name>` creates a new empty file.
2. In that file: `create table`, `enable row level security`,
   `revoke all ... from anon, authenticated`, the exact `grant`s, and one
   policy per allowed action.
3. Add the table to the tests: its exact privileges in
   `000_rls_and_grants.test.sql` and its allow/deny behaviour in a new test
   file.
4. Open a pull request. CI must pass before merging.
