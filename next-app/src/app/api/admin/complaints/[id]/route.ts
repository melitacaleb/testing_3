import { NextRequest, NextResponse } from "next/server";
import { complaintResponseSchema } from "@/lib/validators";
import { getSessionFromRequest } from "@/lib/auth";
import { query } from "@/lib/db";

export async function PATCH(
  request: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const parsed = complaintResponseSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid payload." }, { status: 400 });
  }

  const { id } = await context.params;

  await query(
    `UPDATE complaints
     SET status = $1,
         admin_response = $2,
         responder_id = $3,
         responded_at = NOW()
     WHERE id = $4`,
    [parsed.data.status, parsed.data.adminResponse, session.userId, Number(id)]
  );

  return NextResponse.json({ ok: true });
}
