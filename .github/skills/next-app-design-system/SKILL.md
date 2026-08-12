---
name: next-app-design-system
description: 'Frontend/UI design conventions for the next-app Next.js + React + Tailwind v4 codebase. Use when building or styling pages, components, forms, dashboards, tables, or layouts in next-app/src/app or next-app/src/components; when adding new UI surfaces; when asked about design tokens, colors, typography, spacing, responsive behavior, or component styling in this repo.'
---

# Frontend Design — next-app

Design conventions for this repo's Next.js frontend. Reuse the existing
tokens and utility classes below before inventing new ones — this app uses
a small custom CSS layer on top of Tailwind v4, not a component library.

## Where things live

- Global styles/tokens: `next-app/src/app/globals.css`
- Fonts: configured in `next-app/src/app/layout.tsx` via `next/font/google`
  (`Space Grotesk` for body/sans, `Fraunces` for headings/serif)
- Shared layout shell: `next-app/src/components/app-shell.tsx`
- Auth forms: `next-app/src/components/auth-login-form.tsx`,
  `next-app/src/components/register-form.tsx`

## Design tokens (CSS custom properties)

Defined in `:root` in `globals.css`:

| Token | Value | Use |
|---|---|---|
| `--background` | `#f9f4ec` | page background base |
| `--foreground` | `#1f2937` | body text |
| `--primary` | `#0f766e` (teal) | buttons, links, accents |
| `--primary-dark` | `#115e59` | hover states, sidebar gradient |
| `--secondary` | `#ea580c` (orange) | logout button, secondary accents |
| `--surface` | `#ffffff` | cards, tables |
| `--line` | `#d6d3d1` | borders |

Headings (`h1`, `h2`, `h3`) render in the serif font (`--font-fraunces`)
automatically — don't override `font-family` on headings unless intentional.

## Reusable utility classes

Prefer these existing classes over new Tailwind utility soup or new custom
CSS, so the app stays visually consistent:

- Layout shells: `.landing`, `.auth-wrap` (centered full-height auth pages),
  `.shell` + `.sidebar` + `.content` (authenticated app layout, see
  `AppShell`)
- Cards: `.card` (forms, width-capped ~520px), `.card-lite` (content
  cards/panels), `.hero` (landing page hero)
- Forms: inputs/textareas/buttons are styled globally (border, radius,
  padding) — don't add per-input inline styles; wrap `label` + control
  inside `.card` for consistent spacing
- Data display: `.stat-grid` + `.stat-card` (dashboard metric tiles),
  `.table-wrap` + native `table` (list views), `.stack-list` (card feeds
  like complaints), `.two-col` (two-column report sections)
- Navigation: `.nav-link` inside `.sidebar` for `AppShell` links
- Feedback: `.error` (red text), `.muted` (secondary gray text)

## Component conventions

- Functional components with explicit return types; named exports (except
  Next.js special files like `page.tsx`/`layout.tsx` that require default
  exports) — matches `.github/copilot-instructions.md`
- Prefer React Server Components for data-driven pages; only mark a
  component `"use client"` when it needs interactivity/state (forms with
  client-side validation feedback, e.g. `AuthLoginForm`)
- Wrap authenticated pages in `<AppShell role="admin" | "user" title="...">`
  for consistent sidebar/nav/layout — don't hand-roll a new shell per page
- New role-specific nav links go in the `navByRole` map inside
  `app-shell.tsx`, not hardcoded per page

## Responsive behavior

- Single breakpoint currently defined: `@media (max-width: 860px)` collapses
  `.shell` from a 260px-sidebar + content grid to a single column. Extend
  this media query rather than adding new breakpoints unless a page has
  genuinely different responsive needs
- `.stat-grid` and `.two-col` already use `repeat(auto-fit, minmax(...))`
  for responsive wrapping without extra breakpoints — prefer this pattern
  for new grids over fixed column counts + manual breakpoints

## Accessibility notes

- All form inputs must have an associated `<label>` (see existing forms for
  the `<label>Text<input .../></label>` pattern)
- No custom `:focus` styles are currently defined — rely on browser default
  focus rings; don't remove `outline` without providing a replacement
- Maintain sufficient contrast against `--background`/`--surface` when
  introducing new colors; the existing palette (teal/orange/stone) is
  already tuned for AA contrast on white/cream surfaces

## Adding new UI

1. Check if an existing class (`.card`, `.card-lite`, `.stat-grid`, etc.)
   already fits before adding new CSS
2. If a new pattern is genuinely needed, add it to `globals.css` near
   related classes and follow the existing naming style (short, kebab-case,
   semantic — e.g. `.stack-list`, not `.flex-col-gap-2`)
3. Keep Tailwind utility classes for one-off layout tweaks only; don't
   reintroduce a component library (no MUI/Chakra/shadcn) per the project's
   "no external component library" convention
