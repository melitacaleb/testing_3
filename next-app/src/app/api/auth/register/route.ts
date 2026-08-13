import bcrypt from "bcryptjs";
import { NextResponse } from "next/server";
import { getPool } from "@/lib/db";
import { registerSchema } from "@/lib/validators";
import { setSessionCookie, signSession } from "@/lib/auth";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = registerSchema.safeParse(body);

  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? "Invalid request payload." }, { status: 400 });
  }

  const pool = await getPool();
  const client = await pool.connect();
  try {
    const { fullName, email, password, licenseNumber, phoneNumber, address } = parsed.data;

    const existing = await client.query("SELECT id FROM user_account WHERE email = $1 LIMIT 1", [email]);
    if (existing.rows.length > 0) {
      return NextResponse.json({ error: "That email is already registered." }, { status: 409 });
    }

    await client.query("BEGIN");

    const motoristInsert = await client.query<{ id: number }>(
      `INSERT INTO motorists (full_name, license_number, phone_number, email, address)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [fullName, licenseNumber, phoneNumber, email, address || null]
    );

    const hash = await bcrypt.hash(password, 10);

    const accountInsert = await client.query<{ id: number }>(
      `INSERT INTO user_account (full_name, email, password, role, status, motorist_id)
       VALUES ($1, $2, $3, 'user', 'active', $4)
       RETURNING id`,
      [fullName, email, hash, motoristInsert.rows[0].id]
    );

    await client.query("COMMIT");

    const token = await signSession({
      userId: accountInsert.rows[0].id,
      role: "user",
      email,
      name: fullName,
    });

    const response = NextResponse.json({ ok: true });
    setSessionCookie(response, token);
    return response;
  } catch {
    await client.query("ROLLBACK");
    return NextResponse.json({ error: "Failed to create account." }, { status: 500 });
  } finally {
    client.release();
  }
}
