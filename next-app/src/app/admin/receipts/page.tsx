import AppShell from "@/components/app-shell";
import SendReceiptForm from "@/components/send-receipt-form";
import { requireServerRole } from "@/lib/auth";
import { getAdminReceipts, getAdminUserAccounts } from "@/lib/server-data";

export default async function AdminReceiptsPage() {
  await requireServerRole("admin");
  const [receipts, users] = await Promise.all([getAdminReceipts(), getAdminUserAccounts()]);

  return (
    <AppShell role="admin" title="Receipts">
      <SendReceiptForm users={users} />

      <div className="table-wrap" style={{ marginTop: "1.5rem" }}>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Motorist</th>
              <th>Title</th>
              <th>Amount</th>
              <th>Issued</th>
            </tr>
          </thead>
          <tbody>
            {receipts.map((r) => (
              <tr key={r.id}>
                <td>#{r.id}</td>
                <td>{r.full_name}</td>
                <td>{r.title}</td>
                <td>KES {r.amount}</td>
                <td>{r.created_at}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </AppShell>
  );
}
