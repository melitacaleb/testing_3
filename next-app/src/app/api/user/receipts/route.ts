import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { query } from "@/lib/db";

export async function GET(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "user") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const [receipts, citations] = await Promise.all([
    query<{ id: number; title: string; amount: string; description: string | null; issued_by: string | null; created_at: string }>(
      `SELECT id, title, amount::text, description, issued_by, created_at::text
       FROM receipts
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [session.userId]
    ),
    query<{ id: number; violation: string; amount: string; status: string; issued_at: string }>(
      `SELECT id, violation, amount::text, status, issued_at::text
       FROM citations
       WHERE user_id = $1
       ORDER BY issued_at DESC`,
      [session.userId]
    ),
  ]);

  return NextResponse.json({ receipts: receipts.rows, citations: citations.rows });
}
