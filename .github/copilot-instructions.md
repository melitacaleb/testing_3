# Project Conventions & Guidelines

## Tech Stack & Architecture
- Framework: Next.js 16 (App Router), React 19, TypeScript (strict mode)
- Styling: Tailwind CSS v4 — custom design system in
  `next-app/src/app/globals.css`, no external component library
- State Management: no client state library. Data flows through React
  Server Components and Server Actions; client components use local
  `useState` only where interactivity requires it (e.g., login/register
  forms). Avoid `useEffect` for data fetching — the ESLint config flags
  `setState` calls inside effects (`react-hooks/set-state-in-effect`)
- Database / Data Access: PostgreSQL (Neon-hosted in production) accessed
  directly via the `pg` driver — **no ORM**. All queries go through
  `next-app/src/lib/db.ts` (`query()` / `getPool()`); never import `pool`
  directly. Shared schema lives in root `schema.postgres.sql`
- Auth: JWT (`jsonwebtoken` + `bcryptjs`) stored in an HTTP-only cookie
  (`mtcs_session`), issued/verified in `next-app/src/lib/auth.ts`. Two
  roles: `admin` and `user`. Route protection for `/admin/*` and `/user/*`
  is enforced in `next-app/src/proxy.ts` (Next 16's middleware/proxy
  convention — not `middleware.ts`)
- Validation: `zod` schemas in `next-app/src/lib/validators.ts`
- Shared types live in `next-app/src/types/domain.ts`
- Migration context: this repo is mid-migration from a legacy PHP app
  (`admin/`, `users/`, `includes/`, root `*.php`) to `next-app/`. All new
  features and fixes belong in `next-app/`; treat the PHP folders as
  read-only/deprecated unless explicitly asked otherwise
- Deployment: `Dockerfile` (multi-stage Node build → Next.js standalone
  output), `render.yaml`, and `.dockerignore` deploy `next-app/` to Render;
  see `DEPLOY.md` for details

## Code Style & Standards
- Prefer functional components with explicit return types
- Use named exports instead of default exports, except where Next.js
  requires a default export (`page.tsx`, `layout.tsx`, route handlers)
- Follow early-return guard clause patterns to avoid deep nesting (e.g.,
  auth checks that redirect/return before continuing)
- Never use `any` in TypeScript; define explicit interfaces/types (see
  `next-app/src/types/domain.ts`) or use `unknown`
- Always use parameterized queries (`$1, $2...` via `pg`) — never
  string-concatenate user input into SQL

## Testing
- No test framework is currently configured in `next-app/`
- If tests are introduced, prefer Vitest + React Testing Library, co-locate
  test files alongside components (e.g., `Button.test.tsx`), and mock all
  network/database requests in unit tests

## Workflow & Safety
- Never modify `schema.postgres.sql` without also accounting for the
  legacy PHP app, which shares the same database in production
- Do not output hardcoded secrets or API keys under any circumstances; use
  environment variables (`DATABASE_URL`, `JWT_SECRET`,
  `NEXT_PUBLIC_SITE_NAME` — see `next-app/.env.example`)
- Run `npm run lint` and `npm run build` in `next-app/` after non-trivial
  changes to catch TypeScript/ESLint issues before finishing
- Don't add features, refactor, or add comments/docstrings beyond what's
  requested
- Don't reintroduce PHP-side changes as part of Next.js work; if a
  PHP-only fix is requested, scope it to the legacy files only
