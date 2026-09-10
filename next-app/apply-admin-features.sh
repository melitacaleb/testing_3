#!/usr/bin/env bash
set -e
echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
  echo "ERROR: run this from next-app/ (package.json and src/ not found here)."
  exit 1
fi

echo "==> Writing src/lib/validators.ts"
mkdir -p $(dirname src/lib/validators.ts)
cat > src/lib/validators.ts << 'FILE_EOF'
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

export const addMotorbikeSchema = z
  .object({
    motoristId: z.coerce.number().int().positive(),
    registrationNumber: z.string().min(3),
    brand: z.string().min(1),
    model: z.string().min(1),
    color: z.string().optional(),
    manufactureYear: z.coerce.number().int().min(1900).max(2100).optional(),
    purpose: z.enum(["commercial", "personal_transport", "hire"]),
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

echo "==> Writing src/lib/server-data.ts"
mkdir -p $(dirname src/lib/server-data.ts)
cat > src/lib/server-data.ts << 'FILE_EOF'
import { query } from "@/lib/db";
import type { DashboardStats } from "@/types/domain";

export async function getAdminDashboardStats(): Promise<DashboardStats> {
  const [motorists, bikes, commercial, hire, personal] = await Promise.all([
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorists"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes WHERE purpose = 'commercial'"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes WHERE purpose = 'hire'"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes WHERE purpose = 'personal_transport'"),
  ]);

  return {
    totalMotorists: Number(motorists.rows[0]?.count ?? 0),
    totalMotorbikes: Number(bikes.rows[0]?.count ?? 0),
    commercialCount: Number(commercial.rows[0]?.count ?? 0),
    hireCount: Number(hire.rows[0]?.count ?? 0),
    personalCount: Number(personal.rows[0]?.count ?? 0),
  };
}

export async function getAdminMotorists(search?: string) {
  if (!search) {
    const result = await query<{
      id: number;
      full_name: string;
      license_number: string;
      phone_number: string;
      email: string | null;
      bike_count: string;
    }>(
      `SELECT m.id, m.full_name, m.license_number, m.phone_number, m.email,
              COUNT(mb.id)::text AS bike_count
       FROM motorists m
       LEFT JOIN motorbikes mb ON m.id = mb.motorist_id
       GROUP BY m.id
       ORDER BY m.id DESC
       LIMIT 100`
    );
    return result.rows;
  }

  const like = `%${search}%`;
  const result = await query<{
    id: number;
    full_name: string;
    license_number: string;
    phone_number: string;
    email: string | null;
    bike_count: string;
  }>(
    `SELECT m.id, m.full_name, m.license_number, m.phone_number, m.email,
            COUNT(mb.id)::text AS bike_count
     FROM motorists m
     LEFT JOIN motorbikes mb ON m.id = mb.motorist_id
     WHERE m.full_name ILIKE $1 OR m.license_number ILIKE $1 OR COALESCE(m.email, '') ILIKE $1
     GROUP BY m.id
     ORDER BY m.id DESC
     LIMIT 100`,
    [like]
  );
  return result.rows;
}

export async function getMotoristOptions() {
  const result = await query<{ id: number; full_name: string; license_number: string }>(
    "SELECT id, full_name, license_number FROM motorists ORDER BY full_name ASC"
  );
  return result.rows;
}

export async function getAdminMotorbikes() {
  const result = await query<{
    id: number;
    registration_number: string;
    brand: string;
    model: string;
    color: string | null;
    purpose: string;
    full_name: string;
    hire_rate: string | null;
  }>(
    `SELECT mb.id, mb.registration_number, mb.brand, mb.model, mb.color, mb.purpose,
            m.full_name, hd.hire_rate::text AS hire_rate
     FROM motorbikes mb
     JOIN motorists m ON m.id = mb.motorist_id
     LEFT JOIN hire_details hd ON hd.motorbike_id = mb.id
     ORDER BY mb.id DESC
     LIMIT 100`
  );
  return result.rows;
}

export async function getAdminUserAccounts() {
  const result = await query<{ id: number; full_name: string; email: string }>(
    "SELECT id, full_name, email FROM user_account WHERE status = 'active' ORDER BY full_name ASC"
  );
  return result.rows;
}

export async function getAdminReceipts() {
  const result = await query<{
    id: number;
    title: string;
    amount: string;
    description: string | null;
    created_at: string;
    full_name: string;
  }>(
    `SELECT r.id, r.title, r.amount::text, r.description, r.created_at::text, u.full_name
     FROM receipts r
     JOIN user_account u ON u.id = r.user_id
     ORDER BY r.created_at DESC
     LIMIT 50`
  );
  return result.rows;
}

export async function getReportSummary() {
  type PurposeRow = { purpose: "commercial" | "personal_transport" | "hire"; count: string };
  type TopRow = { full_name: string; bike_count: string };
  type RecentRow = { full_name: string; date_registered: string; bike_count: string };
  type HireRow = { count: string; avg_rate: string | null };

  const [purpose, topMotorists, recent, hireStats] = await Promise.all([
    query<PurposeRow>(
      "SELECT purpose, COUNT(*)::text AS count FROM motorbikes GROUP BY purpose"
    ),
    query<TopRow>(
      `SELECT m.full_name, COUNT(mb.id)::text AS bike_count
       FROM motorists m
       LEFT JOIN motorbikes mb ON m.id = mb.motorist_id
       GROUP BY m.id, m.full_name
       ORDER BY bike_count::int DESC
       LIMIT 5`
    ),
    query<RecentRow>(
      `SELECT m.full_name, m.date_registered::text, COUNT(mb.id)::text AS bike_count
       FROM motorists m
       LEFT JOIN motorbikes mb ON m.id = mb.motorist_id
       GROUP BY m.id, m.full_name, m.date_registered
       ORDER BY m.date_registered DESC
       LIMIT 5`
    ),
    query<HireRow>(
      "SELECT COUNT(*)::text AS count, AVG(hire_rate)::text AS avg_rate FROM hire_details"
    ),
  ]);

  const purposeMap = {
    commercial: 0,
    personal_transport: 0,
    hire: 0,
  };

  for (const row of purpose.rows as PurposeRow[]) {
    purposeMap[row.purpose] = Number(row.count);
  }

  return {
    purpose: purposeMap,
    topMotorists: topMotorists.rows.map((r) => ({
      ...r,
      bike_count: Number(r.bike_count),
    })),
    recent: recent.rows.map((r) => ({
      ...r,
      bike_count: Number(r.bike_count),
    })),
    hire: {
      count: Number(hireStats.rows[0]?.count ?? 0),
      avgRate: Number(hireStats.rows[0]?.avg_rate ?? 0),
    },
  };
}
FILE_EOF

echo "==> Writing src/app/api/admin/motorists/route.ts"
mkdir -p $(dirname src/app/api/admin/motorists/route.ts)
cat > src/app/api/admin/motorists/route.ts << 'FILE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { getAdminMotorists } from "@/lib/server-data";
import { addMotoristSchema } from "@/lib/validators";
import { getSql, isWorkerRuntime } from "@/lib/db";

export async function GET(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const search = request.nextUrl.searchParams.get("search") ?? "";
  const rows = await getAdminMotorists(search);
  return NextResponse.json(rows);
}

export async function POST(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const parsed = addMotoristSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? "Invalid payload." }, { status: 400 });
  }

  const { fullName, licenseNumber, phoneNumber, email, address } = parsed.data;
  const sql = getSql();
  try {
    await sql.unsafe(
      `INSERT INTO motorists (full_name, license_number, phone_number, email, address)
       VALUES ($1, $2, $3, $4, $5)`,
      [fullName, licenseNumber, phoneNumber, email || null, address || null]
    );
    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Failed to add motorist:", error);
    return NextResponse.json({ error: "Failed to add motorist." }, { status: 500 });
  } finally {
    if (isWorkerRuntime()) {
      await sql.end();
    }
  }
}
FILE_EOF

echo "==> Writing src/app/api/admin/motorbikes/route.ts"
mkdir -p $(dirname src/app/api/admin/motorbikes/route.ts)
cat > src/app/api/admin/motorbikes/route.ts << 'FILE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { getAdminMotorbikes } from "@/lib/server-data";
import { addMotorbikeSchema } from "@/lib/validators";
import { getSql, isWorkerRuntime } from "@/lib/db";

export async function GET(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const rows = await getAdminMotorbikes();
  return NextResponse.json(rows);
}

export async function POST(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const parsed = addMotorbikeSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? "Invalid payload." }, { status: 400 });
  }

  const {
    motoristId,
    registrationNumber,
    brand,
    model,
    color,
    manufactureYear,
    purpose,
    ownerName,
    ownerPhone,
    ownerEmail,
    ownerAddress,
    hireRate,
    hireStartDate,
    hireEndDate,
  } = parsed.data;

  const sql = getSql();
  try {
    await sql.begin(async (tx) => {
      const [motorbike] = await tx.unsafe<{ id: number }[]>(
        `INSERT INTO motorbikes (motorist_id, registration_number, brand, model, color, manufacture_year, purpose)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id`,
        [motoristId, registrationNumber, brand, model, color || null, manufactureYear ?? null, purpose]
      );

      if (purpose === "hire") {
        await tx.unsafe(
          `INSERT INTO hire_details (motorbike_id, owner_name, owner_phone, owner_email, owner_address, hire_rate, hire_start_date, hire_end_date)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [
            motorbike.id,
            ownerName || null,
            ownerPhone || null,
            ownerEmail || null,
            ownerAddress || null,
            hireRate ?? null,
            hireStartDate || null,
            hireEndDate || null,
          ]
        );
      }
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Failed to add motorbike:", error);
    return NextResponse.json({ error: "Failed to add motorbike. Check the registration number is unique." }, { status: 500 });
  } finally {
    if (isWorkerRuntime()) {
      await sql.end();
    }
  }
}
FILE_EOF

echo "==> Writing src/app/api/admin/receipts/route.ts"
mkdir -p $(dirname src/app/api/admin/receipts/route.ts)
cat > src/app/api/admin/receipts/route.ts << 'FILE_EOF'
import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { getAdminReceipts } from "@/lib/server-data";
import { createReceiptSchema } from "@/lib/validators";
import { getSql, isWorkerRuntime } from "@/lib/db";

export async function GET(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const rows = await getAdminReceipts();
  return NextResponse.json(rows);
}

export async function POST(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const parsed = createReceiptSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? "Invalid payload." }, { status: 400 });
  }

  const { userId, title, amount, description } = parsed.data;
  const sql = getSql();
  try {
    await sql.unsafe(
      `INSERT INTO receipts (user_id, title, amount, description, issued_by)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, title, amount, description || null, session.name ?? "System Admin"]
    );
    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Failed to create receipt:", error);
    return NextResponse.json({ error: "Failed to send receipt." }, { status: 500 });
  } finally {
    if (isWorkerRuntime()) {
      await sql.end();
    }
  }
}
FILE_EOF

echo "==> Writing src/components/add-motorist-form.tsx"
mkdir -p $(dirname src/components/add-motorist-form.tsx)
cat > src/components/add-motorist-form.tsx << 'FILE_EOF'
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
    <form onSubmit={onSubmit} className="card-lite" style={{ display: "grid", gap: "0.7rem", marginBottom: "1rem" }}>
      <h3 style={{ margin: 0 }}>Add Motorist</h3>
      <label>Full name<input name="fullName" required minLength={3} /></label>
      <label>License number<input name="licenseNumber" required minLength={4} /></label>
      <label>Phone number<input name="phoneNumber" required minLength={10} /></label>
      <label>Email<input type="email" name="email" /></label>
      <label>Address<textarea name="address" rows={2} /></label>
      {error ? <p className="error">{error}</p> : null}
      <div style={{ display: "flex", gap: "0.5rem" }}>
        <button type="submit" disabled={loading}>{loading ? "Saving..." : "Save Motorist"}</button>
        <button type="button" onClick={() => setOpen(false)} className="logout" style={{ borderColor: "var(--hairline-dark)", color: "var(--ink-muted)" }}>
          Cancel
        </button>
      </div>
    </form>
  );
}
FILE_EOF

echo "==> Writing src/components/add-motorbike-form.tsx"
mkdir -p $(dirname src/components/add-motorbike-form.tsx)
cat > src/components/add-motorbike-form.tsx << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/components/send-receipt-form.tsx"
mkdir -p $(dirname src/components/send-receipt-form.tsx)
cat > src/components/send-receipt-form.tsx << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/app/admin/motorists/page.tsx"
mkdir -p $(dirname src/app/admin/motorists/page.tsx)
cat > src/app/admin/motorists/page.tsx << 'FILE_EOF'
import AppShell from "@/components/app-shell";
import AddMotoristForm from "@/components/add-motorist-form";
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
            </tr>
          </thead>
          <tbody>
            {motorists.map((m) => (
              <tr key={m.id}>
                <td>#{m.id}</td>
                <td>{m.full_name}</td>
                <td>{m.license_number}</td>
                <td>{m.phone_number}</td>
                <td>{m.email ?? "-"}</td>
                <td>{m.bike_count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </AppShell>
  );
}
FILE_EOF

echo "==> Writing src/app/admin/motorbikes/page.tsx"
mkdir -p $(dirname src/app/admin/motorbikes/page.tsx)
cat > src/app/admin/motorbikes/page.tsx << 'FILE_EOF'
import AppShell from "@/components/app-shell";
import AddMotorbikeForm from "@/components/add-motorbike-form";
import { requireServerRole } from "@/lib/auth";
import { getAdminMotorbikes, getMotoristOptions } from "@/lib/server-data";

export default async function AdminMotorbikesPage() {
  await requireServerRole("admin");
  const [motorbikes, motorists] = await Promise.all([getAdminMotorbikes(), getMotoristOptions()]);

  return (
    <AppShell role="admin" title="Motorbikes">
      <AddMotorbikeForm motorists={motorists} />

      <div className="table-wrap" style={{ marginTop: "1.5rem" }}>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Registration</th>
              <th>Motorist</th>
              <th>Brand / Model</th>
              <th>Purpose</th>
              <th>Hire rate</th>
            </tr>
          </thead>
          <tbody>
            {motorbikes.map((mb) => (
              <tr key={mb.id}>
                <td>#{mb.id}</td>
                <td>{mb.registration_number}</td>
                <td>{mb.full_name}</td>
                <td>{mb.brand} {mb.model}</td>
                <td>{mb.purpose}</td>
                <td>{mb.hire_rate ? `KES ${mb.hire_rate}` : "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </AppShell>
  );
}
FILE_EOF

echo "==> Writing src/app/admin/receipts/page.tsx"
mkdir -p $(dirname src/app/admin/receipts/page.tsx)
cat > src/app/admin/receipts/page.tsx << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/components/app-shell.tsx"
mkdir -p $(dirname src/components/app-shell.tsx)
cat > src/components/app-shell.tsx << 'FILE_EOF'
import Link from "next/link";
import type { ReactNode } from "react";

type Props = {
  role: "admin" | "user";
  title: string;
  children: ReactNode;
};

const navByRole = {
  admin: [
    { href: "/admin/dashboard", label: "Dashboard" },
    { href: "/admin/motorists", label: "Motorists" },
    { href: "/admin/motorbikes", label: "Motorbikes" },
    { href: "/admin/receipts", label: "Receipts" },
    { href: "/admin/reports", label: "Reports" },
    { href: "/admin/complaints", label: "Complaints" },
  ],
  user: [
    { href: "/user/dashboard", label: "Dashboard" },
    { href: "/user/profile", label: "Profile" },
    { href: "/user/complaints", label: "Complaints" },
    { href: "/user/receipts", label: "Receipts" },
  ],
};

export default function AppShell({ role, title, children }: Props) {
  const links = navByRole[role];

  return (
    <div className="shell">
      <aside className="sidebar">
        <h2>Motorist Control</h2>
        <p className="muted">{role === "admin" ? "Admin Console" : "Motorist Portal"}</p>
        <nav>
          {links.map((link) => (
            <Link key={link.href} href={link.href} className="nav-link">
              {link.label}
            </Link>
          ))}
        </nav>
        <form action="/api/auth/logout" method="post">
          <button className="logout" type="submit">
            Logout
          </button>
        </form>
      </aside>
      <main className="content">
        <header>
          <h1>{title}</h1>
        </header>
        {children}
      </main>
    </div>
  );
}
FILE_EOF

echo "==> Writing src/middleware.ts"
mkdir -p $(dirname src/middleware.ts)
cat > src/middleware.ts << 'FILE_EOF'
import { NextResponse, type NextRequest } from "next/server";
import { getSessionFromRequest } from "@/lib/session";

const adminPaths = ["/admin/dashboard", "/admin/motorists", "/admin/motorbikes", "/admin/receipts", "/admin/reports", "/admin/complaints"];
const userPaths = ["/user/dashboard", "/user/profile", "/user/complaints", "/user/receipts"];

export async function middleware(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  const { pathname } = request.nextUrl;

  const isAdminPath = adminPaths.some((path) => pathname.startsWith(path));
  const isUserPath = userPaths.some((path) => pathname.startsWith(path));

  if (isAdminPath && (!session || session.role !== "admin")) {
    return NextResponse.redirect(new URL("/admin/login", request.url));
  }

  if (isUserPath && (!session || session.role !== "user")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (pathname === "/admin/login" && session?.role === "admin") {
    return NextResponse.redirect(new URL("/admin/dashboard", request.url));
  }

  if ((pathname === "/login" || pathname === "/register") && session?.role === "user") {
    return NextResponse.redirect(new URL("/user/dashboard", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*", "/user/:path*", "/login", "/register"],
};
FILE_EOF

echo ""
echo "Admin CRUD features written: Add Motorist, Add Motorbike, Send Receipt."
echo "Run: npm run deploy"
