"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Trash2, Check, X } from "lucide-react";

type Motorist = {
  id: number;
  full_name: string;
  license_number: string;
  phone_number: string;
  email: string | null;
  bike_count: string;
};

export default function MotoristsTable({ motorists }: { motorists: Motorist[] }) {
  const router = useRouter();
  const [editingId, setEditingId] = useState<number | null>(null);
  const [error, setError] = useState<string>("");
  const [busyId, setBusyId] = useState<number | null>(null);

  function startEdit(id: number) {
    setError("");
    setEditingId(id);
  }

  function cancelEdit() {
    setEditingId(null);
    setError("");
  }

  async function saveEdit(event: React.FormEvent<HTMLFormElement>, id: number) {
    event.preventDefault();
    setError("");
    setBusyId(id);

    const formData = new FormData(event.currentTarget);
    const payload = {
      fullName: String(formData.get("fullName") ?? ""),
      licenseNumber: String(formData.get("licenseNumber") ?? ""),
      phoneNumber: String(formData.get("phoneNumber") ?? ""),
      email: String(formData.get("email") ?? ""),
      address: String(formData.get("address") ?? ""),
    };

    try {
      const response = await fetch(`/api/admin/motorists/${id}`, {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = (await response.json()) as { error?: string };
      if (!response.ok) {
        setError(data.error ?? "Failed to update motorist.");
        return;
      }

      setEditingId(null);
      router.refresh();
    } catch {
      setError("Unexpected network error. Please try again.");
    } finally {
      setBusyId(null);
    }
  }

  async function handleDelete(motorist: Motorist) {
    const bikeCount = Number(motorist.bike_count);
    const warning =
      bikeCount > 0
        ? `Delete ${motorist.full_name}? This will also permanently delete their ${bikeCount} registered motorbike(s). This cannot be undone.`
        : `Delete ${motorist.full_name}? This cannot be undone.`;

    if (!window.confirm(warning)) {
      return;
    }

    setError("");
    setBusyId(motorist.id);
    try {
      const response = await fetch(`/api/admin/motorists/${motorist.id}`, { method: "DELETE" });
      const data = (await response.json()) as { error?: string };
      if (!response.ok) {
        setError(data.error ?? "Failed to delete motorist.");
        return;
      }

      router.refresh();
    } catch {
      setError("Unexpected network error. Please try again.");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div>
      {error ? <p className="error" style={{ marginTop: "0.75rem" }}>{error}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Name</th>
              <th>License</th>
              <th>Phone</th>
              <th>Email</th>
              <th>Bikes</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {motorists.map((m) =>
              editingId === m.id ? (
                <tr key={m.id}>
                  <td colSpan={7}>
                    <form
                      onSubmit={(e) => saveEdit(e, m.id)}
                      style={{ display: "grid", gap: "0.6rem", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", alignItems: "end", padding: "0.5rem 0" }}
                    >
                      <label>
                        Full name
                        <input name="fullName" defaultValue={m.full_name} required minLength={3} />
                      </label>
                      <label>
                        License
                        <input name="licenseNumber" defaultValue={m.license_number} required minLength={4} />
                      </label>
                      <label>
                        Phone
                        <input name="phoneNumber" defaultValue={m.phone_number} required minLength={10} />
                      </label>
                      <label>
                        Email
                        <input type="email" name="email" defaultValue={m.email ?? ""} />
                      </label>
                      <label>
                        Address
                        <input name="address" />
                      </label>
                      <div style={{ display: "flex", gap: "0.4rem" }}>
                        <button type="submit" disabled={busyId === m.id} style={{ padding: "0.6rem 0.8rem" }}>
                          <Check size={16} />
                        </button>
                        <button
                          type="button"
                          onClick={cancelEdit}
                          className="logout"
                          style={{ borderColor: "var(--hairline-strong)", color: "var(--ink-muted)", padding: "0.6rem 0.8rem" }}
                        >
                          <X size={16} />
                        </button>
                      </div>
                    </form>
                  </td>
                </tr>
              ) : (
                <tr key={m.id}>
                  <td>#{m.id}</td>
                  <td>{m.full_name}</td>
                  <td>{m.license_number}</td>
                  <td>{m.phone_number}</td>
                  <td>{m.email ?? "-"}</td>
                  <td>{m.bike_count}</td>
                  <td>
                    <div style={{ display: "flex", gap: "0.4rem" }}>
                      <button
                        type="button"
                        onClick={() => startEdit(m.id)}
                        title="Edit"
                        style={{ padding: "0.4rem 0.55rem", background: "transparent", border: "1px solid var(--hairline-strong)", color: "var(--ink-muted)", boxShadow: "none" }}
                      >
                        <Pencil size={14} />
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDelete(m)}
                        disabled={busyId === m.id}
                        title="Delete"
                        style={{ padding: "0.4rem 0.55rem", background: "transparent", border: "1px solid rgba(255, 84, 112, 0.5)", color: "#ff93a8", boxShadow: "none" }}
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              )
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
