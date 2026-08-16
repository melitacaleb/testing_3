import bcrypt from "bcryptjs";
import { NextResponse } from "next/server";
import { getSql, isCloudflareWorkers } from "@/lib/db";
import { registerSchema } from "@/lib/validators";
import { setSessionCookie, signSession } from "@/lib/auth";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = registerSchema.safeParse(body);

  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? "Invalid request payload." }, { status: 400 });
  }

  const sql = getSql();
  try {
    const { fullName, email, password, licenseNumber, phoneNumber, address } = parsed.data;

    const existing = await sql.unsafe("SELECT id FROM user_account WHERE email = $1 LIMIT 1", [email]);
    if (existing.length > 0) {
      return NextResponse.json({ error: "That email is already registered." }, { status: 409 });
    }

    const hash = await bcrypt.hash(password, 10);

    const account = await sql.begin(async (tx) => {
      const [motorist] = await tx.unsafe<{ id: number }[]>(
        `INSERT INTO motorists (full_name, license_number, phone_number, email, address)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id`,
        [fullName, licenseNumber, phoneNumber, email, address || null]
      );

      const [account] = await tx.unsafe<{ id: number }[]>(
        `INSERT INTO user_account (full_name, email, password, role, status, motorist_id)
         VALUES ($1, $2, $3, 'user', 'active', $4)
         RETURNING id`,
        [fullName, email, hash, motorist.id]
      );

      return account;
    });

    const token = await signSession({
      userId: account.id,
      role: "user",
      email,
      name: fullName,
    });

    const response = NextResponse.json({ ok: true });
    setSessionCookie(response, token);
    return response;
  } catch {
    return NextResponse.json({ error: "Failed to create account." }, { status: 500 });
  } finally {
    if (isCloudflareWorkers) {
      await sql.end();
    }
  }
}
