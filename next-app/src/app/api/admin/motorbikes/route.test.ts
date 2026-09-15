import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const { mockGetSessionFromRequest, mockGetAdminMotorbikes, mockTxUnsafe, mockIsWorkerRuntime, mockEnd } = vi.hoisted(() => ({
  mockGetSessionFromRequest: vi.fn(),
  mockGetAdminMotorbikes: vi.fn(),
  mockTxUnsafe: vi.fn(),
  mockIsWorkerRuntime: vi.fn(),
  mockEnd: vi.fn(),
}));

vi.mock("@/lib/auth", () => ({ getSessionFromRequest: mockGetSessionFromRequest }));
vi.mock("@/lib/server-data", () => ({ getAdminMotorbikes: mockGetAdminMotorbikes }));
vi.mock("@/lib/db", () => ({
  getSql: () => ({
    begin: async (callback: (tx: { unsafe: typeof mockTxUnsafe }) => Promise<void>) =>
      callback({ unsafe: mockTxUnsafe }),
    end: mockEnd,
  }),
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
const commercialBike = {
  motoristId: 1,
  registrationNumber: "KBA 123A",
  brand: "Honda",
  model: "CBR 150",
  purpose: "commercial",
  powerType: "electric",
};
const hireBike = {
  ...commercialBike,
  purpose: "hire",
  ownerName: "Mike Wilson",
  ownerPhone: "0745678901",
  hireRate: 1500,
};

describe("GET /api/admin/motorbikes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
  });

  it("rejects unauthenticated requests", async () => {
    mockGetSessionFromRequest.mockResolvedValue(null);

    const response = await GET(jsonRequest("http://localhost/api/admin/motorbikes", "GET"));

    expect(response.status).toBe(401);
  });

  it("returns motorbikes for an admin session", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockGetAdminMotorbikes.mockResolvedValue([{ id: 1, registration_number: "KBA 123A" }]);

    const response = await GET(jsonRequest("http://localhost/api/admin/motorbikes", "GET"));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual([{ id: 1, registration_number: "KBA 123A" }]);
  });
});

describe("POST /api/admin/motorbikes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
  });

  it("rejects unauthenticated requests before touching the database", async () => {
    mockGetSessionFromRequest.mockResolvedValue(null);

    const response = await POST(jsonRequest("http://localhost/api/admin/motorbikes", "POST", commercialBike));

    expect(response.status).toBe(401);
    expect(mockTxUnsafe).not.toHaveBeenCalled();
  });

  it("rejects an on-hire bike missing owner/hire fields", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);

    const response = await POST(
      jsonRequest("http://localhost/api/admin/motorbikes", "POST", { ...commercialBike, purpose: "hire" })
    );

    expect(response.status).toBe(400);
    expect(mockTxUnsafe).not.toHaveBeenCalled();
  });

  it("inserts a commercial bike without touching hire_details", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockTxUnsafe.mockResolvedValue([{ id: 5 }]);

    const response = await POST(jsonRequest("http://localhost/api/admin/motorbikes", "POST", commercialBike));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true });
    expect(mockTxUnsafe).toHaveBeenCalledTimes(1);
    expect(mockTxUnsafe).toHaveBeenCalledWith(expect.stringContaining("INSERT INTO motorbikes"), expect.any(Array));
  });

  it("inserts an on-hire bike and its hire_details row", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockTxUnsafe.mockResolvedValueOnce([{ id: 7 }]).mockResolvedValueOnce([]);

    const response = await POST(jsonRequest("http://localhost/api/admin/motorbikes", "POST", hireBike));

    expect(response.status).toBe(200);
    expect(mockTxUnsafe).toHaveBeenCalledTimes(2);
    expect(mockTxUnsafe).toHaveBeenNthCalledWith(2, expect.stringContaining("INSERT INTO hire_details"), [
      7,
      "Mike Wilson",
      "0745678901",
      null,
      null,
      1500,
      null,
      null,
    ]);
  });

  it("returns a 500 with a friendly message when the insert fails", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockTxUnsafe.mockRejectedValue(new Error("duplicate key value"));

    const response = await POST(jsonRequest("http://localhost/api/admin/motorbikes", "POST", commercialBike));

    expect(response.status).toBe(500);
  });
});
