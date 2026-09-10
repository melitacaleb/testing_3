import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { query } from "@/lib/db";

export default async function AdminComplaintsPage() {
  await requireServerRole("admin");

  const complaints = await query<{
    id: number;
    subject: string;
    message: string;
    status: string;
    admin_response: string | null;
    full_name: string | null;
    created_at: string;
  }>(
    `SELECT c.id, c.subject, c.message, c.status, c.admin_response, c.created_at::text, u.full_name
     FROM complaints c
     LEFT JOIN user_account u ON c.user_id = u.id
     ORDER BY c.created_at DESC`
  );

  return (
    <AppShell role="admin" title="User Complaints">
      <div className="stack-list">
        {complaints.rows.map((row) => (
          <article key={row.id} className="card-lite">
            <h3>{row.subject}</h3>
            <p className="muted">From: {row.full_name ?? "Unknown user"} | Status: {row.status}</p>
            <p>{row.message}</p>
            {row.admin_response ? <p><strong>Response:</strong> {row.admin_response}</p> : null}
          </article>
        ))}
      </div>
    </AppShell>
  );
}
