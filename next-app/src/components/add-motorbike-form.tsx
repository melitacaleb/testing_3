"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type MotoristOption = { id: number; full_name: string; license_number: string };

export default function AddMotorbikeForm({ motorists }: { motorists: MotoristOption[] }) {
  const router = useRouter();
  const [purpose, setPurpose] = useState("commercial");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setLoading(true);

    const formData = new FormData(event.currentTarget);
    const payload = {
      motoristId: String(formData.get("motoristId") ?? ""),
      registrationNumber: String(formData.get("registrationNumber") ?? ""),
      brand: String(formData.get("brand") ?? ""),
      model: String(formData.get("model") ?? ""),
      color: String(formData.get("color") ?? ""),
      manufactureYear: String(formData.get("manufactureYear") ?? ""),
      purpose: String(formData.get("purpose") ?? ""),
      powerType: String(formData.get("powerType") ?? ""),
      ownerName: String(formData.get("ownerName") ?? ""),
      ownerPhone: String(formData.get("ownerPhone") ?? ""),
      ownerEmail: String(formData.get("ownerEmail") ?? ""),
      ownerAddress: String(formData.get("ownerAddress") ?? ""),
      hireRate: String(formData.get("hireRate") ?? ""),
      hireStartDate: String(formData.get("hireStartDate") ?? ""),
      hireEndDate: String(formData.get("hireEndDate") ?? ""),
    };

    try {
      const response = await fetch("/api/admin/motorbikes", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = (await response.json()) as { error?: string };
      if (!response.ok) {
        setError(data.error ?? "Failed to add motorbike.");
        return;
      }

      event.currentTarget.reset();
      setPurpose("commercial");
      router.refresh();
    } catch {
      setError("Unexpected network error. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="ride-form" style={{ maxWidth: 560 }}>
      <label>
        Motorist
        <select name="motoristId" required defaultValue="">
          <option value="" disabled>-- Select motorist --</option>
          {motorists.map((m) => (
            <option key={m.id} value={m.id}>
              {m.full_name} ({m.license_number})
            </option>
          ))}
        </select>
      </label>
      <label>Registration number<input name="registrationNumber" required /></label>
      <div style={{ display: "flex", gap: "0.7rem" }}>
        <label style={{ flex: 1 }}>Brand<input name="brand" required /></label>
        <label style={{ flex: 1 }}>Model<input name="model" required /></label>
      </div>
      <div style={{ display: "flex", gap: "0.7rem" }}>
        <label style={{ flex: 1 }}>Color<input name="color" /></label>
        <label style={{ flex: 1 }}>Manufacture year<input type="number" name="manufactureYear" min={1900} max={2100} /></label>
      </div>
      <label>
        Purpose
        <select name="purpose" required value={purpose} onChange={(e) => setPurpose(e.target.value)}>
          <option value="commercial">Commercial (Business/Taxi)</option>
          <option value="personal_transport">Personal Transport</option>
          <option value="hire">On Hire</option>
        </select>
      </label>
      <label>
        Power type
        <select name="powerType" required defaultValue="fuel">
          <option value="fuel">Fuel (Petrol)</option>
          <option value="electric">Electric</option>
        </select>
      </label>

      {purpose === "hire" ? (
        <div className="card-lite" style={{ display: "grid", gap: "0.6rem" }}>
          <h3 style={{ margin: 0, fontSize: "0.95rem" }}>Hire / Owner Details</h3>
          <label>Owner&apos;s name<input name="ownerName" required /></label>
          <label>Owner&apos;s phone<input name="ownerPhone" required /></label>
          <label>Owner&apos;s email<input type="email" name="ownerEmail" /></label>
          <label>Owner&apos;s address<textarea name="ownerAddress" rows={2} /></label>
          <div style={{ display: "flex", gap: "0.7rem" }}>
            <label style={{ flex: 1 }}>Hire rate (per day)<input type="number" step="0.01" name="hireRate" required /></label>
            <label style={{ flex: 1 }}>Start date<input type="date" name="hireStartDate" /></label>
            <label style={{ flex: 1 }}>End date<input type="date" name="hireEndDate" /></label>
          </div>
        </div>
      ) : null}

      {error ? <p className="error">{error}</p> : null}
      <button type="submit" disabled={loading}>{loading ? "Saving..." : "Save Motorbike"}</button>
    </form>
  );
}
