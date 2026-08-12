# Deploying to Render + Neon

This app was rewritten from PHP into a Next.js (App Router) + React frontend
with API routes, running on Node.js and PostgreSQL (Neon). The `Dockerfile`
now builds and runs `next-app/` instead of the old PHP/Apache image. Read
this before you deploy.

## 1. Create the Neon database

1. Sign up / log in at https://neon.tech and create a new project (any region close to your Render service's region is fine).
2. In the Neon dashboard, open **Connection Details** and copy the connection string. It looks like:
   ```
   postgres://USER:PASSWORD@ep-xxxx-xxxx.neon.tech/neondb?sslmode=require
   ```
3. Rename the database to something meaningful, or just use the default and point the URL at it — the app doesn't care what it's called.
4. Load the schema:
   ```bash
   psql "postgres://USER:PASSWORD@ep-xxxx-xxxx.neon.tech/neondb?sslmode=require" -f schema.postgres.sql
   ```
   (If you don't have `psql` locally, Neon's web SQL editor can run the same file — paste its contents in and execute.)
5. **Change the default admin password.** The schema seeds one admin user (`admin@example.com`) with a bcrypt hash of the word `password`. Generate your own hash and replace it:
   ```bash
   node -e "console.log(require('bcryptjs').hashSync('your-new-password', 10))"
   ```
   (run from inside `next-app/`, where `bcryptjs` is already a dependency). Then in Neon's SQL editor:
   ```sql
   UPDATE users SET password = '<paste hash here>' WHERE email = 'admin@example.com';
   ```

## 2. Push this code to a Git repo

Render deploys from a Git repository (GitHub/GitLab/Bitbucket). Commit everything in this folder, including `Dockerfile`, `.dockerignore`, and the `next-app/` folder, and push it.

## 3. Create the Render Web Service

1. In the Render dashboard: **New > Web Service**.
2. Connect your repo.
3. Render should detect the `Dockerfile` automatically (Runtime: Docker). If it asks, set:
   - **Dockerfile path:** `./Dockerfile`
   - **Docker build context:** `.`
4. Under **Environment**, add:
   - `DATABASE_URL` = the Neon connection string from step 1
   - `JWT_SECRET` = a long random string (e.g. `openssl rand -hex 32`) used to sign session cookies
   - `NODE_ENV` = `production`
   - `NEXT_PUBLIC_SITE_NAME` = `Motorcycle Traffic Control System` (or your own)
5. Deploy. Render builds the multi-stage Docker image (installs deps → `next build` with standalone output → slim runtime image) and starts `node server.js`, which listens on whatever `$PORT` Render assigns automatically.

Alternatively, if you'd rather not click through the UI: commit `render.yaml` (already included) and use **New > Blueprint** in Render, pointing at this repo. You'll still need to paste `DATABASE_URL` and `JWT_SECRET` into the dashboard since they're marked `sync: false` (so your secrets never live in the repo).

## 4. Verify

- Visit `https://<your-service>.onrender.com/admin/login` and sign in with the admin account you set a password for.
- Visit `https://<your-service>.onrender.com/login` for the public/user side, or `/register` to create a test account.

## What changed from the PHP codebase, and why

- **Frontend/backend rewrite**: the entire `admin/` and `users/` PHP UI was
  replaced by a Next.js App Router project in `next-app/`, using React
  Server Components for data-heavy pages and API routes
  (`next-app/src/app/api/**`) for mutations, backed by the `pg` driver
  against the same PostgreSQL schema (`schema.postgres.sql` is unchanged).
- **Auth**: PHP `$_SESSION`-based auth was replaced with signed JWTs stored
  in an HTTP-only cookie (`next-app/src/lib/auth.ts`), with role-based route
  protection enforced in `next-app/src/proxy.ts` (Next's middleware
  convention) for `/admin/*` and `/user/*`.
- **Docker/Render**: the old `php:8.2-apache` image and its
  `docker/entrypoint.sh` port-rewriting script were removed. The `Dockerfile`
  is now a multi-stage Node build that produces a Next.js "standalone"
  output, which is small and starts with a single `node server.js` — no
  entrypoint script needed since Next reads `$PORT` itself.
- **Config**: environment variables moved to `DATABASE_URL` and `JWT_SECRET`
  (see `next-app/.env.example`), read via `next-app/src/lib/db.ts` and
  `next-app/src/lib/auth.ts`.

The original PHP files (`admin/`, `users/`, `includes/`, root `*.php`) are
still present in this repo for reference during the transition, but are no
longer served by the Docker image.

## Known caveats to be aware of

- **Outbound email.** No email-sending code was carried over into the
  Next.js app. If you need complaint/receipt notifications, wire in an
  API-based provider (Postmark, Resend, SendGrid, etc.) inside the relevant
  API route.
- **File uploads.** Not implemented in the Next.js app. Render's filesystem
  is ephemeral per deploy/restart, so if you add uploads later, use object
  storage (S3, Cloudflare R2) rather than local disk.
- **Local development**: point `DATABASE_URL` at a local Postgres instance
  (or a Neon branch), copy `next-app/.env.example` to `next-app/.env.local`,
  set `JWT_SECRET`, then run `npm install && npm run dev` from inside
  `next-app/`. To test the production Docker image locally:
  `docker build -t motorist-app . && docker run -p 3000:3000 -e DATABASE_URL=... -e JWT_SECRET=... motorist-app`.

