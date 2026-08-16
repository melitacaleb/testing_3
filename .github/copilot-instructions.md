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
- Database / Data Access: PostgreSQL (Neon-hosted) accessed via
  `@neondatabase/serverless` (`Pool`/`Client`, node-postgres-compatible
  API) — **no ORM**, **not** the `pg` package (`pg` cannot be bundled for
  Cloudflare Workers; see Deployment). All queries go through
  `next-app/src/lib/db.ts` (`query()` / `getPool()`, both async — always
  `await` them); never import `pool` directly. On Node, `getPool()` needs
  the `ws` package as a WebSocket polyfill (wired up automatically in
  `db.ts`); on Workers the native global `WebSocket` is used instead, and
  a fresh `Pool` is created per request (see `isCloudflareWorkers` export).
  Shared schema lives in root `schema.postgres.sql`
- Auth: JWT (`jose` + `bcryptjs`) stored in an HTTP-only cookie
  (`mtcs_session`). Two roles: `admin` and `user`. Split across two files:
  `next-app/src/lib/session.ts` (Edge-safe: `signSession`/`verifySession`/
  `getSessionFromRequest`, no Node-only imports) and
  `next-app/src/lib/auth.ts` (Node-only: `getServerSession`,
  `requireServerRole`, `setSessionCookie`, `verifyPassword`; re-exports
  the session.ts functions too). There is **no middleware/proxy.ts** —
  Next.js 16's Proxy always runs on the Node.js runtime (can't be changed)
  which Cloudflare Workers doesn't support, so every protected page calls
  `requireServerRole`/`getServerSession` and every protected API route
  calls `getSessionFromRequest` directly instead of relying on a shared
  middleware gate
- Validation: `zod` schemas in `next-app/src/lib/validators.ts`
- Shared types live in `next-app/src/types/domain.ts`
- Migration context: this repo is mid-migration from a legacy PHP app
  (`admin/`, `users/`, `includes/`, root `*.php`) to `next-app/`. All new
  features and fixes belong in `next-app/`; treat the PHP folders as
  read-only/deprecated unless explicitly asked otherwise
- Deployment: two targets from the same `next-app/` codebase —
  1. **Render/Docker** (primary): `Dockerfile` (multi-stage Node build →
     Next.js standalone output), `render.yaml`, `.dockerignore`; see
     `DEPLOY.md`
  2. **Cloudflare Workers**: via `@opennextjs/cloudflare` + `wrangler.jsonc`
     (worker name must match the actual Cloudflare project — verify
     against the live build log, not assumptions). Build command is
     `npm run cf-typegen && npx opennextjs-cloudflare build`. The
     generated `cloudflare-env.d.ts` must never be committed or left on
     disk during a plain `next build` — it redefines global `Request`/
     `Response` types and breaks TypeScript for the Render build (e.g.
     `Body.json()` becomes `Promise<unknown>`, not `any` — cast JSON
     responses explicitly with `as {...}`)

## Code Style & Standards
- Prefer functional components with explicit return types
- Use named exports instead of default exports, except where Next.js
  requires a default export (`page.tsx`, `layout.tsx`, route handlers)
- Follow early-return guard clause patterns to avoid deep nesting (e.g.,
  auth checks that redirect/return before continuing)
- Never use `any` in TypeScript; define explicit interfaces/types (see
  `next-app/src/types/domain.ts`) or use `unknown`
- Always use parameterized queries (`$1, $2...`) — never string-concatenate
  user input into SQL

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
