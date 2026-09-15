#!/usr/bin/env bash
set -e
echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
  echo "ERROR: run this from next-app/ (package.json and src/ not found here)."
  exit 1
fi

echo "==> Writing src/lib/google-oauth.ts"
mkdir -p "$(dirname "src/lib/google-oauth.ts")"
cat > "src/lib/google-oauth.ts" << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/lib/google-oauth.test.ts"
mkdir -p "$(dirname "src/lib/google-oauth.test.ts")"
cat > "src/lib/google-oauth.test.ts" << 'FILE_EOF'
import { beforeAll, describe, expect, it } from "vitest";
import { decodeGoogleIdToken, getGoogleAuthUrl, signOAuthState, verifyOAuthState } from "./google-oauth";

beforeAll(() => {
  process.env.JWT_SECRET = "test-secret-key-for-unit-tests-only";
  process.env.GOOGLE_CLIENT_ID = "test-client-id.apps.googleusercontent.com";
});

function base64UrlEncode(json: unknown): string {
  const base64 = btoa(JSON.stringify(json));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

describe("OAuth state sign/verify", () => {
  it("round-trips a valid state token", async () => {
    const token = await signOAuthState("admin");
    const result = await verifyOAuthState(token);

    expect(result).not.toBeNull();
    expect(result?.scope).toBe("admin");
    expect(typeof result?.nonce).toBe("string");
  });

  it("produces a different nonce on each call", async () => {
    const tokenA = await signOAuthState("user");
    const tokenB = await signOAuthState("user");

    const resultA = await verifyOAuthState(tokenA);
    const resultB = await verifyOAuthState(tokenB);

    expect(resultA?.nonce).not.toBe(resultB?.nonce);
  });

  it("rejects a tampered token", async () => {
    const token = await signOAuthState("admin");
    const tampered = token.slice(0, -2) + "xx";

    const result = await verifyOAuthState(tampered);

    expect(result).toBeNull();
  });

  it("rejects garbage input", async () => {
    const result = await verifyOAuthState("not-a-real-jwt");
    expect(result).toBeNull();
  });
});

describe("getGoogleAuthUrl", () => {
  it("builds a well-formed Google authorization URL", () => {
    const url = getGoogleAuthUrl("some-state-token", "https://example.com/api/auth/google/callback");
    const parsed = new URL(url);

    expect(parsed.origin + parsed.pathname).toBe("https://accounts.google.com/o/oauth2/v2/auth");
    expect(parsed.searchParams.get("client_id")).toBe("test-client-id.apps.googleusercontent.com");
    expect(parsed.searchParams.get("redirect_uri")).toBe("https://example.com/api/auth/google/callback");
    expect(parsed.searchParams.get("state")).toBe("some-state-token");
    expect(parsed.searchParams.get("scope")).toBe("openid email profile");
    expect(parsed.searchParams.get("response_type")).toBe("code");
  });
});

describe("decodeGoogleIdToken", () => {
  it("decodes a well-formed id_token payload", () => {
    const payload = { sub: "1234567890", email: "rider@example.com", email_verified: true, name: "Test Rider" };
    const fakeIdToken = `${base64UrlEncode({ alg: "RS256" })}.${base64UrlEncode(payload)}.fakesignature`;

    const decoded = decodeGoogleIdToken(fakeIdToken);

    expect(decoded).toEqual(payload);
  });

  it("throws on a malformed token", () => {
    expect(() => decodeGoogleIdToken("not.a.valid.token.with.too.many.parts")).toThrow();
    expect(() => decodeGoogleIdToken("onlyonepart")).toThrow();
  });
});
FILE_EOF

echo "==> Writing src/app/api/auth/google/start/route.ts"
mkdir -p "$(dirname "src/app/api/auth/google/start/route.ts")"
cat > "src/app/api/auth/google/start/route.ts" << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/app/api/auth/google/callback/route.ts"
mkdir -p "$(dirname "src/app/api/auth/google/callback/route.ts")"
cat > "src/app/api/auth/google/callback/route.ts" << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/app/api/auth/google/callback/route.test.ts"
mkdir -p "$(dirname "src/app/api/auth/google/callback/route.test.ts")"
cat > "src/app/api/auth/google/callback/route.test.ts" << 'FILE_EOF'
import { beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const { mockExchangeGoogleCode, mockVerifyOAuthState, mockSignSession, mockSetSessionCookie, mockUnsafe, mockIsWorkerRuntime, mockEnd } =
  vi.hoisted(() => ({
    mockExchangeGoogleCode: vi.fn(),
    mockVerifyOAuthState: vi.fn(),
    mockSignSession: vi.fn(),
    mockSetSessionCookie: vi.fn(),
    mockUnsafe: vi.fn(),
    mockIsWorkerRuntime: vi.fn(),
    mockEnd: vi.fn(),
  }));

vi.mock("@/lib/google-oauth", () => ({
  exchangeGoogleCode: mockExchangeGoogleCode,
  verifyOAuthState: mockVerifyOAuthState,
}));
vi.mock("@/lib/auth", () => ({
  signSession: mockSignSession,
  setSessionCookie: mockSetSessionCookie,
}));
vi.mock("@/lib/db", () => ({
  getSql: () => ({ unsafe: mockUnsafe, end: mockEnd }),
  isWorkerRuntime: mockIsWorkerRuntime,
}));

import { GET } from "./route";

beforeAll(() => {
  process.env.JWT_SECRET = "test-secret";
});

function requestWithParams(params: Record<string, string>): NextRequest {
  const url = new URL("http://localhost/api/auth/google/callback");
  Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value));
  return new NextRequest(url);
}

const GOOGLE_PROFILE = { sub: "google-sub-123", email: "rider@example.com", email_verified: true, name: "Rider One" };

describe("GET /api/auth/google/callback", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
    mockSignSession.mockResolvedValue("fake-jwt-token");
  });

  it("redirects to login with an error when state is missing or invalid", async () => {
    mockVerifyOAuthState.mockResolvedValue(null);

    const response = await GET(requestWithParams({ code: "abc", state: "bad-state" }));

    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toContain("/login?error=");
    expect(mockExchangeGoogleCode).not.toHaveBeenCalled();
  });

  it("redirects to login with an error when code is missing", async () => {
    mockVerifyOAuthState.mockResolvedValue({ scope: "user", nonce: "n" });

    const response = await GET(requestWithParams({ state: "good-state" }));

    expect(response.status).toBe(307);
    expect(mockExchangeGoogleCode).not.toHaveBeenCalled();
  });

  it("auto-provisions a new user_account for an unrecognized user-scope email", async () => {
    mockVerifyOAuthState.mockResolvedValue({ scope: "user", nonce: "n" });
    mockExchangeGoogleCode.mockResolvedValue(GOOGLE_PROFILE);
    mockUnsafe
      .mockResolvedValueOnce([]) // no existing account found
      .mockResolvedValueOnce([{ id: 42, full_name: "Rider One", email: "rider@example.com", role: "user", status: "active" }]); // insert result

    const response = await GET(requestWithParams({ code: "abc", state: "good-state" }));

    expect(mockUnsafe).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining("INSERT INTO user_account"),
      ["Rider One", "rider@example.com", "google-sub-123"]
    );
    expect(mockSignSession).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 42, role: "user", email: "rider@example.com" })
    );
    expect(response.headers.get("location")).toContain("/user/dashboard");
  });

  it("does NOT auto-provision a new admin — rejects unrecognized admin-scope email", async () => {
    mockVerifyOAuthState.mockResolvedValue({ scope: "admin", nonce: "n" });
    mockExchangeGoogleCode.mockResolvedValue(GOOGLE_PROFILE);
    mockUnsafe.mockResolvedValueOnce([]); // no matching admin found

    const response = await GET(requestWithParams({ code: "abc", state: "good-state" }));

    expect(mockUnsafe).toHaveBeenCalledTimes(1); // only the lookup — never an insert
    expect(mockSignSession).not.toHaveBeenCalled();
    expect(response.headers.get("location")).toContain("/admin/login?error=");
  });

  it("links google_id to an existing matching account and signs them in", async () => {
    mockVerifyOAuthState.mockResolvedValue({ scope: "user", nonce: "n" });
    mockExchangeGoogleCode.mockResolvedValue(GOOGLE_PROFILE);
    mockUnsafe
      .mockResolvedValueOnce([{ id: 7, full_name: "Existing Rider", email: "rider@example.com", role: "user", status: "active" }])
      .mockResolvedValueOnce([]); // the UPDATE ... SET google_id

    const response = await GET(requestWithParams({ code: "abc", state: "good-state" }));

    expect(mockUnsafe).toHaveBeenNthCalledWith(2, expect.stringContaining("UPDATE user_account SET google_id"), [
      "google-sub-123",
      7,
    ]);
    expect(mockSignSession).toHaveBeenCalledWith(expect.objectContaining({ userId: 7, role: "user" }));
    expect(response.headers.get("location")).toContain("/user/dashboard");
  });

  it("rejects an inactive account even if the Google email matches", async () => {
    mockVerifyOAuthState.mockResolvedValue({ scope: "user", nonce: "n" });
    mockExchangeGoogleCode.mockResolvedValue(GOOGLE_PROFILE);
    mockUnsafe
      .mockResolvedValueOnce([{ id: 7, full_name: "Existing Rider", email: "rider@example.com", role: "user", status: "inactive" }])
      .mockResolvedValueOnce([]);

    const response = await GET(requestWithParams({ code: "abc", state: "good-state" }));

    expect(mockSignSession).not.toHaveBeenCalled();
    expect(response.headers.get("location")).toContain("/login?error=");
  });

  it("redirects with an error when the Google code exchange fails", async () => {
    mockVerifyOAuthState.mockResolvedValue({ scope: "user", nonce: "n" });
    mockExchangeGoogleCode.mockRejectedValue(new Error("invalid_grant"));

    const response = await GET(requestWithParams({ code: "bad-code", state: "good-state" }));

    expect(mockUnsafe).not.toHaveBeenCalled();
    expect(response.headers.get("location")).toContain("/login?error=");
  });
});
FILE_EOF

echo "==> Writing src/components/auth-login-form.tsx"
mkdir -p "$(dirname "src/components/auth-login-form.tsx")"
cat > "src/components/auth-login-form.tsx" << 'FILE_EOF'
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

type Props = {
  scope: "admin" | "user";
  title: string;
};

export default function AuthLoginForm({ scope, title }: Props) {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const oauthError = params.get("error");
    if (oauthError) {
      // Reading the error the Google OAuth callback redirected back with —
      // an external system (the URL), read once after mount.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setError(oauthError);
    }
  }, []);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setLoading(true);

    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, password, scope }),
      });

      const data = (await response.json()) as { error?: string; redirectTo?: string };
      if (!response.ok) {
        setError(data.error ?? "Login failed");
        return;
      }

      router.push(data.redirectTo ?? "/");
      router.refresh();
    } catch {
      setError("Unexpected network error. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="card">
      <h1>{title}</h1>
      <p className="muted">Sign in with your existing account credentials.</p>

      <label>
        Email
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          placeholder="name@example.com"
        />
      </label>

      <label>
        Password
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          placeholder="Enter your password"
        />
      </label>

      {error ? <p className="error">{error}</p> : null}

      <button type="submit" disabled={loading}>
        {loading ? "Signing in..." : "Sign in"}
      </button>

      <div className="auth-divider">
        <span>or</span>
      </div>

      <a href={`/api/auth/google/start?scope=${scope}`} className="oauth-button">
        <span className="oauth-google-mark">G</span>
        Continue with Google
      </a>
    </form>
  );
}
FILE_EOF

echo "==> Writing src/app/globals.css"
mkdir -p "$(dirname "src/app/globals.css")"
cat > "src/app/globals.css" << 'FILE_EOF'
@import "tailwindcss";

:root {
  --bg-deep: #060b16;
  --bg-deep-2: #0a1428;
  --panel: #101c34;
  --panel-alt: #14213e;
  --glow: #2fb6ff;
  --accent: #2e6bff;
  --accent-2: #6a4bff;
  --amber: #ffab3e;
  --danger: #ff5470;
  --success: #33dd93;
  --ink: #f2f6ff;
  --ink-muted: #8ea0c7;
  --hairline: rgba(255, 255, 255, 0.08);
  --hairline-strong: rgba(255, 255, 255, 0.14);
}

[data-theme="light"] {
  --bg-deep: #f5f7fb;
  --bg-deep-2: #eef1f8;
  --panel: #ffffff;
  --panel-alt: #eef2fa;
  --glow: #1d8fe0;
  --accent: #2e6bff;
  --accent-2: #6a4bff;
  --amber: #b5710f;
  --danger: #d1284a;
  --success: #14966a;
  --ink: #101828;
  --ink-muted: #5b6b8c;
  --hairline: rgba(16, 24, 40, 0.08);
  --hairline-strong: rgba(16, 24, 40, 0.14);
}

[data-theme="light"] body {
  background:
    radial-gradient(1200px 600px at 15% -10%, rgba(46, 107, 255, 0.12), transparent 60%),
    radial-gradient(900px 500px at 100% 0%, rgba(106, 75, 255, 0.1), transparent 55%),
    var(--bg-deep);
}

[data-theme="light"] .hero h1,
[data-theme="light"] .stat-card p {
  background: linear-gradient(135deg, #101828, #1d63e0 70%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

[data-theme="light"] input,
[data-theme="light"] textarea,
[data-theme="light"] select,
[data-theme="light"] th {
  background: rgba(16, 24, 40, 0.03);
}

[data-theme="light"] .hero,
[data-theme="light"] .card,
[data-theme="light"] .card-lite,
[data-theme="light"] .stat-card,
[data-theme="light"] .table-wrap,
[data-theme="light"] .ride-form,
[data-theme="light"] .quick-action {
  box-shadow: 0 12px 34px rgba(16, 24, 40, 0.08);
}

@theme inline {
  --color-background: var(--bg-deep);
  --color-foreground: var(--ink);
  --font-sans: var(--font-plex-sans);
  --font-display: var(--font-sora);
  --font-mono: var(--font-plex-mono);
}

* {
  box-sizing: border-box;
}

body {
  background:
    radial-gradient(1200px 600px at 15% -10%, rgba(46, 107, 255, 0.25), transparent 60%),
    radial-gradient(900px 500px at 100% 0%, rgba(106, 75, 255, 0.18), transparent 55%),
    var(--bg-deep);
  color: var(--ink);
  font-family: var(--font-plex-sans), sans-serif;
  font-size: 15px;
  line-height: 1.55;
}

a {
  color: var(--glow);
}

h1,
h2,
h3 {
  font-family: var(--font-sora), sans-serif;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--ink);
}

/* ---------- Landing: glowing hero ---------- */

.landing {
  min-height: 100vh;
  display: grid;
  place-content: center;
  padding: 2rem;
  position: relative;
  overflow: hidden;
}

.hero {
  position: relative;
  max-width: 720px;
  background: linear-gradient(180deg, var(--panel-alt), var(--panel));
  border: 1px solid var(--hairline-strong);
  border-radius: 28px;
  padding: 3rem 2.5rem;
  box-shadow: 0 40px 90px rgba(0, 0, 0, 0.55), 0 0 0 1px rgba(255, 255, 255, 0.02) inset;
  overflow: hidden;
}

.hero::after {
  content: "";
  position: absolute;
  top: -140px;
  right: -140px;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(47, 182, 255, 0.55), rgba(47, 182, 255, 0) 70%);
  pointer-events: none;
}

.hero::before {
  content: "SYSTEM ONLINE";
  position: relative;
  z-index: 1;
  display: inline-block;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.68rem;
  font-weight: 600;
  letter-spacing: 0.18em;
  color: var(--glow);
  background: rgba(47, 182, 255, 0.12);
  border: 1px solid rgba(47, 182, 255, 0.35);
  border-radius: 999px;
  padding: 0.3rem 0.8rem;
  margin-bottom: 1.5rem;
}

.hero h1 {
  position: relative;
  z-index: 1;
  font-size: clamp(2rem, 5.5vw, 3.1rem);
  line-height: 1.08;
  margin: 0;
  background: linear-gradient(135deg, #ffffff, #b9ccff 70%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.muted {
  color: var(--ink-muted);
}

.hero .muted {
  position: relative;
  z-index: 1;
  margin-top: 0.9rem;
  max-width: 46ch;
}

.hero-actions {
  position: relative;
  z-index: 1;
  margin-top: 2rem;
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.hero-actions a {
  display: inline-block;
  padding: 0.75rem 1.3rem;
  border-radius: 999px;
  text-decoration: none;
  font-weight: 600;
  font-size: 0.9rem;
  border: 1px solid var(--hairline-strong);
  color: var(--ink);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.hero-actions a:first-child {
  background: linear-gradient(135deg, var(--accent), var(--glow));
  border: none;
  color: #071224;
  box-shadow: 0 8px 30px rgba(47, 182, 255, 0.45);
}

.hero-actions a:hover {
  transform: translateY(-2px);
}

/* ---------- Auth ---------- */

.auth-wrap {
  min-height: 100vh;
  display: grid;
  place-content: center;
  padding: 1.5rem;
}

.card,
.card-lite {
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 20px;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.35);
}

.card {
  width: min(440px, 92vw);
  padding: 2rem;
  display: grid;
  gap: 1rem;
}

.card h1 {
  font-size: 1.5rem;
}

.card label {
  display: grid;
  gap: 0.35rem;
  font-size: 0.85rem;
  font-weight: 500;
  color: var(--ink-muted);
}

input,
textarea,
button,
select {
  font: inherit;
}

input,
textarea,
select {
  border: 1px solid var(--hairline-strong);
  border-radius: 12px;
  padding: 0.7rem 0.85rem;
  background: rgba(255, 255, 255, 0.03);
  color: var(--ink);
  font-family: var(--font-plex-sans), sans-serif;
}

input::placeholder,
textarea::placeholder {
  color: rgba(142, 160, 199, 0.6);
}

input:focus-visible,
textarea:focus-visible,
select:focus-visible,
button:focus-visible,
a:focus-visible {
  outline: 2px solid var(--glow);
  outline-offset: 2px;
}

button {
  border: 0;
  border-radius: 999px;
  padding: 0.8rem 1.2rem;
  background: linear-gradient(135deg, var(--accent), var(--glow));
  color: #071224;
  font-weight: 700;
  font-size: 0.88rem;
  cursor: pointer;
  box-shadow: 0 10px 26px rgba(47, 182, 255, 0.35);
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}

button:hover {
  transform: translateY(-1px);
  box-shadow: 0 14px 32px rgba(47, 182, 255, 0.45);
}

button:disabled {
  opacity: 0.55;
  cursor: default;
  box-shadow: none;
}

.error {
  color: var(--danger);
  font-size: 0.9rem;
  font-weight: 500;
}

.auth-link {
  text-align: center;
  font-size: 0.9rem;
  color: var(--ink-muted);
}

.auth-divider {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  color: var(--ink-muted);
  font-size: 0.78rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin: 0.2rem 0;
}

.auth-divider::before,
.auth-divider::after {
  content: "";
  flex: 1;
  height: 1px;
  background: var(--hairline);
}

.oauth-button {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.6rem;
  padding: 0.75rem 1rem;
  border-radius: 999px;
  background: var(--surface, var(--panel));
  border: 1px solid var(--hairline-strong);
  color: var(--ink);
  text-decoration: none;
  font-weight: 600;
  font-size: 0.88rem;
  box-shadow: none;
  transition: transform 0.12s ease, background 0.12s ease;
}

.oauth-button:hover {
  transform: translateY(-1px);
  background: rgba(255, 255, 255, 0.05);
}

.oauth-google-mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: linear-gradient(135deg, #4285f4, #34a853 35%, #fbbc05 65%, #ea4335);
  color: #fff;
  font-family: var(--font-sora, sans-serif);
  font-weight: 700;
  font-size: 0.72rem;
  flex: 0 0 auto;
}

/* ---------- App shell / console ---------- */

.shell {
  min-height: 100vh;
  display: grid;
  grid-template-columns: 250px 1fr;
  transition: grid-template-columns 0.2s ease;
}

.shell.shell-collapsed {
  grid-template-columns: 84px 1fr;
}

.sidebar {
  background: linear-gradient(180deg, var(--panel-alt), var(--bg-deep-2));
  color: var(--ink);
  padding: 1.5rem 1.1rem;
  display: flex;
  flex-direction: column;
  gap: 1.2rem;
  border-right: 1px solid var(--hairline);
}

.sidebar h2 {
  margin: 0;
  font-size: 1.15rem;
}

.sidebar .muted {
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.68rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--glow);
  margin-top: -0.7rem;
}

.sidebar nav {
  display: grid;
  gap: 0.3rem;
  margin-top: 0.5rem;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.65rem 0.85rem;
  border-radius: 14px;
  color: var(--ink-muted);
  text-decoration: none;
  font-size: 0.92rem;
  font-weight: 500;
  transition: background 0.15s ease, color 0.15s ease;
}

.nav-link:hover {
  background: rgba(47, 182, 255, 0.1);
  color: var(--ink);
}

.nav-link.active {
  background: linear-gradient(135deg, rgba(46, 107, 255, 0.35), rgba(47, 182, 255, 0.25));
  color: #fff;
  box-shadow: 0 0 0 1px rgba(47, 182, 255, 0.4) inset;
}

.logout {
  margin-top: auto;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  background: transparent;
  border: 1px solid rgba(255, 84, 112, 0.5);
  color: #ff93a8;
  box-shadow: none;
}

.logout:hover {
  background: rgba(255, 84, 112, 0.12);
  transform: none;
  box-shadow: none;
}

.content {
  padding: 1.75rem 2rem;
}

.content > header {
  margin-bottom: 1.5rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid var(--hairline);
}

.content h1 {
  font-size: 1.6rem;
  margin: 0;
}

/* ---------- Stat cards: glowing ring signature ---------- */

.stat-grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
}

.stat-card {
  position: relative;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 18px;
  padding: 1.25rem 1.1rem;
  overflow: hidden;
}

.stat-card::before {
  content: "";
  position: absolute;
  top: -30px;
  right: -30px;
  width: 90px;
  height: 90px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(47, 182, 255, 0.4), rgba(47, 182, 255, 0) 70%);
}

.stat-card p {
  font-family: var(--font-plex-mono), monospace;
  font-size: 1.85rem;
  font-weight: 600;
  margin: 0.4rem 0 0;
  background: linear-gradient(135deg, #fff, var(--glow));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}

.stat-card span,
.stat-card label {
  font-size: 0.72rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink-muted);
}

/* ---------- Ride booking ---------- */

.ride-booking {
  max-width: 720px;
  display: grid;
  gap: 1rem;
}

.ride-booking-copy {
  padding: 1rem 0 0;
}

.ride-booking-copy h2 {
  margin: 0.2rem 0;
  font-size: 1.35rem;
}

.ride-kicker {
  margin: 0;
  color: var(--glow);
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.ride-route {
  display: flex;
  align-items: center;
  width: min(100%, 420px);
  padding-top: 0.75rem;
}

.ride-stop {
  width: 14px;
  height: 14px;
  flex: 0 0 auto;
  border: 3px solid var(--bg-deep);
  border-radius: 50%;
  box-shadow: 0 0 0 2px var(--glow), 0 0 14px rgba(47, 182, 255, 0.6);
}

.ride-stop--end {
  border-radius: 4px;
  box-shadow: 0 0 0 2px var(--amber), 0 0 14px rgba(255, 171, 62, 0.55);
}

.ride-route-line {
  height: 3px;
  width: 100%;
  background: repeating-linear-gradient(90deg, var(--glow) 0 10px, transparent 10px 16px);
  opacity: 0.6;
}

.ride-form {
  display: grid;
  gap: 0.9rem;
  padding: 1.5rem;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 20px;
}

.ride-form label {
  display: grid;
  gap: 0.35rem;
  font-size: 0.85rem;
  color: var(--ink-muted);
}

.ride-location {
  justify-self: start;
  padding: 0.6rem 0.9rem;
  color: var(--glow);
  background: rgba(47, 182, 255, 0.08);
  border: 1px solid rgba(47, 182, 255, 0.35);
  box-shadow: none;
}

.ride-location:hover {
  background: rgba(47, 182, 255, 0.18);
  transform: none;
  box-shadow: none;
}

.ride-estimate {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.9rem 1rem;
  color: var(--ink);
  background: rgba(46, 107, 255, 0.1);
  border: 1px solid rgba(46, 107, 255, 0.3);
  border-radius: 14px;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.9rem;
}

.ride-estimate strong {
  text-align: right;
  font-size: 0.9rem;
  color: var(--glow);
}

.ride-message {
  margin: 0;
  padding: 0.9rem 1rem;
  color: var(--ink);
  background: rgba(255, 171, 62, 0.1);
  border: 1px solid rgba(255, 171, 62, 0.35);
  border-radius: 14px;
  font-size: 0.9rem;
}

/* ---------- Status badges ---------- */

.badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.25rem 0.65rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}

.badge-pending {
  color: var(--amber);
  background: rgba(255, 171, 62, 0.14);
  border: 1px solid rgba(255, 171, 62, 0.35);
}

.badge-assigned {
  color: var(--glow);
  background: rgba(47, 182, 255, 0.14);
  border: 1px solid rgba(47, 182, 255, 0.35);
}

.badge-completed {
  color: var(--success);
  background: rgba(51, 221, 147, 0.14);
  border: 1px solid rgba(51, 221, 147, 0.35);
}

.badge-cancelled {
  color: var(--danger);
  background: rgba(255, 84, 112, 0.14);
  border: 1px solid rgba(255, 84, 112, 0.35);
}

/* ---------- Data / tables ---------- */

.inline-form {
  display: flex;
  gap: 0.6rem;
  margin: 1rem 0;
}

.table-wrap {
  overflow-x: auto;
  margin-top: 1rem;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 18px;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.92rem;
}

th {
  text-align: left;
  padding: 0.75rem 0.9rem;
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.7rem;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: var(--ink-muted);
  background: rgba(255, 255, 255, 0.02);
  border-bottom: 1px solid var(--hairline);
}

td {
  text-align: left;
  padding: 0.75rem 0.9rem;
  border-bottom: 1px solid var(--hairline);
  font-family: var(--font-plex-mono), monospace;
  font-size: 0.88rem;
  color: var(--ink);
}

tr:last-child td {
  border-bottom: none;
}

tr:hover td {
  background: rgba(255, 255, 255, 0.02);
}

.two-col {
  margin-top: 1rem;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}

.card-lite {
  padding: 1.1rem;
  border-left: 3px solid var(--accent);
}

.stack-list {
  margin-top: 1rem;
  display: grid;
  gap: 0.8rem;
}

@media (max-width: 960px) {
  .shell,
  .shell.shell-collapsed {
    grid-template-columns: 1fr;
  }

  .sidebar {
    position: fixed;
    top: 0;
    bottom: 0;
    left: 0;
    width: 260px;
    max-width: 82vw;
    border-right: none;
    border-bottom: none;
    transform: translateX(-100%);
    transition: transform 0.25s ease;
    z-index: 60;
    box-shadow: 0 0 50px rgba(0, 0, 0, 0.5);
  }

  .sidebar.mobile-open {
    transform: translateX(0);
  }

  /* On mobile the drawer always shows full labels, even if the desktop
     "collapsed" preference is on — collapsing only makes sense for the
     persistent desktop column, not a full-width slide-in drawer. */
  .sidebar.collapsed {
    padding: 1.5rem 1.1rem;
  }

  .sidebar.collapsed h2,
  .sidebar.collapsed .muted,
  .sidebar.collapsed .nav-label,
  .sidebar.collapsed .logout-label {
    display: block;
  }

  .sidebar.collapsed .nav-link {
    justify-content: flex-start;
    padding: 0.65rem 0.85rem;
  }

  .sidebar-toggle {
    display: none;
  }

  .sidebar-close {
    display: inline-flex;
  }

  .sidebar-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 55;
  }

  .mobile-topbar-toggle {
    display: inline-flex;
  }

  .content {
    padding: 1.25rem 1rem;
  }
}

@media (max-width: 640px) {
  .content {
    padding: 1rem 0.85rem;
  }

  .content h1 {
    font-size: 1.3rem;
  }

  .hero {
    padding: 2rem 1.4rem;
  }

  .stat-grid,
  .quick-actions {
    grid-template-columns: 1fr;
  }

  .two-col {
    grid-template-columns: 1fr;
  }

  .donut-wrap {
    width: 120px;
    height: 120px;
  }

  table,
  th,
  td {
    font-size: 0.8rem;
  }

  th,
  td {
    padding: 0.55rem 0.6rem;
  }

  .ride-form,
  .card {
    padding: 1.1rem;
  }

  .theme-toggle {
    top: 0.6rem;
    right: 0.6rem;
    padding: 0.4rem 0.7rem;
    font-size: 0.72rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  * {
    transition: none !important;
  }
}

/* ---------- Theme toggle ---------- */

.theme-toggle {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 50;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.5rem 0.9rem;
  border-radius: 999px;
  background: var(--panel);
  border: 1px solid var(--hairline-strong);
  color: var(--ink);
  font-size: 0.78rem;
  font-weight: 600;
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.25);
}

.theme-toggle:hover {
  transform: translateY(-1px);
  box-shadow: 0 10px 24px rgba(0, 0, 0, 0.3);
}

/* ---------- Collapsible sidebar ---------- */

.sidebar-toggle {
  align-self: flex-end;
  background: transparent;
  border: 1px solid var(--hairline-strong);
  color: var(--ink-muted);
  padding: 0.35rem;
  border-radius: 8px;
  box-shadow: none;
  width: auto;
}

.sidebar-toggle:hover {
  color: var(--ink);
  background: rgba(255, 255, 255, 0.05);
  transform: none;
  box-shadow: none;
}

.sidebar-close {
  display: none;
  align-self: flex-end;
  background: transparent;
  border: 1px solid var(--hairline-strong);
  color: var(--ink-muted);
  padding: 0.35rem;
  border-radius: 8px;
  box-shadow: none;
  width: auto;
}

.sidebar-close:hover {
  color: var(--ink);
  background: rgba(255, 255, 255, 0.05);
  transform: none;
  box-shadow: none;
}

.mobile-topbar-toggle {
  display: none;
  align-items: center;
  gap: 0.5rem;
  background: var(--panel);
  border: 1px solid var(--hairline-strong);
  color: var(--ink);
  padding: 0.55rem 0.9rem;
  border-radius: 10px;
  margin-bottom: 1.1rem;
  box-shadow: none;
  width: auto;
  font-size: 0.85rem;
}

.mobile-topbar-toggle:hover {
  transform: none;
  box-shadow: none;
  background: rgba(255, 255, 255, 0.06);
}

.sidebar.collapsed {
  padding: 1.5rem 0.6rem;
}

.sidebar.collapsed h2,
.sidebar.collapsed .muted,
.sidebar.collapsed .nav-label,
.sidebar.collapsed .logout-label {
  display: none;
}

.sidebar.collapsed .nav-link {
  justify-content: center;
  padding: 0.65rem;
}

.sidebar.collapsed .logout {
  display: flex;
  justify-content: center;
  padding: 0.65rem;
}

/* ---------- Dashboard: donut, legend, power bar, quick actions ---------- */

.donut-wrap {
  position: relative;
  width: 150px;
  height: 150px;
  flex: 0 0 auto;
}

.donut {
  width: 100%;
  height: 100%;
  border-radius: 50%;
}

.donut-hole {
  position: absolute;
  inset: 20px;
  border-radius: 50%;
  background: var(--panel);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
}

.donut-hole strong {
  font-family: var(--font-plex-mono), monospace;
  font-size: 1.5rem;
  color: var(--ink);
}

.donut-hole span {
  font-size: 0.65rem;
  color: var(--ink-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.55rem;
  font-size: 0.88rem;
  color: var(--ink);
}

.legend li {
  display: flex;
  align-items: center;
  gap: 0.55rem;
}

.legend .dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex: 0 0 auto;
}

.power-bar {
  display: flex;
  height: 14px;
  border-radius: 999px;
  overflow: hidden;
  background: var(--hairline);
}

.power-bar-electric {
  background: linear-gradient(135deg, var(--success), #22c55e);
}

.power-bar-fuel {
  background: linear-gradient(135deg, var(--ink-muted), #64748b);
}

.quick-actions {
  margin-top: 0.75rem;
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
}

.quick-action {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  padding: 1.1rem;
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 16px;
  text-decoration: none;
  color: var(--ink);
  transition: transform 0.15s ease, border-color 0.15s ease;
}

.quick-action:hover {
  transform: translateY(-2px);
  border-color: var(--accent);
}

.quick-action-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 42px;
  height: 42px;
  border-radius: 12px;
  flex: 0 0 auto;
  background: linear-gradient(135deg, rgba(46, 107, 255, 0.18), rgba(47, 182, 255, 0.18));
  color: var(--glow);
}
FILE_EOF

echo ""
echo "============================================================"
echo "Code written. THREE more things needed before this works:"
echo "============================================================"
echo ""
echo "1) Run this in your Supabase SQL editor:"
echo ""
echo "   ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) UNIQUE;"
echo "   ALTER TABLE users ALTER COLUMN password DROP NOT NULL;"
echo "   ALTER TABLE user_account ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) UNIQUE;"
echo "   ALTER TABLE user_account ALTER COLUMN password DROP NOT NULL;"
echo ""
echo "2) Create a Google OAuth Client ID (console.cloud.google.com ->"
echo "   APIs & Services -> Credentials -> Create Credentials -> OAuth client ID"
echo "   -> Web application). Add these Authorized redirect URIs:"
echo "     https://testing-3.lembaracaleb.workers.dev/api/auth/google/callback"
echo "     http://localhost:3000/api/auth/google/callback"
echo ""
echo "3) Set the two secrets on your Worker, and in .dev.vars for local testing:"
echo "   npx wrangler secret put GOOGLE_CLIENT_ID"
echo "   npx wrangler secret put GOOGLE_CLIENT_SECRET"
echo "   (then add GOOGLE_CLIENT_ID=... and GOOGLE_CLIENT_SECRET=... lines to .dev.vars too)"
echo ""
echo "Run tests: npm run test"
echo "Then deploy: bash deploy.sh"
