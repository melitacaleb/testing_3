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
