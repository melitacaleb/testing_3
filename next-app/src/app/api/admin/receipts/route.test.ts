import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const { mockGetSessionFromRequest, mockGetAdminReceipts, mockUnsafe, mockIsWorkerRuntime, mockEnd } = vi.hoisted(() => ({
  mockGetSessionFromRequest: vi.fn(),
  mockGetAdminReceipts: vi.fn(),
  mockUnsafe: vi.fn(),
  mockIsWorkerRuntime: vi.fn(),
  mockEnd: vi.fn(),
}));

vi.mock("@/lib/auth", () => ({ getSessionFromRequest: mockGetSessionFromRequest }));
vi.mock("@/lib/server-data", () => ({ getAdminReceipts: mockGetAdminReceipts }));
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

const ADMIN_SESSION = { userId: 1, role: "admin" as const, email: "admin@example.com", name: "System Admin" };
const validReceipt = { userId: 3, title: "Registration fee", amount: 1500, description: "Annual fee" };

describe("GET /api/admin/receipts", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
  });

  it("rejects unauthenticated requests", async () => {
    mockGetSessionFromRequest.mockResolvedValue(null);

    const response = await GET(jsonRequest("http://localhost/api/admin/receipts", "GET"));

    expect(response.status).toBe(401);
  });

  it("returns receipts for an admin session", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockGetAdminReceipts.mockResolvedValue([{ id: 1, title: "Registration fee" }]);

    const response = await GET(jsonRequest("http://localhost/api/admin/receipts", "GET"));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual([{ id: 1, title: "Registration fee" }]);
  });
});

describe("POST /api/admin/receipts", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
  });

  it("rejects unauthenticated requests before touching the database", async () => {
    mockGetSessionFromRequest.mockResolvedValue(null);

    const response = await POST(jsonRequest("http://localhost/api/admin/receipts", "POST", validReceipt));

    expect(response.status).toBe(401);
    expect(mockUnsafe).not.toHaveBeenCalled();
  });

  it("rejects a negative amount before touching the database", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);

    const response = await POST(
      jsonRequest("http://localhost/api/admin/receipts", "POST", { ...validReceipt, amount: -1 })
    );

    expect(response.status).toBe(400);
    expect(mockUnsafe).not.toHaveBeenCalled();
  });

  it("inserts a valid receipt tagged with the issuing admin's name", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockUnsafe.mockResolvedValue([]);

    const response = await POST(jsonRequest("http://localhost/api/admin/receipts", "POST", validReceipt));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true });
    expect(mockUnsafe).toHaveBeenCalledWith(
      expect.stringContaining("INSERT INTO receipts"),
      [3, "Registration fee", 1500, "Annual fee", "System Admin"]
    );
  });

  it("returns a 500 with a friendly message when the insert fails", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockUnsafe.mockRejectedValue(new Error("connection reset"));

    const response = await POST(jsonRequest("http://localhost/api/admin/receipts", "POST", validReceipt));

    expect(response.status).toBe(500);
  });
});
