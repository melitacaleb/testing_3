import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { query } from "@/lib/db";

export async function GET(request: NextRequest) {
  const session = getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const result = await query<{
    id: number;
    subject: string;
    message: string;
    status: string;
    admin_response: string | null;
    created_at: string;
    full_name: string | null;
    email: string | null;
  }>(
    `SELECT c.id, c.subject, c.message, c.status, c.admin_response, c.created_at::text,
            u.full_name, u.email
     FROM complaints c
     LEFT JOIN user_account u ON c.user_id = u.id
     ORDER BY c.created_at DESC`
  );

  return NextResponse.json(result.rows);
}
