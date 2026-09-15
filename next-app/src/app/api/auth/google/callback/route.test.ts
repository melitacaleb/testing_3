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
