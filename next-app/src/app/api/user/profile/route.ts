import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { query } from "@/lib/db";

export async function GET(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "user") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const account = await query<{ id: number; full_name: string; email: string; motorist_id: number | null }>(
    "SELECT id, full_name, email, motorist_id FROM user_account WHERE id = $1 LIMIT 1",
    [session.userId]
  );

  const row = account.rows[0];
  if (!row?.motorist_id) {
    return NextResponse.json(row ?? null);
  }

  const motorist = await query<{ license_number: string; phone_number: string; address: string | null }>(
    "SELECT license_number, phone_number, address FROM motorists WHERE id = $1 LIMIT 1",
    [row.motorist_id]
  );

  return NextResponse.json({ ...row, ...motorist.rows[0] });
}

export async function PATCH(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "user") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const fullName = String(body?.fullName ?? "").trim();
  const phoneNumber = String(body?.phoneNumber ?? "").trim();
  const address = String(body?.address ?? "").trim();

  if (!fullName || !phoneNumber) {
    return NextResponse.json({ error: "Full name and phone number are required." }, { status: 400 });
  }

  const account = await query<{ motorist_id: number | null }>(
    "SELECT motorist_id FROM user_account WHERE id = $1 LIMIT 1",
    [session.userId]
  );

  await query("UPDATE user_account SET full_name = $1 WHERE id = $2", [fullName, session.userId]);

  if (account.rows[0]?.motorist_id) {
    await query("UPDATE motorists SET full_name = $1, phone_number = $2, address = $3 WHERE id = $4", [
      fullName,
      phoneNumber,
      address || null,
      account.rows[0].motorist_id,
    ]);
  }

  return NextResponse.json({ ok: true });
}
