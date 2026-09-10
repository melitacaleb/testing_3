import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { query } from "@/lib/db";

export default async function UserDashboardPage() {
  const session = await requireServerRole("user");

  const [receipts, citations, complaints] = await Promise.all([
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM receipts WHERE user_id = $1", [session.userId]),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM citations WHERE user_id = $1", [session.userId]),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM complaints WHERE user_id = $1", [session.userId]),
  ]);

  return (
    <AppShell role="user" title={`Hello, ${session.name}`}>
      <div className="stat-grid">
        <article className="stat-card"><h3>Receipts</h3><p>{receipts.rows[0]?.count ?? 0}</p></article>
        <article className="stat-card"><h3>Citations</h3><p>{citations.rows[0]?.count ?? 0}</p></article>
        <article className="stat-card"><h3>Complaints</h3><p>{complaints.rows[0]?.count ?? 0}</p></article>
      </div>
    </AppShell>
  );
}
