import bcrypt from "bcryptjs";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { NextResponse } from "next/server";
import type { AppRole } from "@/types/domain";
import { COOKIE_NAME, getSessionFromRequest, signSession, verifySession } from "@/lib/session";

export { getSessionFromRequest, signSession, verifySession };

export async function verifyPassword(password: string, hash: string) {
  return bcrypt.compare(password, hash);
}

export function setSessionCookie(response: NextResponse, token: string) {
  response.cookies.set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 7,
  });
}

export function clearSessionCookie(response: NextResponse) {
  response.cookies.set(COOKIE_NAME, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    expires: new Date(0),
  });
}

export async function getServerSession() {
  const cookieStore = await cookies();
  const token = cookieStore.get(COOKIE_NAME)?.value;

  if (!token) {
    return null;
  }

  return verifySession(token);
}

export async function requireServerRole(role: AppRole) {
  const session = await getServerSession();
  if (!session || session.role !== role) {
    redirect(role === "admin" ? "/admin/login" : "/login");
  }
  return session;
}
