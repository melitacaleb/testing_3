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
