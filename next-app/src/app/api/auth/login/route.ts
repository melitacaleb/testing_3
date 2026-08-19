import { NextResponse } from "next/server";
import { query } from "@/lib/db";
import { loginSchema } from "@/lib/validators";
import { setSessionCookie, signSession, verifyPassword } from "@/lib/auth";

async function handleLogin(request: Request): Promise<Response> {
  const body = await request.json().catch(() => null);
  const parsed = loginSchema.safeParse(body);

  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request payload." }, { status: 400 });
  }

  const { email, password, scope } = parsed.data;

  const table = scope === "admin" ? "users" : "user_account";
  let data;
  try {
    data = await query<{
      id: number;
      full_name: string;
      email: string;
      password: string;
      role: string;
      status: string;
    }>(`SELECT id, full_name, email, password, role, status FROM ${table} WHERE email = $1 LIMIT 1`, [email]);
  } catch (error) {
    console.error("Login DB query failed:", error);
    return NextResponse.json({ error: "Could not reach the database. Please try again." }, { status: 503 });
  }

  const user = data.rows[0];
  if (!user) {
    return NextResponse.json({ error: "Invalid email or password." }, { status: 401 });
  }

  const passwordOk = await verifyPassword(password, user.password);
  if (!passwordOk) {
    return NextResponse.json({ error: "Invalid email or password." }, { status: 401 });
  }

  if (scope === "admin" && user.role !== "admin") {
    return NextResponse.json({ error: "Only admin users can sign in here." }, { status: 403 });
  }

  if (scope === "user" && user.role === "admin") {
    return NextResponse.json({ error: "Admin users must use admin login." }, { status: 403 });
  }

  if (user.status !== "active") {
    return NextResponse.json({ error: "This account is not active." }, { status: 403 });
  }

  const token = await signSession({
    userId: user.id,
    role: scope,
    email: user.email,
    name: user.full_name,
  });

  const response = NextResponse.json({
    ok: true,
    redirectTo: scope === "admin" ? "/admin/dashboard" : "/user/dashboard",
  });
  setSessionCookie(response, token);
  return response;
}

// Top-level wrapper ensures any uncaught error always returns JSON, never an empty 500.
export async function POST(request: Request) {
  try {
    return await handleLogin(request);
  } catch (error) {
    console.error("Unhandled login error:", error);
    const message = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ error: `Server error: ${message}` }, { status: 500 });
  }
}
