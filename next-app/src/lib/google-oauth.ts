// Minimal, dependency-free Google OAuth 2.0 (Authorization Code flow) helpers.
// Kept edge-safe (no Node-only APIs) so it can run identically in the
// Cloudflare Worker and in local dev.
import { jwtVerify, SignJWT } from "jose";
import type { AppRole } from "@/types/domain";

function getSecretKey() {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error("JWT_SECRET is not set.");
  }
  return new TextEncoder().encode(secret);
}

type OAuthState = { scope: AppRole; nonce: string };

// The "state" param is a short-lived, server-signed JWT (not stored anywhere)
// so the callback can verify it wasn't tampered with and hasn't expired,
// without needing session storage on a stateless Worker.
export async function signOAuthState(scope: AppRole): Promise<string> {
  const nonce = crypto.randomUUID();
  return new SignJWT({ scope, nonce } satisfies OAuthState)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("10m")
    .sign(getSecretKey());
}

export async function verifyOAuthState(token: string): Promise<OAuthState | null> {
  try {
    const { payload } = await jwtVerify<OAuthState>(token, getSecretKey());
    return payload;
  } catch {
    return null;
  }
}

export function getGoogleAuthUrl(state: string, redirectUri: string): string {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  if (!clientId) {
    throw new Error("GOOGLE_CLIENT_ID is not set.");
  }

  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: "code",
    scope: "openid email profile",
    state,
    prompt: "select_account",
    access_type: "online",
  });

  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

type GoogleTokenResponse = {
  access_token: string;
  id_token: string;
  expires_in: number;
  token_type: string;
};

export type GoogleProfile = {
  sub: string;
  email: string;
  email_verified: boolean;
  name?: string;
};

function base64UrlDecode(segment: string): string {
  const base64 = segment.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64 + "===".slice((base64.length + 3) % 4);
  return atob(padded);
}

export function decodeGoogleIdToken(idToken: string): GoogleProfile {
  const segments = idToken.split(".");
  if (segments.length !== 3) {
    throw new Error("Malformed Google id_token.");
  }
  return JSON.parse(base64UrlDecode(segments[1])) as GoogleProfile;
}

// Exchanges an authorization code for tokens via a direct server-to-server
// HTTPS call to Google. Because the id_token arrives over that trusted
// channel (not handed to us by the browser), decoding its payload here is
// sufficient — it doesn't need separate signature verification against
// Google's JWKS the way a client-supplied id_token would.
export async function exchangeGoogleCode(code: string, redirectUri: string): Promise<GoogleProfile> {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new Error("Google sign-in is not configured (missing GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET).");
  }

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      grant_type: "authorization_code",
    }),
  });

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`Google token exchange failed (${response.status}): ${text}`);
  }

  const tokens = (await response.json()) as GoogleTokenResponse;
  const profile = decodeGoogleIdToken(tokens.id_token);

  if (!profile.email || !profile.email_verified) {
    throw new Error("Google account has no verified email address.");
  }

  return profile;
}
