import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const { mockGetSessionFromRequest, mockGetAdminMotorists, mockUnsafe, mockIsWorkerRuntime, mockEnd } = vi.hoisted(() => ({
  mockGetSessionFromRequest: vi.fn(),
  mockGetAdminMotorists: vi.fn(),
  mockUnsafe: vi.fn(),
  mockIsWorkerRuntime: vi.fn(),
  mockEnd: vi.fn(),
}));

vi.mock("@/lib/auth", () => ({ getSessionFromRequest: mockGetSessionFromRequest }));
vi.mock("@/lib/server-data", () => ({ getAdminMotorists: mockGetAdminMotorists }));
vi.mock("@/lib/db", () => ({
  getSql: () => ({ unsafe: mockUnsafe, end: mockEnd }),
  isWorkerRuntime: mockIsWorkerRuntime,
}));

import { GET, POST } from "./route";

function jsonRequest(url: string, method: string, body?: unknown): NextRequest {
  return new NextRequest(url, {
    method,
    headers: { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

const ADMIN_SESSION = { userId: 1, role: "admin" as const, email: "admin@example.com", name: "Admin" };
const validMotorist = {
  fullName: "Amina Kamau",
  licenseNumber: "DL999999",
  phoneNumber: "0712345678",
  email: "amina@example.com",
  address: "123 Main St",
};

describe("GET /api/admin/motorists", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
  });

  it("rejects unauthenticated requests", async () => {
    mockGetSessionFromRequest.mockResolvedValue(null);

    const response = await GET(jsonRequest("http://localhost/api/admin/motorists", "GET"));

    expect(response.status).toBe(401);
    expect(mockGetAdminMotorists).not.toHaveBeenCalled();
  });

  it("rejects a non-admin session", async () => {
    mockGetSessionFromRequest.mockResolvedValue({ ...ADMIN_SESSION, role: "user" });

    const response = await GET(jsonRequest("http://localhost/api/admin/motorists", "GET"));

    expect(response.status).toBe(401);
  });

  it("returns motorists for an admin session", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockGetAdminMotorists.mockResolvedValue([{ id: 1, full_name: "John Doe" }]);

    const response = await GET(jsonRequest("http://localhost/api/admin/motorists?search=john", "GET"));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual([{ id: 1, full_name: "John Doe" }]);
    expect(mockGetAdminMotorists).toHaveBeenCalledWith("john");
  });
});

describe("POST /api/admin/motorists", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
  });

  it("rejects unauthenticated requests before touching the database", async () => {
    mockGetSessionFromRequest.mockResolvedValue(null);

    const response = await POST(jsonRequest("http://localhost/api/admin/motorists", "POST", validMotorist));

    expect(response.status).toBe(401);
    expect(mockUnsafe).not.toHaveBeenCalled();
  });

  it("rejects an invalid payload before touching the database", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);

    const response = await POST(
      jsonRequest("http://localhost/api/admin/motorists", "POST", { ...validMotorist, licenseNumber: "" })
    );

    expect(response.status).toBe(400);
    expect(mockUnsafe).not.toHaveBeenCalled();
  });

  it("inserts a valid motorist and returns ok", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockUnsafe.mockResolvedValue([]);

    const response = await POST(jsonRequest("http://localhost/api/admin/motorists", "POST", validMotorist));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true });
    expect(mockUnsafe).toHaveBeenCalledWith(
      expect.stringContaining("INSERT INTO motorists"),
      ["Amina Kamau", "DL999999", "0712345678", "amina@example.com", "123 Main St"]
    );
  });

  it("returns a 500 with a friendly message when the insert fails", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockUnsafe.mockRejectedValue(new Error("duplicate key value"));

    const response = await POST(jsonRequest("http://localhost/api/admin/motorists", "POST", validMotorist));

    expect(response.status).toBe(500);
    await expect(response.json()).resolves.toEqual({ error: "Failed to add motorist." });
  });
});
