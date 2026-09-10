#!/usr/bin/env bash
set -e
echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
  echo "ERROR: run this from next-app/ (package.json and src/ not found here)."
  exit 1
fi

echo "==> Installing lucide-react (icon library used in the new sidebar)"
npm install lucide-react --no-audit --no-fund

echo "==> Writing src/app/globals.css"
mkdir -p $(dirname src/app/globals.css)
cat > src/app/globals.css << 'FILE_EOF'
@import "tailwindcss";

:root {
  --bg-deep: #060b16;
  --bg-deep-2: #0a1428;
  --panel: #101c34;
  --panel-alt: #14213e;
  --glow: #2fb6ff;
  --accent: #2e6bff;
  --accent-2: #6a4bff;
  --amber: #ffab3e;
  --danger: #ff5470;
  --success: #33dd93;
  --ink: #f2f6ff;
  --ink-muted: #8ea0c7;
  --hairline: rgba(255, 255, 255, 0.08);
  --hairline-strong: rgba(255, 255, 255, 0.14);
}

@theme inline {
  --color-background: var(--bg-deep);
  --color-foreground: var(--ink);
  --font-sans: var(--font-plex-sans);
  --font-display: var(--font-sora);
  --font-mono: var(--font-plex-mono);
}

* {
  box-sizing: border-box;
}

body {
  background:
    radial-gradient(1200px 600px at 15% -10%, rgba(46, 107, 255, 0.25), transparent 60%),
    radial-gradient(900px 500px at 100% 0%, rgba(106, 75, 255, 0.18), transparent 55%),
    var(--bg-deep);
  color: var(--ink);
  font-family: var(--font-plex-sans), sans-serif;
  font-size: 15px;
  line-height: 1.55;
}

a {
  color: var(--glow);
}

h1,
h2,
h3 {
  font-family: var(--font-sora), sans-serif;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--ink);
}

/* ---------- Landing: glowing hero ---------- */

.landing {
  min-height: 100vh;
  display: grid;
  place-content: center;
  padding: 2rem;
  position: relative;
  overflow: hidden;
}

.hero {
  position: relative;
  max-width: 720px;
  background: linear-gradient(180deg, var(--panel-alt), var(--panel));
  border: 1px solid var(--hairline-strong);
  border-radius: 28px;
  padding: 3rem 2.5rem;
  box-shadow: 0 40px 90px rgba(0, 0, 0, 0.55), 0 0 0 1px rgba(255, 255, 255, 0.02) inset;
  overflow: hidden;
}

.hero::after {
  content: "";
  position: absolute;
  top: -140px;
  right: -140px;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(47, 182, 255, 0.55), rgba(47, 182, 255, 0) 70%);
  pointer-events: none;
}

.hero::before {
  content: "SYSTEM ONLINE";
  position: relative;
  z-index: 1;
  display: inline-block;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.68rem;
  font-weight: 600;
  letter-spacing: 0.18em;
  color: var(--glow);
  background: rgba(47, 182, 255, 0.12);
  border: 1px solid rgba(47, 182, 255, 0.35);
  border-radius: 999px;
  padding: 0.3rem 0.8rem;
  margin-bottom: 1.5rem;
}

.hero h1 {
  position: relative;
  z-index: 1;
  font-size: clamp(2rem, 5.5vw, 3.1rem);
  line-height: 1.08;
  margin: 0;
  background: linear-gradient(135deg, #ffffff, #b9ccff 70%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.muted {
  color: var(--ink-muted);
}

.hero .muted {
  position: relative;
  z-index: 1;
  margin-top: 0.9rem;
  max-width: 46ch;
}

.hero-actions {
  position: relative;
  z-index: 1;
  margin-top: 2rem;
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.hero-actions a {
  display: inline-block;
  padding: 0.75rem 1.3rem;
  border-radius: 999px;
  text-decoration: none;
  font-weight: 600;
  font-size: 0.9rem;
  border: 1px solid var(--hairline-strong);
  color: var(--ink);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.hero-actions a:first-child {
  background: linear-gradient(135deg, var(--accent), var(--glow));
  border: none;
  color: #071224;
  box-shadow: 0 8px 30px rgba(47, 182, 255, 0.45);
}

.hero-actions a:hover {
  transform: translateY(-2px);
}

/* ---------- Auth ---------- */

.auth-wrap {
  min-height: 100vh;
  display: grid;
  place-content: center;
  padding: 1.5rem;
}

.card,
.card-lite {
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 20px;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.35);
}

.card {
  width: min(440px, 92vw);
  padding: 2rem;
  display: grid;
  gap: 1rem;
}

.card h1 {
  font-size: 1.5rem;
}

.card label {
  display: grid;
  gap: 0.35rem;
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--ink-muted);
}

input,
textarea,
button,
select {
  font: inherit;
}

input,
textarea,
select {
  border: 1px solid var(--hairline-strong);
  border-radius: 12px;
  padding: 0.7rem 0.85rem;
  background: rgba(255, 255, 255, 0.03);
  color: var(--ink);
  font-family: var(--font-plex-sans), sans-serif;
}

input::placeholder,
textarea::placeholder {
  color: rgba(142, 160, 199, 0.6);
}

input:focus-visible,
textarea:focus-visible,
select:focus-visible,
button:focus-visible,
a:focus-visible {
  outline: 2px solid var(--glow);
  outline-offset: 2px;
}

button {
  border: 0;
  border-radius: 999px;
  padding: 0.8rem 1.2rem;
  background: linear-gradient(135deg, var(--accent), var(--glow));
  color: #071224;
  font-weight: 700;
  font-size: 0.88rem;
  cursor: pointer;
  box-shadow: 0 10px 26px rgba(47, 182, 255, 0.35);
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}

button:hover {
  transform: translateY(-1px);
  box-shadow: 0 14px 32px rgba(47, 182, 255, 0.45);
}

button:disabled {
  opacity: 0.55;
  cursor: default;
  box-shadow: none;
}

.error {
  color: var(--danger);
  font-size: 0.9rem;
  font-weight: 500;
}

.auth-link {
  text-align: center;
  font-size: 0.9rem;
  color: var(--ink-muted);
}

/* ---------- App shell / console ---------- */

.shell {
  min-height: 100vh;
  display: grid;
  grid-template-columns: 250px 1fr;
}

.sidebar {
  background: linear-gradient(180deg, var(--panel-alt), var(--bg-deep-2));
  color: var(--ink);
  padding: 1.5rem 1.1rem;
  display: flex;
  flex-direction: column;
  gap: 1.2rem;
  border-right: 1px solid var(--hairline);
}

.sidebar h2 {
  margin: 0;
  font-size: 1.15rem;
}

.sidebar .muted {
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.68rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--glow);
  margin-top: -0.7rem;
}

.sidebar nav {
  display: grid;
  gap: 0.3rem;
  margin-top: 0.5rem;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.65rem 0.85rem;
  border-radius: 14px;
  color: var(--ink-muted);
  text-decoration: none;
  font-size: 0.92rem;
  font-weight: 500;
  transition: background 0.15s ease, color 0.15s ease;
}

.nav-link:hover {
  background: rgba(47, 182, 255, 0.1);
  color: var(--ink);
}

.nav-link.active {
  background: linear-gradient(135deg, rgba(46, 107, 255, 0.35), rgba(47, 182, 255, 0.25));
  color: #fff;
  box-shadow: 0 0 0 1px rgba(47, 182, 255, 0.4) inset;
}

.logout {
  margin-top: auto;
  width: 100%;
  background: transparent;
  border: 1px solid rgba(255, 84, 112, 0.5);
  color: #ff93a8;
  box-shadow: none;
}

.logout:hover {
  background: rgba(255, 84, 112, 0.12);
  transform: none;
  box-shadow: none;
}

.content {
  padding: 1.75rem 2rem;
}

.content > header {
  margin-bottom: 1.5rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid var(--hairline);
}

.content h1 {
  font-size: 1.6rem;
  margin: 0;
}

/* ---------- Stat cards: glowing ring signature ---------- */

.stat-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
}

.stat-card {
  position: relative;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 18px;
  padding: 1.25rem 1.1rem;
  overflow: hidden;
}

.stat-card::before {
  content: "";
  position: absolute;
  top: -30px;
  right: -30px;
  width: 90px;
  height: 90px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(47, 182, 255, 0.4), rgba(47, 182, 255, 0) 70%);
}

.stat-card p {
  font-family: var(--font-plex-mono), monospace;
  font-size: 1.85rem;
  font-weight: 600;
  margin: 0.4rem 0 0;
  background: linear-gradient(135deg, #fff, var(--glow));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.stat-card span,
.stat-card label {
  font-size: 0.72rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink-muted);
}

/* ---------- Ride booking ---------- */

.ride-booking {
  max-width: 720px;
  display: grid;
  gap: 1rem;
}

.ride-booking-copy {
  padding: 1rem 0 0;
}

.ride-booking-copy h2 {
  margin: 0.2rem 0;
  font-size: 1.35rem;
}

.ride-kicker {
  margin: 0;
  color: var(--glow);
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.ride-route {
  display: flex;
  align-items: center;
  width: min(100%, 420px);
  padding-top: 0.75rem;
}

.ride-stop {
  width: 14px;
  height: 14px;
  flex: 0 0 auto;
  border: 3px solid var(--bg-deep);
  border-radius: 50%;
  box-shadow: 0 0 0 2px var(--glow), 0 0 14px rgba(47, 182, 255, 0.6);
}

.ride-stop--end {
  border-radius: 4px;
  box-shadow: 0 0 0 2px var(--amber), 0 0 14px rgba(255, 171, 62, 0.55);
}

.ride-route-line {
  height: 3px;
  width: 100%;
  background: repeating-linear-gradient(90deg, var(--glow) 0 10px, transparent 10px 16px);
  opacity: 0.6;
}

.ride-form {
  display: grid;
  gap: 0.9rem;
  padding: 1.5rem;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 20px;
}

.ride-form label {
  display: grid;
  gap: 0.35rem;
  font-size: 0.85rem;
  color: var(--ink-muted);
}

.ride-location {
  justify-self: start;
  padding: 0.6rem 0.9rem;
  color: var(--glow);
  background: rgba(47, 182, 255, 0.08);
  border: 1px solid rgba(47, 182, 255, 0.35);
  box-shadow: none;
}

.ride-location:hover {
  background: rgba(47, 182, 255, 0.18);
  transform: none;
  box-shadow: none;
}

.ride-estimate {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.9rem 1rem;
  color: var(--ink);
  background: rgba(46, 107, 255, 0.1);
  border: 1px solid rgba(46, 107, 255, 0.3);
  border-radius: 14px;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.9rem;
}

.ride-estimate strong {
  text-align: right;
  font-size: 0.9rem;
  color: var(--glow);
}

.ride-message {
  margin: 0;
  padding: 0.9rem 1rem;
  color: var(--ink);
  background: rgba(255, 171, 62, 0.1);
  border: 1px solid rgba(255, 171, 62, 0.35);
  border-radius: 14px;
  font-size: 0.9rem;
}

/* ---------- Status badges ---------- */

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.25rem 0.65rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}

.badge-pending {
  color: var(--amber);
  background: rgba(255, 171, 62, 0.14);
  border: 1px solid rgba(255, 171, 62, 0.35);
}

.badge-assigned {
  color: var(--glow);
  background: rgba(47, 182, 255, 0.14);
  border: 1px solid rgba(47, 182, 255, 0.35);
}

.badge-completed {
  color: var(--success);
  background: rgba(51, 221, 147, 0.14);
  border: 1px solid rgba(51, 221, 147, 0.35);
}

.badge-cancelled {
  color: var(--danger);
  background: rgba(255, 84, 112, 0.14);
  border: 1px solid rgba(255, 84, 112, 0.35);
}

/* ---------- Data / tables ---------- */

.inline-form {
  display: flex;
  gap: 0.6rem;
  margin: 1rem 0;
}

.table-wrap {
  overflow-x: auto;
  margin-top: 1rem;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 18px;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.92rem;
}

th {
  text-align: left;
  padding: 0.75rem 0.9rem;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.7rem;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: var(--ink-muted);
  background: rgba(255, 255, 255, 0.02);
  border-bottom: 1px solid var(--hairline);
}

td {
  text-align: left;
  padding: 0.75rem 0.9rem;
  border-bottom: 1px solid var(--hairline);
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.88rem;
  color: var(--ink);
}

tr:last-child td {
  border-bottom: none;
}

tr:hover td {
  background: rgba(255, 255, 255, 0.02);
}

.two-col {
  margin-top: 1rem;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}

.card-lite {
  padding: 1.1rem;
  border-left: 3px solid var(--accent);
}

.stack-list {
  margin-top: 1rem;
  display: grid;
  gap: 0.8rem;
}

@media (max-width: 860px) {
  .shell {
    grid-template-columns: 1fr;
  }

  .sidebar {
    border-right: none;
    border-bottom: 1px solid var(--hairline);
  }
}

@media (prefers-reduced-motion: reduce) {
  * {
    transition: none !important;
  }
}
FILE_EOF

echo "==> Writing src/app/layout.tsx"
mkdir -p $(dirname src/app/layout.tsx)
cat > src/app/layout.tsx << 'FILE_EOF'
import type { Metadata } from "next";
import { Sora, IBM_Plex_Sans, IBM_Plex_Mono } from "next/font/google";
import "./globals.css";

const sora = Sora({
  variable: "--font-sora",
  subsets: ["latin"],
  weight: ["600", "700", "800"],
});

const plexSans = IBM_Plex_Sans({
  variable: "--font-plex-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
});

const plexMono = IBM_Plex_Mono({
  variable: "--font-plex-mono",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
});

export const metadata: Metadata = {
  title: "Motorist Traffic Control System",
  description: "Next.js migration of the motorist management application.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${sora.variable} ${plexSans.variable} ${plexMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
FILE_EOF

echo "==> Writing src/components/app-shell.tsx"
mkdir -p $(dirname src/components/app-shell.tsx)
cat > src/components/app-shell.tsx << 'FILE_EOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import {
  LayoutDashboard,
  Users,
  Bike,
  Receipt,
  FileBarChart,
  MessageSquareWarning,
  UserCircle,
} from "lucide-react";

type Props = {
  role: "admin" | "user";
  title: string;
  children: ReactNode;
};

const navByRole = {
  admin: [
    { href: "/admin/dashboard", label: "Dashboard", icon: LayoutDashboard },
    { href: "/admin/motorists", label: "Motorists", icon: Users },
    { href: "/admin/motorbikes", label: "Motorbikes", icon: Bike },
    { href: "/admin/receipts", label: "Receipts", icon: Receipt },
    { href: "/admin/reports", label: "Reports", icon: FileBarChart },
    { href: "/admin/complaints", label: "Complaints", icon: MessageSquareWarning },
  ],
  user: [
    { href: "/user/dashboard", label: "Dashboard", icon: LayoutDashboard },
    { href: "/user/profile", label: "Profile", icon: UserCircle },
    { href: "/user/complaints", label: "Complaints", icon: MessageSquareWarning },
    { href: "/user/receipts", label: "Receipts", icon: Receipt },
  ],
};

export default function AppShell({ role, title, children }: Props) {
  const links = navByRole[role];
  const pathname = usePathname();

  return (
    <div className="shell">
      <aside className="sidebar">
        <h2>Motorist Control</h2>
        <p className="muted">{role === "admin" ? "Admin Console" : "Motorist Portal"}</p>
        <nav>
          {links.map((link) => {
            const Icon = link.icon;
            const isActive = pathname?.startsWith(link.href);
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`nav-link${isActive ? " active" : ""}`}
              >
                <Icon size={18} strokeWidth={2} />
                {link.label}
              </Link>
            );
          })}
        </nav>
        <form action="/api/auth/logout" method="post">
          <button className="logout" type="submit">
            Logout
          </button>
        </form>
      </aside>
      <main className="content">
        <header>
          <h1>{title}</h1>
        </header>
        {children}
      </main>
    </div>
  );
}
FILE_EOF

echo ""
echo "Dark navy glow theme applied throughout the app."
echo "Run: npm run deploy   (or npm run dev to preview locally first)"
