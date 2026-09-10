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
