"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function AddMotoristForm() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setLoading(true);

    const formData = new FormData(event.currentTarget);
    const payload = {
      fullName: String(formData.get("fullName") ?? ""),
      licenseNumber: String(formData.get("licenseNumber") ?? ""),
      phoneNumber: String(formData.get("phoneNumber") ?? ""),
      email: String(formData.get("email") ?? ""),
      address: String(formData.get("address") ?? ""),
    };

    try {
      const response = await fetch("/api/admin/motorists", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = (await response.json()) as { error?: string };
      if (!response.ok) {
        setError(data.error ?? "Failed to add motorist.");
        return;
      }

      setOpen(false);
      event.currentTarget.reset();
      router.refresh();
    } catch {
      setError("Unexpected network error. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  if (!open) {
    return (
      <button type="button" onClick={() => setOpen(true)}>
        + Add Motorist
      </button>
    );
  }

  return (
    <form onSubmit={onSubmit} className="ride-form" style={{ maxWidth: 480, marginBottom: "1.5rem" }}>
      <h3 style={{ margin: 0 }}>Add Motorist</h3>
      <label>
        Full name
        <input name="fullName" required minLength={3} placeholder="e.g. Jane Wanjiru" />
      </label>
      <label>
        License number
        <input name="licenseNumber" required minLength={4} placeholder="e.g. DL123456" />
      </label>
      <label>
        Phone number
        <input name="phoneNumber" required minLength={10} placeholder="e.g. 0712345678" />
      </label>
      <label>
        Email
        <input type="email" name="email" placeholder="e.g. jane@email.com" />
      </label>
      <label>
        Address
        <textarea name="address" rows={2} placeholder="e.g. 123 Moi Avenue, Nairobi" />
      </label>

      {error ? <p className="error">{error}</p> : null}

      <div style={{ display: "flex", gap: "0.5rem" }}>
        <button type="submit" disabled={loading}>
          {loading ? "Saving..." : "Save Motorist"}
        </button>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="logout"
          style={{ borderColor: "var(--hairline-strong)", color: "var(--ink-muted)" }}
        >
          Cancel
        </button>
      </div>
    </form>
  );
}
