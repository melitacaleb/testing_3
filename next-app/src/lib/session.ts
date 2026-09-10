// Edge-safe session helpers (no bcryptjs/next-headers/next-navigation) so
// this module can be imported directly from proxy.ts (Edge middleware).
import { jwtVerify, SignJWT } from "jose";
import type { NextRequest } from "next/server";
import type { SessionPayload } from "@/types/domain";

export const COOKIE_NAME = "mtcs_session";
const JWT_SECRET = process.env.JWT_SECRET;

function getJwtSecretKey() {
  if (!JWT_SECRET) {
    throw new Error("JWT_SECRET is not set.");
  }
  return new TextEncoder().encode(JWT_SECRET);
}

export function signSession(payload: SessionPayload) {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("7d")
    .sign(getJwtSecretKey());
}

export async function verifySession(token: string): Promise<SessionPayload | null> {
  try {
    const { payload } = await jwtVerify<SessionPayload>(token, getJwtSecretKey());
    return payload;
  } catch {
    return null;
  }
}

export async function getSessionFromRequest(request: NextRequest) {
  const token = request.cookies.get(COOKIE_NAME)?.value;
  if (!token) {
    return null;
  }
  return verifySession(token);
}
