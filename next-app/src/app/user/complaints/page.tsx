import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { query } from "@/lib/db";
import { revalidatePath } from "next/cache";

type Complaint = {
  id: number;
  subject: string;
  message: string;
  status: string;
  admin_response: string | null;
};

export default async function UserComplaintsPage() {
  const session = await requireServerRole("user");

  async function createComplaint(formData: FormData) {
    "use server";

    const current = await requireServerRole("user");
    const subject = String(formData.get("subject") ?? "").trim();
    const message = String(formData.get("message") ?? "").trim();

    if (subject.length < 3 || message.length < 10) {
      return;
    }

    await query(
      "INSERT INTO complaints (user_id, subject, message, status) VALUES ($1, $2, $3, 'open')",
      [current.userId, subject, message]
    );

    revalidatePath("/user/complaints");
  }

  const complaints = await query<Complaint>(
    `SELECT id, subject, message, status, admin_response
     FROM complaints
     WHERE user_id = $1
     ORDER BY created_at DESC`,
    [session.userId]
  );

  return (
    <AppShell role="user" title="Complaints">
      <form action={createComplaint} className="card">
        <h2>Submit a Complaint</h2>
        <label>Subject<input name="subject" required minLength={3} /></label>
        <label>Message<textarea name="message" rows={4} required minLength={10} /></label>
        <button type="submit">Submit complaint</button>
      </form>

      <div className="stack-list">
        {complaints.rows.map((c) => (
          <article key={c.id} className="card-lite">
            <h3>{c.subject}</h3>
            <p className="muted">Status: {c.status}</p>
            <p>{c.message}</p>
            {c.admin_response ? <p><strong>Admin:</strong> {c.admin_response}</p> : null}
          </article>
        ))}
      </div>
    </AppShell>
  );
}
