"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type UserOption = { id: number; full_name: string; email: string };

export default function SendReceiptForm({ users }: { users: UserOption[] }) {
  const router = useRouter();
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setSuccess("");
    setLoading(true);

    const formData = new FormData(event.currentTarget);
    const payload = {
      userId: String(formData.get("userId") ?? ""),
      title: String(formData.get("title") ?? ""),
      amount: String(formData.get("amount") ?? ""),
      description: String(formData.get("description") ?? ""),
    };

    try {
      const response = await fetch("/api/admin/receipts", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = (await response.json()) as { error?: string };
      if (!response.ok) {
        setError(data.error ?? "Failed to send receipt.");
        return;
      }

      setSuccess("Receipt sent.");
      event.currentTarget.reset();
      router.refresh();
    } catch {
      setError("Unexpected network error. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="ride-form" style={{ maxWidth: 480 }}>
      <label>
        Motorist / user
        <select name="userId" required defaultValue="">
          <option value="" disabled>-- Select user --</option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {u.full_name} ({u.email})
            </option>
          ))}
        </select>
      </label>
      <label>Title<input name="title" required minLength={3} placeholder="e.g. Registration fee" /></label>
      <label>Amount (KES)<input type="number" step="0.01" name="amount" required min={0} /></label>
      <label>Description<textarea name="description" rows={2} /></label>

      {error ? <p className="error">{error}</p> : null}
      {success ? <p className="ride-message">{success}</p> : null}
      <button type="submit" disabled={loading}>{loading ? "Sending..." : "Send Receipt"}</button>
    </form>
  );
}
