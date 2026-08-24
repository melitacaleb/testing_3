import Link from "next/link";
import type { ReactNode } from "react";

type Props = {
  role: "admin" | "user";
  title: string;
  children: ReactNode;
};

const navByRole = {
  admin: [
    { href: "/admin/dashboard", label: "Dashboard" },
    { href: "/admin/motorists", label: "Motorists" },
    { href: "/admin/reports", label: "Reports" },
    { href: "/admin/complaints", label: "Complaints" },
  ],
  user: [
    { href: "/user/dashboard", label: "Dashboard" },
    { href: "/user/profile", label: "Profile" },
    { href: "/user/complaints", label: "Complaints" },
    { href: "/user/receipts", label: "Receipts" },
  ],
};

export default function AppShell({ role, title, children }: Props) {
  const links = navByRole[role];

  return (
    <div className="shell">
      <aside className="sidebar">
        <h2>Motorist Control</h2>
        <p className="muted">{role === "admin" ? "Admin Console" : "Motorist Portal"}</p>
        <nav>
          {links.map((link) => (
            <Link key={link.href} href={link.href} className="nav-link">
              {link.label}
            </Link>
          ))}
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
