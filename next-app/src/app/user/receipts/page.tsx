import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { query } from "@/lib/db";

type Receipt = {
  id: number;
  title: string;
  amount: string;
  description: string | null;
  issued_by: string | null;
  created_at: string;
};

type Citation = {
  id: number;
  violation: string;
  amount: string;
  status: string;
  issued_at: string;
};

export default async function UserReceiptsPage() {
  const session = await requireServerRole("user");

  const [receipts, citations] = await Promise.all([
    query<Receipt>(
      `SELECT id, title, amount::text, description, issued_by, created_at::text
       FROM receipts
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [session.userId]
    ),
    query<Citation>(
      `SELECT id, violation, amount::text, status, issued_at::text
       FROM citations
       WHERE user_id = $1
       ORDER BY issued_at DESC`,
      [session.userId]
    ),
  ]);

  return (
    <AppShell role="user" title="Receipts & Citations">
      <section className="card-lite">
        <h2>Receipts</h2>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Title</th><th>Amount</th><th>Issued By</th></tr></thead>
            <tbody>
              {receipts.rows.map((r) => (
                <tr key={r.id}><td>{r.title}</td><td>KES {Number(r.amount).toFixed(2)}</td><td>{r.issued_by ?? "System"}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card-lite">
        <h2>Citations</h2>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Violation</th><th>Amount</th><th>Status</th></tr></thead>
            <tbody>
              {citations.rows.map((c) => (
                <tr key={c.id}><td>{c.violation}</td><td>KES {Number(c.amount).toFixed(2)}</td><td>{c.status}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </AppShell>
  );
}
