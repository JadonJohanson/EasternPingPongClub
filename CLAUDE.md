# CLAUDE.md: ECSU Ping Pong website

Instructions and project memory for Claude sessions working in this repo.
Read all of it before changing anything.

## About the owner and how to work with him

- Owner: Jadon Johanson (Computer Science and BIS double major). Strong in
  SQL and Excel, a little JavaScript, **new to React**. Wants to learn best
  practices and is willing to put in the time.
- Explain what code does as you write it (comments and short explanations),
  and keep the project readable so he can change any piece himself.
- Working style: plan first, best practices only. **Work in branches and pull
  requests; never push to `main`.** He reviews the diff before merging.
- Never ask him to paste keys, tokens, or passwords into chat. Never enter
  passwords or codes in a browser for him.

## Site requirements

- Home: large club title, the **next upcoming event** directly under it, then
  a "Join us" button that goes to Sign Up.
- Collapsible sidebar for navigation (hamburger on mobile).
- Pages: Home, Schedule, Results, Players, Play, Info, Sign Up, Contact.
- Mobile friendly is required (members use it in the gym). Installable as a
  home-screen app (PWA) later. The Play tab should log a match in about 15
  seconds on a phone.
- Players: searchable list and individual profile pages (record, rating,
  playing style, match history, head-to-head). Profiles have two sections:
  **Tournament** and **Casual**.
- Results: official tournament results plus leaderboard/rankings.
- Play: members enter casual games themselves (names + game scores), with
  casual head-to-head records. Players are picked by type-ahead from existing
  players, with a "guest / not a member yet" option.
- Info: location and map, what to bring, membership/fees, rules/code of
  conduct, officers. Contact form. Schedule with add-to-calendar links.
- Sign Up form fields: name, school email (@easternct.edu or
  @my.easternct.edu), Eastern ID (exactly 8 digits), skill level (beginner,
  intermediate, advanced, expert, master). Submissions are officer-read only.
- Later extras: photo gallery, announcements, social links, beginner's guide.
- Club name is "ECSU Ping Pong" (one constant in `src/siteConfig.js`). Colors
  are white, blue `#1F3A6E` and red `#9B2335`, all defined in ONE file
  (`src/theme.css`): blue is the main brand color, red the accent for the main
  call-to-action button. No logo yet; `public/favicon.svg` is a plain
  placeholder.

## Key design decisions (agreed)

### Tournament vs casual

- Two kinds of stats. **Tournament** stats are officer-entered and feed Elo
  and the official leaderboard. **Casual** stats are member-entered, records
  and head-to-head only, and NEVER affect rankings. No casual Elo in v1.
- One shared database. One flat results/matches table with a `match_type`
  column (`'tournament'` or `'casual'`). `tournament_id` is filled only for
  tournament rows. One shared players table, so one player ID is used
  everywhere.
- Elo is computed from `match_type = 'tournament'` rows ONLY, by **replaying**
  completed tournament results in chronological order (not stored running
  totals), so a corrected score can be re-played cleanly. Store a rating
  snapshot after each tournament for profile charts. Label ratings "club
  ratings", not USATT-equivalent. Standard Elo with a higher adjustment rate
  for new players; starting rating and K are settings.

### Tournaments

- Officer-only creation page: pick players from a dropdown (players must
  exist first), choose single or double elimination, choose seeding BY ELO or
  RANDOM.
- Elo seeding: sort by rating, traditional seeding (1v8, 4v5, 2v7, 3v6), top
  seeds get byes. Random seeding: shuffle, and assign byes randomly too.
- Snapshot each player's rating and seed number at bracket creation. Store
  the seeding method and, for random, the shuffle result. Break rating ties
  randomly and store the result. New players get a default starting rating
  and a "new" label in the preview.
- Bracket preview with drag-to-swap before "Start"; seeding locks on start.
- Score entry, automatic advancement, forfeits/withdrawals, corrections that
  reset downstream matches, locking once complete. Optional third-place match.
- Use the open-source libraries **brackets-manager.js** and
  **brackets-viewer.js** for bracket logic and rendering rather than
  hand-writing it (small React wrapper component needed). Keep one shared
  players table and the flat results table; let the library's tables hold
  bracket scaffolding and write a results row when a bracket match finishes.
- Ship single elimination first, then double.
- Unit-test seeding and byes for every player count from 2 to 32.

### Data and hosting

- Frontend: React + Vite, plain JavaScript first (TypeScript maybe later),
  deployed to GitHub Pages by GitHub Actions. Live URL:
  `https://jadonjohanson.github.io/EasternPingPongClub/`, so Vite `base` is
  `'/EasternPingPongClub/'`. Pages has no server routing, so the app uses
  **hash routes** (`HashRouter`).
- Backend: Supabase (Postgres + Auth). ALL data lives in Supabase (players,
  tournaments, brackets, matches, casual games, signups, contact messages,
  events). Excel is import/export only (bulk player import, scheduled backup
  export), never the live source of truth.
- Officer access: Supabase Auth email + password, open sign-ups OFF, officers
  added manually. Officer status comes from an `officers` table keyed to the
  Supabase user id, NOT from user metadata (users can edit their own metadata).

## Security rules (non-negotiable)

- Row Level Security on EVERY table, with explicit select/insert/update/delete
  policies. Insert policies use `WITH CHECK`.
- Public read: players, results, events, ratings.
- Public insert-only (no public update/delete) for casual games, validated:
  `match_type = 'casual'`, `tournament_id` empty, both players exist, scores
  valid, a player cannot play themselves.
- Public insert-only for signups and contact messages with NO public read, so
  emails never leak.
- Tournament and bracket writes: officers only, checked against `officers`.
- Add DB constraints too (foreign keys, score checks).
- Policy tests (`supabase test db`) asserting allow/deny for anon and officer
  on every table, run in CI.
- Spam defense for the public Play form: Cloudflare Turnstile CAPTCHA plus rate
  limits. Supabase's built-in CAPTCHA covers sign-up/sign-in/password reset,
  not plain inserts, so use anonymous sign-in with CAPTCHA or a small server
  function that verifies CAPTCHA before inserting. Confirm against current
  docs when building.
- The **service-role key must NEVER** be in the repo or pasted into chat. The
  anon key is public by design and fine in the frontend. Secrets go in
  `.env` files (gitignored).
- Schema is version-controlled as migration files (Supabase CLI), never
  hand-edited in the dashboard. Apply migrations deliberately, dev first.
- Keep the free Supabase project from pausing (it pauses after 7 days of low
  activity): a scheduled GitHub Action pings it every few days and can export
  CSV backups (free plan has no automatic backups; re-verify).
- Do not list member emails or Eastern ID numbers publicly, ever. Showing member
  names is fine: the owner decided no consent step is needed (2026-10-23).
- Supabase GitHub integration settings ("Deploy to production", automatic
  branching, "Supabase changes only") stay OFF until Phase 2 is stable. Do not
  enable them without asking.

## Build plan

| Phase | What                                                                                                                                                                                |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0/1   | Repo, tooling, deployment (Vite + React, ESLint + Prettier, Pages workflow, theme file, branch protection)                                                                          |
| 2     | Database and security first: migrations, tables, RLS, policies, constraints, policy tests, seed data. Existing Supabase project is DEV; create a separate PROD project later        |
| 3     | Site shell: layout, title, next-event slot, Join button, sidebar, loading/empty/error states, dark mode, check on a real phone                                                      |
| 4     | Players: list + search, profiles, officer add-player form, Excel/CSV bulk import with validation                                                                                    |
| 5     | Casual play: Play form, spam defense, casual leaderboard and head-to-head                                                                                                           |
| 6     | Officer access: Supabase Auth, officer-only routes enforced by DB policies, fix/remove bad entries, audit trail                                                                     |
| 7     | Tournaments (single elimination first)                                                                                                                                              |
| 8     | Elo + leaderboard + Results page (tested replay function)                                                                                                                           |
| 9     | Schedule/events + calendar links, Sign Up, Contact, Info                                                                                                                            |
| 10    | PWA install, accessibility pass, performance pass                                                                                                                                   |
| 11    | Operations: keep-alive + CSV backup action, error monitoring, recovery note                                                                                                         |
| 12    | Testing and soft launch with a few members                                                                                                                                          |
| 13    | Handover: dev README, one-page officer guide, second Supabase owner, repo access for the club (possibly transfer to a new free GitHub organization so the site survives graduation) |

## Conventions in this repo

- Node version is pinned in `.nvmrc` (22). `npm ci` / `npm install` to set up.
- Scripts: `npm run dev`, `npm run build`, `npm run lint`, `npm run format`.
- ESLint 9 (flat config, `eslint.config.js`) checks correctness; Prettier
  (`.prettierrc`) owns formatting. ESLint is pinned to v9 because
  `eslint-plugin-react` does not yet support v10.
- Colors, fonts and sizes come only from `src/theme.css` variables.
- Club-wide facts (name) come only from `src/siteConfig.js`.
- Routes live in `src/App.jsx`; sidebar links live in `NAV_ITEMS` in
  `src/components/Layout.jsx`. Add both when adding a page.
- Comment code for a reader new to React: say what it does and why.

## Database conventions (Phase 2 onward)

Full detail is in `docs/database.md`; keep that file up to date as tables are
added.

- Supabase dev project: `EasternPingPongClub-dev`, ref `dbuzjfoqhglaszkvdbww`,
  East US (N. Virginia), Postgres 17. Project settings chosen at creation:
  Data API on, "Automatically expose new tables" **off**, "Enable automatic
  RLS" **on**.
- Schema changes are migration files only: `npx supabase migration new <name>`.
  Never edit the schema in the dashboard.
- Every table: `enable row level security`, then `revoke all ... from anon,
authenticated`, then the exact `grant`s, then one policy per allowed action.
  Auto-expose is off, so a table with no grant is unreachable from the site.
- Officer checks use `private.is_officer()` (reads the `officers` table).
  Never trust user metadata.
- Every table gets pgTAP tests in `supabase/tests/database/` for anon,
  logged-in non-officer and officer. `000_rls_and_grants.test.sql` also lists
  the exact privileges per table and fails if any table lacks RLS.
- CI runs `npx supabase test db` against a throwaway local database. Docker is
  required to run it locally.
- Claude does not apply migrations to the hosted project. The owner runs
  `npx supabase link` and `npx supabase db push` himself because they need the
  database password, which must never be pasted into chat.
- Hosted-project sign-ups must be turned off in the dashboard before the first
  officer login (Phase 6). `supabase/config.toml` already has them off.
- Event times (`events.starts_at/ends_at`) are `timestamp(0)` with no time zone:
  plain New York wall-clock time, by owner request (one location, simpler to
  read). System moments such as `created_at` stay `timestamptz`.
- Decisions for 2b: casual and tournament scores are stored game by game
  (`match_games`); a guest opponent is a typed name on the match, never a row
  in `players`.
