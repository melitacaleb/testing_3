import { NextRequest, NextResponse } from "next/server";
import { getGoogleAuthUrl, signOAuthState } from "@/lib/google-oauth";
import type { AppRole } from "@/types/domain";

export async function GET(request: NextRequest) {
  const scopeParam = request.nextUrl.searchParams.get("scope");
  const scope: AppRole = scopeParam === "admin" ? "admin" : "user";
  const loginPage = scope === "admin" ? "/admin/login" : "/login";

  try {
    const state = await signOAuthState(scope);
    const redirectUri = new URL("/api/auth/google/callback", request.nextUrl.origin).toString();
    const authUrl = getGoogleAuthUrl(state, redirectUri);
    return NextResponse.redirect(authUrl);
  } catch (error) {
    console.error("Failed to start Google sign-in:", error);
    const message = error instanceof Error ? error.message : "Google sign-in is not configured.";
    return NextResponse.redirect(
      new URL(`${loginPage}?error=${encodeURIComponent(message)}`, request.nextUrl.origin)
    );
  }
}
