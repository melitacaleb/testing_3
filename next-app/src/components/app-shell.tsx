"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";
import {
  LayoutDashboard,
  Users,
  Bike,
  Receipt,
  FileBarChart,
  MessageSquareWarning,
  UserCircle,
  ChevronLeft,
  ChevronRight,
  LogOut,
  Menu,
  X,
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

const SIDEBAR_STORAGE_KEY = "sidebar-collapsed";

export default function AppShell({ role, title, children }: Props) {
  const links = navByRole[role];
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    try {
      const stored = localStorage.getItem(SIDEBAR_STORAGE_KEY);
      if (stored === "true") {
        // Syncing from localStorage (an external system) after mount, since
        // it isn't available during server rendering. Avoids a hydration
        // mismatch versus reading it in a lazy useState initializer.
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setCollapsed(true);
      }
    } catch {
      // localStorage unavailable; default to expanded.
    }
  }, []);

  const [prevPathname, setPrevPathname] = useState(pathname);
  if (pathname !== prevPathname) {
    // Adjusting state during render (React's documented pattern for
    // resetting state when a prop changes) rather than in an effect —
    // closes the mobile drawer the moment the route actually changes.
    setPrevPathname(pathname);
    setMobileOpen(false);
  }

  function toggleCollapsed() {
    setCollapsed((prev) => {
      const next = !prev;
      try {
        localStorage.setItem(SIDEBAR_STORAGE_KEY, String(next));
      } catch {
        // ignore persistence failure
      }
      return next;
    });
  }

  return (
    <div className={`shell${collapsed ? " shell-collapsed" : ""}`}>
      {mobileOpen ? <div className="sidebar-backdrop" onClick={() => setMobileOpen(false)} /> : null}

      <aside className={`sidebar${collapsed ? " collapsed" : ""}${mobileOpen ? " mobile-open" : ""}`}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <button
            type="button"
            className="sidebar-toggle"
            onClick={toggleCollapsed}
            aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          >
            {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
          </button>
          <button
            type="button"
            className="sidebar-close"
            onClick={() => setMobileOpen(false)}
            aria-label="Close menu"
          >
            <X size={18} />
          </button>
        </div>
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
                title={collapsed ? link.label : undefined}
              >
                <Icon size={18} strokeWidth={2} />
                <span className="nav-label">{link.label}</span>
              </Link>
            );
          })}
        </nav>
        <form action="/api/auth/logout" method="post">
          <button className="logout" type="submit" title={collapsed ? "Logout" : undefined}>
            <LogOut size={16} />
            <span className="logout-label">Logout</span>
          </button>
        </form>
      </aside>

      <main className="content">
        <button
          type="button"
          className="mobile-topbar-toggle"
          onClick={() => setMobileOpen(true)}
          aria-label="Open menu"
        >
          <Menu size={18} />
          Menu
        </button>
        <header>
          <h1>{title}</h1>
        </header>
        {children}
      </main>
    </div>
  );
}
