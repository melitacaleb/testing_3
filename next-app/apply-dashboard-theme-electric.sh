#!/usr/bin/env bash
set -e
echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
  echo "ERROR: run this from next-app/ (package.json and src/ not found here)."
  exit 1
fi

echo "==> Ensuring lucide-react is installed"
npm install lucide-react --no-audit --no-fund

echo "==> Writing src/types/domain.ts"
mkdir -p $(dirname src/types/domain.ts)
cat > src/types/domain.ts << 'FILE_EOF'
export type AppRole = "admin" | "user";

export type PowerType = "electric" | "fuel";

export type SessionPayload = {
  userId: number;
  role: AppRole;
  email: string;
  name: string;
};

export type DashboardStats = {
  totalMotorists: number;
  totalMotorbikes: number;
  commercialCount: number;
  hireCount: number;
  personalCount: number;
  electricCount: number;
  fuelCount: number;
};

export type PurposeStats = {
  commercial: number;
  personal_transport: number;
  hire: number;
};

export type UserAccount = {
  id: number;
  full_name: string;
  email: string;
  role: AppRole;
  status: "active" | "inactive";
  motorist_id: number | null;
};
FILE_EOF

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

echo "==> Writing src/lib/server-data.ts"
mkdir -p $(dirname src/lib/server-data.ts)
cat > src/lib/server-data.ts << 'FILE_EOF'
import { query } from "@/lib/db";
import type { DashboardStats } from "@/types/domain";

export async function getAdminDashboardStats(): Promise<DashboardStats> {
  const [motorists, bikes, commercial, hire, personal, electric, fuel] = await Promise.all([
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorists"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes WHERE purpose = 'commercial'"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes WHERE purpose = 'hire'"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes WHERE purpose = 'personal_transport'"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes WHERE power_type = 'electric'"),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM motorbikes WHERE power_type = 'fuel'"),
  ]);

  return {
    totalMotorists: Number(motorists.rows[0]?.count ?? 0),
    totalMotorbikes: Number(bikes.rows[0]?.count ?? 0),
    commercialCount: Number(commercial.rows[0]?.count ?? 0),
    hireCount: Number(hire.rows[0]?.count ?? 0),
    personalCount: Number(personal.rows[0]?.count ?? 0),
    electricCount: Number(electric.rows[0]?.count ?? 0),
    fuelCount: Number(fuel.rows[0]?.count ?? 0),
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
    power_type: string;
    full_name: string;
    hire_rate: string | null;
  }>(
    `SELECT mb.id, mb.registration_number, mb.brand, mb.model, mb.color, mb.purpose, mb.power_type,
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
       ORDER BY COUNT(mb.id) DESC
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
    powerType,
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
        `INSERT INTO motorbikes (motorist_id, registration_number, brand, model, color, manufacture_year, purpose, power_type)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING id`,
        [motoristId, registrationNumber, brand, model, color || null, manufactureYear ?? null, purpose, powerType]
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
              <th>Power</th>
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
                <td>
                  <span className={`badge ${mb.power_type === "electric" ? "badge-completed" : "badge-pending"}`}>
                    {mb.power_type === "electric" ? "Electric" : "Fuel"}
                  </span>
                </td>
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

echo "==> Writing src/app/admin/dashboard/page.tsx"
mkdir -p $(dirname src/app/admin/dashboard/page.tsx)
cat > src/app/admin/dashboard/page.tsx << 'FILE_EOF'
import Link from "next/link";
import { Users, Bike, Briefcase, Handshake, Car, Zap, Fuel, UserPlus, Receipt, FileBarChart } from "lucide-react";
import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { getAdminDashboardStats } from "@/lib/server-data";

export default async function AdminDashboardPage() {
  const session = await requireServerRole("admin");
  const stats = await getAdminDashboardStats();

  const purposeTotal = stats.commercialCount + stats.hireCount + stats.personalCount || 1;
  const commercialPct = (stats.commercialCount / purposeTotal) * 100;
  const hirePct = (stats.hireCount / purposeTotal) * 100;
  const commercialEnd = commercialPct;
  const hireEnd = commercialPct + hirePct;

  const powerTotal = stats.electricCount + stats.fuelCount || 1;
  const electricPct = (stats.electricCount / powerTotal) * 100;

  return (
    <AppShell role="admin" title={`Welcome, ${session.name}`}>
      <div className="stat-grid">
        <article className="stat-card">
          <span><Users size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Total Motorists</span>
          <p>{stats.totalMotorists}</p>
        </article>
        <article className="stat-card">
          <span><Bike size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Total Motorbikes</span>
          <p>{stats.totalMotorbikes}</p>
        </article>
        <article className="stat-card">
          <span><Briefcase size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Commercial</span>
          <p>{stats.commercialCount}</p>
        </article>
        <article className="stat-card">
          <span><Handshake size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />On Hire</span>
          <p>{stats.hireCount}</p>
        </article>
        <article className="stat-card">
          <span><Car size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Personal</span>
          <p>{stats.personalCount}</p>
        </article>
        <article className="stat-card">
          <span><Zap size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Electric</span>
          <p>{stats.electricCount}</p>
        </article>
      </div>

      <div className="two-col" style={{ marginTop: "1.5rem" }}>
        <div className="card-lite" style={{ borderLeft: "3px solid var(--accent)" }}>
          <h3 style={{ marginTop: 0 }}>Fleet by purpose</h3>
          <div style={{ display: "flex", alignItems: "center", gap: "1.5rem", flexWrap: "wrap" }}>
            <div className="donut-wrap">
              <div
                className="donut"
                style={{
                  background: `conic-gradient(var(--accent) 0% ${commercialEnd}%, var(--glow) ${commercialEnd}% ${hireEnd}%, var(--amber) ${hireEnd}% 100%)`,
                }}
              />
              <div className="donut-hole">
                <strong>{stats.totalMotorbikes}</strong>
                <span>Bikes</span>
              </div>
            </div>
            <ul className="legend">
              <li><span className="dot" style={{ background: "var(--accent)" }} />Commercial — {stats.commercialCount}</li>
              <li><span className="dot" style={{ background: "var(--glow)" }} />On hire — {stats.hireCount}</li>
              <li><span className="dot" style={{ background: "var(--amber)" }} />Personal — {stats.personalCount}</li>
            </ul>
          </div>
        </div>

        <div className="card-lite" style={{ borderLeft: "3px solid var(--success)" }}>
          <h3 style={{ marginTop: 0 }}>Electric vs Fuel</h3>
          <div className="power-bar">
            <div className="power-bar-electric" style={{ width: `${electricPct}%` }} />
            <div className="power-bar-fuel" style={{ width: `${100 - electricPct}%` }} />
          </div>
          <ul className="legend" style={{ marginTop: "1rem" }}>
            <li><Zap size={14} style={{ color: "var(--success)" }} /> Electric — {stats.electricCount}</li>
            <li><Fuel size={14} style={{ color: "var(--ink-muted)" }} /> Fuel — {stats.fuelCount}</li>
          </ul>
        </div>
      </div>

      <h3 style={{ marginTop: "1.75rem" }}>Quick actions</h3>
      <div className="quick-actions">
        <Link href="/admin/motorists" className="quick-action">
          <span className="quick-action-icon"><UserPlus size={20} /></span>
          <div>
            <strong>Add Motorist</strong>
            <p className="muted" style={{ margin: 0, fontSize: "0.82rem" }}>Register a new motorist</p>
          </div>
        </Link>
        <Link href="/admin/motorbikes" className="quick-action">
          <span className="quick-action-icon"><Bike size={20} /></span>
          <div>
            <strong>Add Motorbike</strong>
            <p className="muted" style={{ margin: 0, fontSize: "0.82rem" }}>Register a bike or hire unit</p>
          </div>
        </Link>
        <Link href="/admin/receipts" className="quick-action">
          <span className="quick-action-icon"><Receipt size={20} /></span>
          <div>
            <strong>Send Receipt</strong>
            <p className="muted" style={{ margin: 0, fontSize: "0.82rem" }}>Issue a payment receipt</p>
          </div>
        </Link>
        <Link href="/admin/reports" className="quick-action">
          <span className="quick-action-icon"><FileBarChart size={20} /></span>
          <div>
            <strong>View Reports</strong>
            <p className="muted" style={{ margin: 0, fontSize: "0.82rem" }}>Full breakdowns and trends</p>
          </div>
        </Link>
      </div>
    </AppShell>
  );
}
FILE_EOF

echo "==> Writing src/app/globals.css"
mkdir -p $(dirname src/app/globals.css)
cat > src/app/globals.css << 'FILE_EOF'
@import "tailwindcss";

:root {
  --bg-deep: #060b16;
  --bg-deep-2: #0a1428;
  --panel: #101c34;
  --panel-alt: #14213e;
  --glow: #2fb6ff;
  --accent: #2e6bff;
  --accent-2: #6a4bff;
  --amber: #ffab3e;
  --danger: #ff5470;
  --success: #33dd93;
  --ink: #f2f6ff;
  --ink-muted: #8ea0c7;
  --hairline: rgba(255, 255, 255, 0.08);
  --hairline-strong: rgba(255, 255, 255, 0.14);
}

[data-theme="light"] {
  --bg-deep: #f5f7fb;
  --bg-deep-2: #eef1f8;
  --panel: #ffffff;
  --panel-alt: #eef2fa;
  --glow: #1d8fe0;
  --accent: #2e6bff;
  --accent-2: #6a4bff;
  --amber: #b5710f;
  --danger: #d1284a;
  --success: #14966a;
  --ink: #101828;
  --ink-muted: #5b6b8c;
  --hairline: rgba(16, 24, 40, 0.08);
  --hairline-strong: rgba(16, 24, 40, 0.14);
}

[data-theme="light"] body {
  background:
    radial-gradient(1200px 600px at 15% -10%, rgba(46, 107, 255, 0.12), transparent 60%),
    radial-gradient(900px 500px at 100% 0%, rgba(106, 75, 255, 0.1), transparent 55%),
    var(--bg-deep);
}

[data-theme="light"] .hero h1,
[data-theme="light"] .stat-card p {
  background: linear-gradient(135deg, #101828, #1d63e0 70%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

[data-theme="light"] input,
[data-theme="light"] textarea,
[data-theme="light"] select,
[data-theme="light"] th {
  background: rgba(16, 24, 40, 0.03);
}

[data-theme="light"] .hero,
[data-theme="light"] .card,
[data-theme="light"] .card-lite,
[data-theme="light"] .stat-card,
[data-theme="light"] .table-wrap,
[data-theme="light"] .ride-form,
[data-theme="light"] .quick-action {
  box-shadow: 0 12px 34px rgba(16, 24, 40, 0.08);
}

@theme inline {
  --color-background: var(--bg-deep);
  --color-foreground: var(--ink);
  --font-sans: var(--font-plex-sans);
  --font-display: var(--font-sora);
  --font-mono: var(--font-plex-mono);
}

* {
  box-sizing: border-box;
}

body {
  background:
    radial-gradient(1200px 600px at 15% -10%, rgba(46, 107, 255, 0.25), transparent 60%),
    radial-gradient(900px 500px at 100% 0%, rgba(106, 75, 255, 0.18), transparent 55%),
    var(--bg-deep);
  color: var(--ink);
  font-family: var(--font-plex-sans), sans-serif;
  font-size: 15px;
  line-height: 1.55;
}

a {
  color: var(--glow);
}

h1,
h2,
h3 {
  font-family: var(--font-sora), sans-serif;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--ink);
}

/* ---------- Landing: glowing hero ---------- */

.landing {
  min-height: 100vh;
  display: grid;
  place-content: center;
  padding: 2rem;
  position: relative;
  overflow: hidden;
}

.hero {
  position: relative;
  max-width: 720px;
  background: linear-gradient(180deg, var(--panel-alt), var(--panel));
  border: 1px solid var(--hairline-strong);
  border-radius: 28px;
  padding: 3rem 2.5rem;
  box-shadow: 0 40px 90px rgba(0, 0, 0, 0.55), 0 0 0 1px rgba(255, 255, 255, 0.02) inset;
  overflow: hidden;
}

.hero::after {
  content: "";
  position: absolute;
  top: -140px;
  right: -140px;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(47, 182, 255, 0.55), rgba(47, 182, 255, 0) 70%);
  pointer-events: none;
}

.hero::before {
  content: "SYSTEM ONLINE";
  position: relative;
  z-index: 1;
  display: inline-block;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.68rem;
  font-weight: 600;
  letter-spacing: 0.18em;
  color: var(--glow);
  background: rgba(47, 182, 255, 0.12);
  border: 1px solid rgba(47, 182, 255, 0.35);
  border-radius: 999px;
  padding: 0.3rem 0.8rem;
  margin-bottom: 1.5rem;
}

.hero h1 {
  position: relative;
  z-index: 1;
  font-size: clamp(2rem, 5.5vw, 3.1rem);
  line-height: 1.08;
  margin: 0;
  background: linear-gradient(135deg, #ffffff, #b9ccff 70%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.muted {
  color: var(--ink-muted);
}

.hero .muted {
  position: relative;
  z-index: 1;
  margin-top: 0.9rem;
  max-width: 46ch;
}

.hero-actions {
  position: relative;
  z-index: 1;
  margin-top: 2rem;
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.hero-actions a {
  display: inline-block;
  padding: 0.75rem 1.3rem;
  border-radius: 999px;
  text-decoration: none;
  font-weight: 600;
  font-size: 0.9rem;
  border: 1px solid var(--hairline-strong);
  color: var(--ink);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.hero-actions a:first-child {
  background: linear-gradient(135deg, var(--accent), var(--glow));
  border: none;
  color: #071224;
  box-shadow: 0 8px 30px rgba(47, 182, 255, 0.45);
}

.hero-actions a:hover {
  transform: translateY(-2px);
}

/* ---------- Auth ---------- */

.auth-wrap {
  min-height: 100vh;
  display: grid;
  place-content: center;
  padding: 1.5rem;
}

.card,
.card-lite {
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 20px;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.35);
}

.card {
  width: min(440px, 92vw);
  padding: 2rem;
  display: grid;
  gap: 1rem;
}

.card h1 {
  font-size: 1.5rem;
}

.card label {
  display: grid;
  gap: 0.35rem;
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--ink-muted);
}

input,
textarea,
button,
select {
  font: inherit;
}

input,
textarea,
select {
  border: 1px solid var(--hairline-strong);
  border-radius: 12px;
  padding: 0.7rem 0.85rem;
  background: rgba(255, 255, 255, 0.03);
  color: var(--ink);
  font-family: var(--font-plex-sans), sans-serif;
}

input::placeholder,
textarea::placeholder {
  color: rgba(142, 160, 199, 0.6);
}

input:focus-visible,
textarea:focus-visible,
select:focus-visible,
button:focus-visible,
a:focus-visible {
  outline: 2px solid var(--glow);
  outline-offset: 2px;
}

button {
  border: 0;
  border-radius: 999px;
  padding: 0.8rem 1.2rem;
  background: linear-gradient(135deg, var(--accent), var(--glow));
  color: #071224;
  font-weight: 700;
  font-size: 0.88rem;
  cursor: pointer;
  box-shadow: 0 10px 26px rgba(47, 182, 255, 0.35);
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}

button:hover {
  transform: translateY(-1px);
  box-shadow: 0 14px 32px rgba(47, 182, 255, 0.45);
}

button:disabled {
  opacity: 0.55;
  cursor: default;
  box-shadow: none;
}

.error {
  color: var(--danger);
  font-size: 0.9rem;
  font-weight: 500;
}

.auth-link {
  text-align: center;
  font-size: 0.9rem;
  color: var(--ink-muted);
}

/* ---------- App shell / console ---------- */

.shell {
  min-height: 100vh;
  display: grid;
  grid-template-columns: 250px 1fr;
}

.sidebar {
  background: linear-gradient(180deg, var(--panel-alt), var(--bg-deep-2));
  color: var(--ink);
  padding: 1.5rem 1.1rem;
  display: flex;
  flex-direction: column;
  gap: 1.2rem;
  border-right: 1px solid var(--hairline);
}

.sidebar h2 {
  margin: 0;
  font-size: 1.15rem;
}

.sidebar .muted {
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.68rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--glow);
  margin-top: -0.7rem;
}

.sidebar nav {
  display: grid;
  gap: 0.3rem;
  margin-top: 0.5rem;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.65rem 0.85rem;
  border-radius: 14px;
  color: var(--ink-muted);
  text-decoration: none;
  font-size: 0.92rem;
  font-weight: 500;
  transition: background 0.15s ease, color 0.15s ease;
}

.nav-link:hover {
  background: rgba(47, 182, 255, 0.1);
  color: var(--ink);
}

.nav-link.active {
  background: linear-gradient(135deg, rgba(46, 107, 255, 0.35), rgba(47, 182, 255, 0.25));
  color: #fff;
  box-shadow: 0 0 0 1px rgba(47, 182, 255, 0.4) inset;
}

.logout {
  margin-top: auto;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  background: transparent;
  border: 1px solid rgba(255, 84, 112, 0.5);
  color: #ff93a8;
  box-shadow: none;
}

.logout:hover {
  background: rgba(255, 84, 112, 0.12);
  transform: none;
  box-shadow: none;
}

.content {
  padding: 1.75rem 2rem;
}

.content > header {
  margin-bottom: 1.5rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid var(--hairline);
}

.content h1 {
  font-size: 1.6rem;
  margin: 0;
}

/* ---------- Stat cards: glowing ring signature ---------- */

.stat-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
}

.stat-card {
  position: relative;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 18px;
  padding: 1.25rem 1.1rem;
  overflow: hidden;
}

.stat-card::before {
  content: "";
  position: absolute;
  top: -30px;
  right: -30px;
  width: 90px;
  height: 90px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(47, 182, 255, 0.4), rgba(47, 182, 255, 0) 70%);
}

.stat-card p {
  font-family: var(--font-plex-mono), monospace;
  font-size: 1.85rem;
  font-weight: 600;
  margin: 0.4rem 0 0;
  background: linear-gradient(135deg, #fff, var(--glow));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.stat-card span,
.stat-card label {
  font-size: 0.72rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink-muted);
}

/* ---------- Ride booking ---------- */

.ride-booking {
  max-width: 720px;
  display: grid;
  gap: 1rem;
}

.ride-booking-copy {
  padding: 1rem 0 0;
}

.ride-booking-copy h2 {
  margin: 0.2rem 0;
  font-size: 1.35rem;
}

.ride-kicker {
  margin: 0;
  color: var(--glow);
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.ride-route {
  display: flex;
  align-items: center;
  width: min(100%, 420px);
  padding-top: 0.75rem;
}

.ride-stop {
  width: 14px;
  height: 14px;
  flex: 0 0 auto;
  border: 3px solid var(--bg-deep);
  border-radius: 50%;
  box-shadow: 0 0 0 2px var(--glow), 0 0 14px rgba(47, 182, 255, 0.6);
}

.ride-stop--end {
  border-radius: 4px;
  box-shadow: 0 0 0 2px var(--amber), 0 0 14px rgba(255, 171, 62, 0.55);
}

.ride-route-line {
  height: 3px;
  width: 100%;
  background: repeating-linear-gradient(90deg, var(--glow) 0 10px, transparent 10px 16px);
  opacity: 0.6;
}

.ride-form {
  display: grid;
  gap: 0.9rem;
  padding: 1.5rem;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 20px;
}

.ride-form label {
  display: grid;
  gap: 0.35rem;
  font-size: 0.85rem;
  color: var(--ink-muted);
}

.ride-location {
  justify-self: start;
  padding: 0.6rem 0.9rem;
  color: var(--glow);
  background: rgba(47, 182, 255, 0.08);
  border: 1px solid rgba(47, 182, 255, 0.35);
  box-shadow: none;
}

.ride-location:hover {
  background: rgba(47, 182, 255, 0.18);
  transform: none;
  box-shadow: none;
}

.ride-estimate {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.9rem 1rem;
  color: var(--ink);
  background: rgba(46, 107, 255, 0.1);
  border: 1px solid rgba(46, 107, 255, 0.3);
  border-radius: 14px;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.9rem;
}

.ride-estimate strong {
  text-align: right;
  font-size: 0.9rem;
  color: var(--glow);
}

.ride-message {
  margin: 0;
  padding: 0.9rem 1rem;
  color: var(--ink);
  background: rgba(255, 171, 62, 0.1);
  border: 1px solid rgba(255, 171, 62, 0.35);
  border-radius: 14px;
  font-size: 0.9rem;
}

/* ---------- Status badges ---------- */

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.25rem 0.65rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}

.badge-pending {
  color: var(--amber);
  background: rgba(255, 171, 62, 0.14);
  border: 1px solid rgba(255, 171, 62, 0.35);
}

.badge-assigned {
  color: var(--glow);
  background: rgba(47, 182, 255, 0.14);
  border: 1px solid rgba(47, 182, 255, 0.35);
}

.badge-completed {
  color: var(--success);
  background: rgba(51, 221, 147, 0.14);
  border: 1px solid rgba(51, 221, 147, 0.35);
}

.badge-cancelled {
  color: var(--danger);
  background: rgba(255, 84, 112, 0.14);
  border: 1px solid rgba(255, 84, 112, 0.35);
}

/* ---------- Data / tables ---------- */

.inline-form {
  display: flex;
  gap: 0.6rem;
  margin: 1rem 0;
}

.table-wrap {
  overflow-x: auto;
  margin-top: 1rem;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 18px;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.92rem;
}

th {
  text-align: left;
  padding: 0.75rem 0.9rem;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.7rem;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: var(--ink-muted);
  background: rgba(255, 255, 255, 0.02);
  border-bottom: 1px solid var(--hairline);
}

td {
  text-align: left;
  padding: 0.75rem 0.9rem;
  border-bottom: 1px solid var(--hairline);
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.88rem;
  color: var(--ink);
}

tr:last-child td {
  border-bottom: none;
}

tr:hover td {
  background: rgba(255, 255, 255, 0.02);
}

.two-col {
  margin-top: 1rem;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}

.card-lite {
  padding: 1.1rem;
  border-left: 3px solid var(--accent);
}

.stack-list {
  margin-top: 1rem;
  display: grid;
  gap: 0.8rem;
}

@media (max-width: 860px) {
  .shell {
    grid-template-columns: 1fr;
  }

  .sidebar {
    border-right: none;
    border-bottom: 1px solid var(--hairline);
  }
}

@media (prefers-reduced-motion: reduce) {
  * {
    transition: none !important;
  }
}

/* ---------- Theme toggle ---------- */

.theme-toggle {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 50;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.5rem 0.9rem;
  border-radius: 999px;
  background: var(--panel);
  border: 1px solid var(--hairline-strong);
  color: var(--ink);
  font-size: 0.78rem;
  font-weight: 600;
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.25);
}

.theme-toggle:hover {
  transform: translateY(-1px);
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.3);
}

/* ---------- Collapsible sidebar ---------- */

.sidebar-toggle {
  align-self: flex-end;
  background: transparent;
  border: 1px solid var(--hairline-strong);
  color: var(--ink-muted);
  padding: 0.35rem;
  border-radius: 8px;
  box-shadow: none;
  width: auto;
}

.sidebar-toggle:hover {
  color: var(--ink);
  background: rgba(255, 255, 255, 0.05);
  transform: none;
  box-shadow: none;
}

.sidebar.collapsed {
  padding: 1.5rem 0.6rem;
}

.sidebar.collapsed h2,
.sidebar.collapsed .muted,
.sidebar.collapsed .nav-label,
.sidebar.collapsed .logout-label {
  display: none;
}

.sidebar.collapsed .nav-link {
  justify-content: center;
  padding: 0.65rem;
}

.sidebar.collapsed .logout {
  display: flex;
  justify-content: center;
  padding: 0.65rem;
}

/* ---------- Dashboard: donut, legend, power bar, quick actions ---------- */

.donut-wrap {
  position: relative;
  width: 150px;
  height: 150px;
  flex: 0 0 auto;
}

.donut {
  width: 100%;
  height: 100%;
  border-radius: 50%;
}

.donut-hole {
  position: absolute;
  inset: 20px;
  border-radius: 50%;
  background: var(--panel);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
}

.donut-hole strong {
  font-family: var(--font-plex-mono), monospace;
  font-size: 1.5rem;
  color: var(--ink);
}

.donut-hole span {
  font-size: 0.65rem;
  color: var(--ink-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.55rem;
  font-size: 0.88rem;
  color: var(--ink);
}

.legend li {
  display: flex;
  align-items: center;
  gap: 0.55rem;
}

.legend .dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex: 0 0 auto;
}

.power-bar {
  display: flex;
  height: 14px;
  border-radius: 999px;
  overflow: hidden;
  background: var(--hairline);
}

.power-bar-electric {
  background: linear-gradient(135deg, var(--success), #22c55e);
}

.power-bar-fuel {
  background: linear-gradient(135deg, var(--ink-muted), #64748b);
}

.quick-actions {
  margin-top: 0.75rem;
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
}

.quick-action {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  padding: 1.1rem;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 16px;
  text-decoration: none;
  color: var(--ink);
  transition: transform 0.15s ease, border-color 0.15s ease;
}

.quick-action:hover {
  transform: translateY(-2px);
  border-color: var(--accent);
}

.quick-action-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 42px;
  height: 42px;
  border-radius: 12px;
  flex: 0 0 auto;
  background: linear-gradient(135deg, rgba(46, 107, 255, 0.18), rgba(47, 182, 255, 0.18));
  color: var(--glow);
}
FILE_EOF

echo "==> Writing src/app/layout.tsx"
mkdir -p $(dirname src/app/layout.tsx)
cat > src/app/layout.tsx << 'FILE_EOF'
import type { Metadata } from "next";
import { Sora, IBM_Plex_Sans, IBM_Plex_Mono } from "next/font/google";
import Script from "next/script";
import ThemeToggle from "@/components/theme-toggle";
import "./globals.css";

const sora = Sora({
  variable: "--font-sora",
  subsets: ["latin"],
  weight: ["600", "700", "800"],
});

const plexSans = IBM_Plex_Sans({
  variable: "--font-plex-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
});

const plexMono = IBM_Plex_Mono({
  variable: "--font-plex-mono",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
});

export const metadata: Metadata = {
  title: "Motorist Traffic Control System",
  description: "Next.js migration of the motorist management application.",
};

const themeInitScript = `
  (function () {
    try {
      var stored = localStorage.getItem("theme");
      var theme = stored || (window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");
      document.documentElement.setAttribute("data-theme", theme);
    } catch (e) {
      document.documentElement.setAttribute("data-theme", "dark");
    }
  })();
`;

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${sora.variable} ${plexSans.variable} ${plexMono.variable} h-full antialiased`}
    >
      <head>
        <Script id="theme-init" strategy="beforeInteractive">
          {themeInitScript}
        </Script>
      </head>
      <body className="min-h-full flex flex-col">
        <ThemeToggle />
        {children}
      </body>
    </html>
  );
}
FILE_EOF

echo "==> Writing src/components/theme-toggle.tsx"
mkdir -p $(dirname src/components/theme-toggle.tsx)
cat > src/components/theme-toggle.tsx << 'FILE_EOF'
"use client";

import { useEffect, useState } from "react";
import { Sun, Moon } from "lucide-react";

type Theme = "dark" | "light";

export default function ThemeToggle() {
  const [theme, setTheme] = useState<Theme | null>(null);

  useEffect(() => {
    // Reads the theme already applied by the pre-hydration script in layout.tsx.
    // Doing this in an effect (not a lazy useState initializer) avoids a
    // server/client hydration mismatch, since the server always renders "dark".
    const current = document.documentElement.getAttribute("data-theme") as Theme | null;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setTheme(current ?? "dark");
  }, []);

  function toggle() {
    const next: Theme = theme === "light" ? "dark" : "light";
    setTheme(next);
    document.documentElement.setAttribute("data-theme", next);
    try {
      localStorage.setItem("theme", next);
    } catch {
      // localStorage may be unavailable (private browsing); theme just won't persist.
    }
  }

  if (!theme) {
    return null;
  }

  return (
    <button type="button" onClick={toggle} className="theme-toggle" aria-label="Toggle color theme">
      {theme === "light" ? <Moon size={16} /> : <Sun size={16} />}
      {theme === "light" ? "Dark" : "Light"}
    </button>
  );
}
FILE_EOF

echo "==> Writing src/components/app-shell.tsx"
mkdir -p $(dirname src/components/app-shell.tsx)
cat > src/components/app-shell.tsx << 'FILE_EOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";
import {
  LayoutDashboard,
  Users,
  Bike,
  Receipt,
  FileBarChart,
  MessageSquareWarning,
  UserCircle,
  ChevronLeft,
  ChevronRight,
  LogOut,
} from "lucide-react";

type Props = {
  role: "admin" | "user";
  title: string;
  children: ReactNode;
};

const navByRole = {
  admin: [
    { href: "/admin/dashboard", label: "Dashboard", icon: LayoutDashboard },
    { href: "/admin/motorists", label: "Motorists", icon: Users },
    { href: "/admin/motorbikes", label: "Motorbikes", icon: Bike },
    { href: "/admin/receipts", label: "Receipts", icon: Receipt },
    { href: "/admin/reports", label: "Reports", icon: FileBarChart },
    { href: "/admin/complaints", label: "Complaints", icon: MessageSquareWarning },
  ],
  user: [
    { href: "/user/dashboard", label: "Dashboard", icon: LayoutDashboard },
    { href: "/user/profile", label: "Profile", icon: UserCircle },
    { href: "/user/complaints", label: "Complaints", icon: MessageSquareWarning },
    { href: "/user/receipts", label: "Receipts", icon: Receipt },
  ],
};

const SIDEBAR_STORAGE_KEY = "sidebar-collapsed";

export default function AppShell({ role, title, children }: Props) {
  const links = navByRole[role];
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    try {
      const stored = localStorage.getItem(SIDEBAR_STORAGE_KEY);
      if (stored === "true") {
        // Syncing from localStorage (an external system) after mount, since
        // it isn't available during server rendering. Avoids a hydration
        // mismatch versus reading it in a lazy useState initializer.
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setCollapsed(true);
      }
    } catch {
      // localStorage unavailable; default to expanded.
    }
  }, []);

  function toggleCollapsed() {
    setCollapsed((prev) => {
      const next = !prev;
      try {
        localStorage.setItem(SIDEBAR_STORAGE_KEY, String(next));
      } catch {
        // ignore persistence failure
      }
      return next;
    });
  }

  return (
    <div className="shell" style={{ gridTemplateColumns: collapsed ? "84px 1fr" : "250px 1fr" }}>
      <aside className={`sidebar${collapsed ? " collapsed" : ""}`}>
        <button
          type="button"
          className="sidebar-toggle"
          onClick={toggleCollapsed}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
        <h2>Motorist Control</h2>
        <p className="muted">{role === "admin" ? "Admin Console" : "Motorist Portal"}</p>
        <nav>
          {links.map((link) => {
            const Icon = link.icon;
            const isActive = pathname?.startsWith(link.href);
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`nav-link${isActive ? " active" : ""}`}
                title={collapsed ? link.label : undefined}
              >
                <Icon size={18} strokeWidth={2} />
                <span className="nav-label">{link.label}</span>
              </Link>
            );
          })}
        </nav>
        <form action="/api/auth/logout" method="post">
          <button className="logout" type="submit" title={collapsed ? "Logout" : undefined}>
            <LogOut size={16} />
            <span className="logout-label">Logout</span>
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

echo ""
echo "IMPORTANT: this only updates code. You must also run this SQL in your"
echo "Supabase SQL editor (Database > SQL Editor) BEFORE deploying, or"
echo "adding a motorbike will fail:"
echo ""
echo "  ALTER TABLE motorbikes ADD COLUMN IF NOT EXISTS power_type VARCHAR(20) NOT NULL DEFAULT 'fuel' CHECK (power_type IN ('electric','fuel'));"
echo ""
echo "Done. After running that SQL, run: npm run deploy"
