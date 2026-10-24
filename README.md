# ECSU Ping Pong

Website for the ECSU Ping Pong club (Eastern Connecticut State University): upcoming events, results
and rankings, player profiles, and quick casual match logging from a phone.

**Live site:** https://jadonjohanson.github.io/EasternPingPongClub/

> Work in progress. The pages exist but are placeholders; see
> [CLAUDE.md](CLAUDE.md) for the full requirements and build plan.

## Tech stack

- [React](https://react.dev/) with [Vite](https://vite.dev/) (plain JavaScript)
- [React Router](https://reactrouter.com/) using hash routes
- [Supabase](https://supabase.com/) (Postgres database and login)
- GitHub Pages for hosting, GitHub Actions for deployment

## Run it on your computer

You need [Node.js](https://nodejs.org/) 22 or newer.

```bash
npm install      # download the libraries (first time only)
npm run dev      # start the site; open the address it prints
```

## Connect it to the database

The site reads from Supabase. Locally, copy `.env.example` to `.env` and fill
in the project URL and the **anon** key (Supabase dashboard > Project Settings >
API). Restart `npm run dev` after changing `.env`. The `.env` file is ignored
by git. Never use the `service_role` key here.

Without a `.env` file the site still runs; the Home page just says the
database is not connected.

For the live site, add the same two values as repository **variables** named
`VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (GitHub: Settings > Secrets and
variables > Actions > Variables), then re-run the deploy.

## Useful commands

| Command                | What it does                               |
| ---------------------- | ------------------------------------------ |
| `npm run dev`          | Run the site locally with live reload      |
| `npm run build`        | Build the real site into the `dist` folder |
| `npm run preview`      | Serve the built site locally to try it out |
| `npm run lint`         | Check the code for mistakes (ESLint)       |
| `npm test`             | Run the unit tests (Vitest)                |
| `npm run format`       | Auto-format all files (Prettier)           |
| `npm run format:check` | Check formatting without changing files    |

In VS Code, install the recommended extensions (ESLint and Prettier) when it
offers. Files then format automatically when you save.

## Project layout

```text
src/
  main.jsx            Starts the app and turns on page routing
  App.jsx             The map of the site: which address shows which page
  siteConfig.js       Club name and other facts used in many places
  theme.css           ALL colors, fonts and sizes (edit this to re-brand)
  index.css           Base styles shared by every page
  components/         Reusable pieces (Layout, loading/error states, next event)
  lib/                Shared helpers (Supabase connection, data hook, dates)
  data/               Functions that read from the database
  pages/              One file per page of the site
.github/workflows/    deploy.yml (publish site), ci.yml (checks on PRs)
supabase/             Database migrations, tests and local Supabase config
docs/                 Guides (docs/database.md)
```

## Database

The database design, security rules and the commands for testing and applying
migrations are in [docs/database.md](docs/database.md).

## How changes are made

1. Create a branch (never edit `main` directly).
2. Make changes, run `npm run lint` and `npm run build`.
3. Open a pull request and review the diff. CI runs the checks.
4. Merge. The deploy workflow publishes the site automatically.

## Secrets

Never commit passwords, tokens, or Supabase's **service-role key**. Local
secrets go in a `.env` file, which is gitignored.
