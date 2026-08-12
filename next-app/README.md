# Next.js Migration - Motorist Traffic Control System

This folder contains the migrated application built with Next.js (App Router), React, and PostgreSQL.

## What Was Migrated

- User authentication and registration
- Admin authentication
- Role-protected admin and user dashboards
- Admin motorists listing with search
- Admin report summaries
- User profile, complaints, receipts, and citations views
- API routes that map to the same Postgres schema used by the PHP app

## Environment Setup

Create a `.env.local` file:

```bash
cp .env.example .env.local
```

Then set:

- `DATABASE_URL` - Neon/Postgres connection string
- `JWT_SECRET` - long random string for session signing
- `NEXT_PUBLIC_SITE_NAME` - app display name

## Run Locally

```bash
npm install
npm run dev
```

Open http://localhost:3000.

## Main Routes

- `/` - landing page
- `/login` - user login
- `/register` - user registration
- `/admin/login` - admin login
- `/admin/dashboard` - admin dashboard
- `/admin/motorists` - admin motorists list and search
- `/admin/reports` - admin analytics
- `/admin/complaints` - complaint review view
- `/user/dashboard` - user dashboard
- `/user/profile` - user profile
- `/user/complaints` - user complaint submission/history
- `/user/receipts` - user receipts/citations

## Notes

- JWT sessions are stored in an HTTP-only cookie (`mtcs_session`).
- Middleware enforces role-based access to `/admin/*` and `/user/*`.
- The existing PHP codebase is still present outside this folder for reference and phased migration.
