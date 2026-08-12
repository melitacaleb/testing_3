import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { query } from "@/lib/db";
import { createComplaintSchema } from "@/lib/validators";

export async function GET(request: NextRequest) {
  const session = getSessionFromRequest(request);
  if (!session || session.role !== "user") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const result = await query<{ id: number; subject: string; message: string; status: string; admin_response: string | null; created_at: string }>(
    `SELECT id, subject, message, status, admin_response, created_at::text
     FROM complaints
     WHERE user_id = $1
     ORDER BY created_at DESC`,
    [session.userId]
  );

  return NextResponse.json(result.rows);
}

export async function POST(request: NextRequest) {
  const session = getSessionFromRequest(request);
  if (!session || session.role !== "user") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const parsed = createComplaintSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Please fill all complaint fields." }, { status: 400 });
  }

  await query(
    "INSERT INTO complaints (user_id, subject, message, status) VALUES ($1, $2, $3, 'open')",
    [session.userId, parsed.data.subject, parsed.data.message]
  );

  return NextResponse.json({ ok: true });
}
