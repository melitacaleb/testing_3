import { NextRequest, NextResponse } from "next/server";
import { exchangeGoogleCode, verifyOAuthState } from "@/lib/google-oauth";
import { setSessionCookie, signSession } from "@/lib/auth";
import { getSql, isWorkerRuntime } from "@/lib/db";
import type { AppRole } from "@/types/domain";

type Account = {
  id: number;
  full_name: string;
  email: string;
  role: string;
  status: string;
};

export async function GET(request: NextRequest) {
  const origin = request.nextUrl.origin;
  const code = request.nextUrl.searchParams.get("code");
  const stateToken = request.nextUrl.searchParams.get("state");
  const state = stateToken ? await verifyOAuthState(stateToken) : null;
  const scope: AppRole = state?.scope ?? "user";
  const loginPage = scope === "admin" ? "/admin/login" : "/login";

  function fail(message: string) {
    return NextResponse.redirect(new URL(`${loginPage}?error=${encodeURIComponent(message)}`, origin));
  }

  if (!code || !state) {
    return fail("Google sign-in failed or expired. Please try again.");
  }

  const redirectUri = new URL("/api/auth/google/callback", origin).toString();

  let profile;
  try {
    profile = await exchangeGoogleCode(code, redirectUri);
  } catch (error) {
    console.error("Google OAuth exchange failed:", error);
    return fail("Could not complete Google sign-in.");
  }

  const table = scope === "admin" ? "users" : "user_account";
  const sql = getSql();
  try {
    const existingRows = await sql.unsafe<Account[]>(
      `SELECT id, full_name, email, role, status FROM ${table} WHERE email = $1 OR google_id = $2 LIMIT 1`,
      [profile.email, profile.sub]
    );

    let account = existingRows[0];

    if (!account) {
      if (scope === "admin") {
        return fail("No admin account found for this Google email. Ask an existing admin to add you first.");
      }

      const inserted = await sql.unsafe<Account[]>(
        `INSERT INTO user_account (full_name, email, password, role, status, google_id)
         VALUES ($1, $2, NULL, 'user', 'active', $3)
         RETURNING id, full_name, email, role, status`,
        [profile.name || profile.email, profile.email, profile.sub]
      );
      account = inserted[0];
    } else {
      await sql.unsafe(`UPDATE ${table} SET google_id = $1 WHERE id = $2`, [profile.sub, account.id]);
    }

    if (scope === "admin" && account.role !== "admin") {
      return fail("Only admin users can sign in here.");
    }
    if (scope === "user" && account.role === "admin") {
      return fail("Admin users must use admin login.");
    }
    if (account.status !== "active") {
      return fail("This account is not active.");
    }

    const token = await signSession({
      userId: account.id,
      role: scope,
      email: account.email,
      name: account.full_name,
    });

    const redirectTo = scope === "admin" ? "/admin/dashboard" : "/user/dashboard";
    const response = NextResponse.redirect(new URL(redirectTo, origin));
    setSessionCookie(response, token);
    return response;
  } catch (error) {
    console.error("Google OAuth account lookup/creation failed:", error);
    return fail("Something went wrong completing Google sign-in.");
  } finally {
    if (isWorkerRuntime()) {
      await sql.end();
    }
  }
}
