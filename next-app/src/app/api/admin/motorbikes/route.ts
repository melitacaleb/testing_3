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
