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
