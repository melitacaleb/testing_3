import Link from "next/link";

export default function Home() {
  return (
    <div className="landing">
      <main className="hero">
        <h1>Motorist Traffic Control System</h1>
        <p className="muted">
          Your application has been migrated to a Next.js + React architecture with API routes and PostgreSQL access.
        </p>
        <div className="hero-actions">
          <Link href="/login">User Login</Link>
          <Link href="/register">Register</Link>
          <Link href="/admin/login">Admin Login</Link>
        </div>
      </main>
    </div>
  );
}
