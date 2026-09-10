import Link from "next/link";

export default function Home() {
  return (
    <div className="landing">
      <main className="hero">
        <h1>Motorist Traffic Control System</h1>
        <p className="muted">
          One record for every motorist, ticket, and ride — checked in, tracked, and closed out from a single console.
        </p>
        <div className="hero-actions">
          <Link href="/login">Motorist login</Link>
          <Link href="/register">Register</Link>
          <Link href="/admin/login">Admin console</Link>
        </div>
      </main>
    </div>
  );
}
