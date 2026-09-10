import { beforeEach, describe, expect, it, vi } from "vitest";

const { mockQuery, mockSetSessionCookie, mockSignSession, mockVerifyPassword } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockSetSessionCookie: vi.fn(),
  mockSignSession: vi.fn(),
  mockVerifyPassword: vi.fn(),
}));

vi.mock("@/lib/db", () => ({ query: mockQuery }));
vi.mock("@/lib/auth", () => ({
  setSessionCookie: mockSetSessionCookie,
  signSession: mockSignSession,
  verifyPassword: mockVerifyPassword,
}));

import { POST } from "./route";

function loginRequest(payload: unknown): Request {
  return new Request("http://localhost/api/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
}

describe("POST /api/auth/login", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("rejects invalid payloads before querying the database", async () => {
    const response = await POST(loginRequest({ email: "invalid" }));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "Invalid request payload." });
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it("creates an admin session after valid credentials", async () => {
    mockQuery.mockResolvedValue({
      rows: [{ id: 1, full_name: "System Administrator", email: "admin@example.com", password: "hash", role: "admin", status: "active" }],
    });
    mockVerifyPassword.mockResolvedValue(true);
    mockSignSession.mockResolvedValue("signed-session");

    const response = await POST(loginRequest({ email: "admin@example.com", password: "secret", scope: "admin" }));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true, redirectTo: "/admin/dashboard" });
    expect(mockQuery).toHaveBeenCalledWith(expect.stringContaining("FROM users"), ["admin@example.com"]);
    expect(mockSetSessionCookie).toHaveBeenCalledWith(response, "signed-session");
  });
});