import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { query } from "@/lib/db";

export async function GET(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "user") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const [receipts, citations, complaints] = await Promise.all([
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM receipts WHERE user_id = $1", [session.userId]),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM citations WHERE user_id = $1", [session.userId]),
    query<{ count: string }>("SELECT COUNT(*)::text AS count FROM complaints WHERE user_id = $1", [session.userId]),
  ]);

  return NextResponse.json({
    receipts: Number(receipts.rows[0]?.count ?? 0),
    citations: Number(citations.rows[0]?.count ?? 0),
    complaints: Number(complaints.rows[0]?.count ?? 0),
  });
}
