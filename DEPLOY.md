# Deploying to Render + Neon

This app was originally written against MySQL/`mysqli`. It has been ported to
PDO + PostgreSQL (for Neon) and containerized for Render, which has no native
PHP runtime. Read this before you deploy.

## 1. Create the Neon database

1. Sign up / log in at https://neon.tech and create a new project (any region close to your Render service's region is fine).
2. In the Neon dashboard, open **Connection Details** and copy the connection string. It looks like:
   ```
   postgres://USER:PASSWORD@ep-xxxx-xxxx.neon.tech/neondb?sslmode=require
   ```
3. Rename the database to something meaningful, or just use the default and point `PGDATABASE`/the URL at it — the app doesn't care what it's called.
4. Load the schema:
   ```bash
   psql "postgres://USER:PASSWORD@ep-xxxx-xxxx.neon.tech/neondb?sslmode=require" -f schema.postgres.sql
   ```
   (If you don't have `psql` locally, Neon's web SQL editor can run the same file — paste its contents in and execute.)
5. **Change the default admin password.** The schema seeds one admin user (`admin@example.com`) with a bcrypt hash of the word `password`. Generate your own hash and replace it:
   ```bash
   php -r "echo password_hash('your-new-password', PASSWORD_DEFAULT), PHP_EOL;"
   ```
   Then in Neon's SQL editor:
   ```sql
   UPDATE users SET password = '<paste hash here>' WHERE email = 'admin@example.com';
   ```

## 2. Push this code to a Git repo

Render deploys from a Git repository (GitHub/GitLab/Bitbucket). Commit everything in this folder, including the `Dockerfile` and `docker/` folder, and push it.

## 3. Create the Render Web Service

1. In the Render dashboard: **New > Web Service**.
2. Connect your repo.
3. Render should detect the `Dockerfile` automatically (Runtime: Docker). If it asks, set:
   - **Dockerfile path:** `./Dockerfile`
   - **Docker build context:** `.`
4. Under **Environment**, add:
   - `DATABASE_URL` = the Neon connection string from step 1
   - `APP_ENV` = `production`
   - `SITE_NAME` = `Motorcycle Traffic Control System` (or your own)
   - `SITE_URL` = `https://<your-service>.onrender.com/`
5. Deploy. Render builds the Docker image and starts the container, which listens on whatever `$PORT` Render assigns (handled automatically by `docker/entrypoint.sh`).

Alternatively, if you'd rather not click through the UI: commit `render.yaml` (already included) and use **New > Blueprint** in Render, pointing at this repo. You'll still need to paste `DATABASE_URL` into the dashboard since it's marked `sync: false` (so your secret never lives in the repo).

## 4. Verify

- Visit `https://<your-service>.onrender.com/admin/login.php` and sign in with the admin account you set a password for.
- Visit `https://<your-service>.onrender.com/users/login.php` for the public/user side, or `/users/registration.php` to create a test account.

## What changed from the original codebase, and why

- **Database layer**: every `mysqli` call site now runs through PDO (`pgsql`
  driver). A compatibility shim (`includes/db.php`) keeps `->fetch_assoc()`,
  `->fetch_all()`, and `->num_rows` working without touching every template,
  but raw SQL string-building was replaced with real prepared statements
  everywhere user input reached a query (this also closes a couple of SQL
  injection holes that existed in `admin/index.php` and
  `admin/view_motorist.php` in the original).
- **Schema**: `AUTO_INCREMENT` → `SERIAL`, `ENUM(...)` → `VARCHAR` + `CHECK`,
  `YEAR` → `INTEGER`, `GROUP_CONCAT` → `string_agg`, `DATE_SUB(...)` →
  `NOW() - INTERVAL '7 days'`. Two tables (`complaints`, `activity_log`) were
  referenced by the PHP code but missing from both original `.sql` files —
  they're included in `schema.postgres.sql` based on how the columns are
  used.
- **`insert_id`**: mysqli auto-populates this after any insert; Postgres
  doesn't work that way over a generic connection. Insert statements that
  need the new row's id now use `INSERT ... RETURNING id` via the
  `insertReturningId()` helper on the connection object.
- **Docker/Render**: Render has no native PHP buildpack, so the app runs in a
  `php:8.2-apache` container with `pdo_pgsql` installed. An entrypoint script
  rewrites Apache's listen port to Render's `$PORT` at container start.
- **Config**: DB credentials moved out of hardcoded `config.php` constants
  and into environment variables (`DATABASE_URL` or discrete `PG*` vars),
  read in `includes/db.php`.

## Known caveats to be aware of

- **Outbound email.** `sendEmailNotification()` still calls PHP's `mail()`.
  Render containers don't ship a configured MTA, so this will silently fail
  in production (it falls back to logging to `logs/mail_fail.log` inside the
  container, which is wiped on every redeploy). If you need real email
  delivery, swap this function for an API-based provider (Postmark, Resend,
  SendGrid, etc.) — happy to wire one in if you tell me which you'd like.
- **`num_rows` on PDO.** The compatibility shim implements `->num_rows` via
  `rowCount()`, which isn't officially guaranteed for `SELECT` statements
  across all PDO drivers. It works correctly for the simple, non-cursor
  SELECTs this app uses with the native `pgsql` driver, but if you add more
  complex queries later and see a wrong count, switch that spot to
  `count($stmt->fetch_all())` instead.
- **File uploads.** `uploadFile()`/`deleteFile()` write to local disk. Render's
  filesystem is ephemeral per deploy/restart — fine for temp/log files, not
  fine for anything you need to keep. This app doesn't currently use file
  uploads on any page, so it's not an active problem, just don't start saving
  user-uploaded images to local disk without adding object storage (e.g. S3,
  Cloudflare R2) first.
- **Local development**: if you want to run this locally before deploying,
  point `PGHOST`/`DATABASE_URL` at a local Postgres instance (or a Neon
  branch) and run `php -S localhost:8000` from inside `app/`, or use the same
  Docker image: `docker build -t motorist-app . && docker run -p 8080:80 -e DATABASE_URL=... motorist-app`.
