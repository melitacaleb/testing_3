import { NextRequest, NextResponse } from "next/server";
import { getSessionFromRequest } from "@/lib/auth";
import { editMotoristSchema } from "@/lib/validators";
import { getSql, isWorkerRuntime } from "@/lib/db";

type RouteParams = { params: Promise<{ id: string }> };

export async function PATCH(request: NextRequest, { params }: RouteParams) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const motoristId = Number(id);
  if (!Number.isInteger(motoristId) || motoristId <= 0) {
    return NextResponse.json({ error: "Invalid motorist id." }, { status: 400 });
  }

  const body = await request.json().catch(() => null);
  const parsed = editMotoristSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? "Invalid payload." }, { status: 400 });
  }

  const { fullName, licenseNumber, phoneNumber, email, address } = parsed.data;
  const sql = getSql();
  try {
    const rows = await sql.unsafe(
      `UPDATE motorists
       SET full_name = $1, license_number = $2, phone_number = $3, email = $4, address = $5
       WHERE id = $6
       RETURNING id`,
      [fullName, licenseNumber, phoneNumber, email || null, address || null, motoristId]
    );

    if (rows.length === 0) {
      return NextResponse.json({ error: "Motorist not found." }, { status: 404 });
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Failed to update motorist:", error);
    return NextResponse.json(
      { error: "Failed to update motorist. The license number may already be in use." },
      { status: 500 }
    );
  } finally {
    if (isWorkerRuntime()) {
      await sql.end();
    }
  }
}

export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSessionFromRequest(request);
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const motoristId = Number(id);
  if (!Number.isInteger(motoristId) || motoristId <= 0) {
    return NextResponse.json({ error: "Invalid motorist id." }, { status: 400 });
  }

  const sql = getSql();
  try {
    const rows = await sql.unsafe("DELETE FROM motorists WHERE id = $1 RETURNING id", [motoristId]);

    if (rows.length === 0) {
      return NextResponse.json({ error: "Motorist not found." }, { status: 404 });
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error("Failed to delete motorist:", error);
    return NextResponse.json({ error: "Failed to delete motorist." }, { status: 500 });
  } finally {
    if (isWorkerRuntime()) {
      await sql.end();
    }
  }
}
