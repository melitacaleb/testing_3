#!/usr/bin/env bash
set -e
echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
  echo "ERROR: run this from next-app/ (package.json and src/ not found here)."
  exit 1
fi

echo "==> Writing src/lib/validators.ts"
mkdir -p "$(dirname "src/lib/validators.ts")"
cat > "src/lib/validators.ts" << 'FILE_EOF'
import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
  scope: z.enum(["admin", "user"]),
});

export const registerSchema = z
  .object({
    fullName: z.string().min(3),
    email: z.string().email(),
    password: z.string().min(6),
    confirmPassword: z.string().min(6),
    licenseNumber: z.string().min(4),
    phoneNumber: z.string().min(10),
    address: z.string().optional(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

export const createComplaintSchema = z.object({
  subject: z.string().min(3),
  message: z.string().min(10),
});

export const complaintResponseSchema = z.object({
  status: z.enum(["open", "in_progress", "resolved", "closed"]),
  adminResponse: z.string().min(3),
});

export const addMotoristSchema = z.object({
  fullName: z.string().min(3),
  licenseNumber: z.string().min(4),
  phoneNumber: z.string().min(10),
  email: z.string().email().optional().or(z.literal("")),
  address: z.string().optional(),
});

export const editMotoristSchema = addMotoristSchema;

export const addMotorbikeSchema = z
  .object({
    motoristId: z.coerce.number().int().positive(),
    registrationNumber: z.string().min(3),
    brand: z.string().min(1),
    model: z.string().min(1),
    color: z.string().optional(),
    manufactureYear: z.coerce.number().int().min(1900).max(2100).optional(),
    purpose: z.enum(["commercial", "personal_transport", "hire"]),
    powerType: z.enum(["electric", "fuel"]),
    ownerName: z.string().optional(),
    ownerPhone: z.string().optional(),
    ownerEmail: z.string().email().optional().or(z.literal("")),
    ownerAddress: z.string().optional(),
    hireRate: z.coerce.number().nonnegative().optional(),
    hireStartDate: z.string().optional(),
    hireEndDate: z.string().optional(),
  })
  .refine(
    (data) =>
      data.purpose !== "hire" || (data.ownerName && data.ownerPhone && data.hireRate !== undefined),
    {
      message: "Owner name, owner phone, and hire rate are required when purpose is 'hire'.",
      path: ["ownerName"],
    }
  );

export const createReceiptSchema = z.object({
  userId: z.coerce.number().int().positive(),
  title: z.string().min(3),
  amount: z.coerce.number().nonnegative(),
  description: z.string().optional(),
});
FILE_EOF

echo "==> Writing src/app/api/admin/motorists/[id]/route.ts"
mkdir -p "$(dirname "src/app/api/admin/motorists/[id]/route.ts")"
cat > "src/app/api/admin/motorists/[id]/route.ts" << 'FILE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { editMotoristSchema } from "@/lib/validators";
import { getSql, isWorkerRuntime } from "@/lib/db";

type RouteParams = { params: Promise<{ id: string }> };

export async function PATCH(request: NextRequest, { params }: RouteParams) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const motoristId = Number(id);
  if (!Number.isInteger(motoristId) || motoristId <= 0) {
    return NextResponse.json({ error: "Invalid motorist id." }, { status: 400 });
  }

  const body = await request.json().catch(() => null);
  const parsed = editMotoristSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? "Invalid payload." }, { status: 400 });
  }

  const { fullName, licenseNumber, phoneNumber, email, address } = parsed.data;
  const sql = getSql();
  try {
    const rows = await sql.unsafe(
      `UPDATE motorists
       SET full_name = $1, license_number = $2, phone_number = $3, email = $4, address = $5
       WHERE id = $6
       RETURNING id`,
      [fullName, licenseNumber, phoneNumber, email || null, address || null, motoristId]
    );

    if (rows.length === 0) {
      return NextResponse.json({ error: "Motorist not found." }, { status: 404 });
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Failed to update motorist:", error);
    return NextResponse.json(
      { error: "Failed to update motorist. The license number may already be in use." },
      { status: 500 }
    );
  } finally {
    if (isWorkerRuntime()) {
      await sql.end();
    }
  }
}

export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const motoristId = Number(id);
  if (!Number.isInteger(motoristId) || motoristId <= 0) {
    return NextResponse.json({ error: "Invalid motorist id." }, { status: 400 });
  }

  const sql = getSql();
  try {
    const rows = await sql.unsafe("DELETE FROM motorists WHERE id = $1 RETURNING id", [motoristId]);

    if (rows.length === 0) {
      return NextResponse.json({ error: "Motorist not found." }, { status: 404 });
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Failed to delete motorist:", error);
    return NextResponse.json({ error: "Failed to delete motorist." }, { status: 500 });
  } finally {
    if (isWorkerRuntime()) {
      await sql.end();
    }
  }
}
FILE_EOF

echo "==> Writing src/components/motorists-table.tsx"
mkdir -p "$(dirname "src/components/motorists-table.tsx")"
cat > "src/components/motorists-table.tsx" << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/app/admin/motorists/page.tsx"
mkdir -p "$(dirname "src/app/admin/motorists/page.tsx")"
cat > "src/app/admin/motorists/page.tsx" << 'FILE_EOF'
import AppShell from "@/components/app-shell";
import AddMotoristForm from "@/components/add-motorist-form";
import MotoristsTable from "@/components/motorists-table";
import { requireServerRole } from "@/lib/auth";
import { getAdminMotorists } from "@/lib/server-data";

type Props = {
  searchParams: Promise<{ search?: string }>;
};

export default async function AdminMotoristsPage({ searchParams }: Props) {
  await requireServerRole("admin");
  const { search } = await searchParams;
  const motorists = await getAdminMotorists(search);

  return (
    <AppShell role="admin" title="Motorists">
      <AddMotoristForm />

      <form method="get" className="inline-form">
        <input name="search" defaultValue={search ?? ""} placeholder="Search by name, license, or email" />
        <button type="submit">Search</button>
      </form>

      <MotoristsTable motorists={motorists} />
    </AppShell>
  );
}
FILE_EOF

echo ""
echo "Edit and Delete motorist actions added."
echo "Run: bash deploy.sh   (or: npm run deploy)"
