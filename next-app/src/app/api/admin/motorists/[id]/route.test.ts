import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const { mockGetSessionFromRequest, mockUnsafe, mockIsWorkerRuntime, mockEnd } = vi.hoisted(() => ({
  mockGetSessionFromRequest: vi.fn(),
  mockUnsafe: vi.fn(),
  mockIsWorkerRuntime: vi.fn(),
  mockEnd: vi.fn(),
}));

vi.mock("@/lib/auth", () => ({ getSessionFromRequest: mockGetSessionFromRequest }));
vi.mock("@/lib/db", () => ({
  getSql: () => ({ unsafe: mockUnsafe, end: mockEnd }),
  isWorkerRuntime: mockIsWorkerRuntime,
}));

import { PATCH, DELETE } from "./route";

function jsonRequest(url: string, method: string, body?: unknown): NextRequest {
  return new NextRequest(url, {
    method,
    headers: { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

function withParams(id: string) {
  return { params: Promise.resolve({ id }) };
}

const ADMIN_SESSION = { userId: 1, role: "admin" as const, email: "admin@example.com", name: "Admin" };
const validUpdate = {
  fullName: "Amina Kamau",
  licenseNumber: "DL999999",
  phoneNumber: "0712345678",
  email: "amina@example.com",
  address: "123 Main St",
};

describe("PATCH /api/admin/motorists/[id]", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
  });

  it("rejects unauthenticated requests", async () => {
    mockGetSessionFromRequest.mockResolvedValue(null);

    const response = await PATCH(
      jsonRequest("http://localhost/api/admin/motorists/1", "PATCH", validUpdate),
      withParams("1")
    );

    expect(response.status).toBe(401);
    expect(mockUnsafe).not.toHaveBeenCalled();
  });

  it("rejects a non-numeric id", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);

    const response = await PATCH(
      jsonRequest("http://localhost/api/admin/motorists/abc", "PATCH", validUpdate),
      withParams("abc")
    );

    expect(response.status).toBe(400);
    expect(mockUnsafe).not.toHaveBeenCalled();
  });

  it("rejects an invalid payload", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);

    const response = await PATCH(
      jsonRequest("http://localhost/api/admin/motorists/1", "PATCH", { ...validUpdate, phoneNumber: "1" }),
      withParams("1")
    );

    expect(response.status).toBe(400);
    expect(mockUnsafe).not.toHaveBeenCalled();
  });

  it("returns 404 when the motorist does not exist", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockUnsafe.mockResolvedValue([]);

    const response = await PATCH(
      jsonRequest("http://localhost/api/admin/motorists/999", "PATCH", validUpdate),
      withParams("999")
    );

    expect(response.status).toBe(404);
  });

  it("updates an existing motorist", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockUnsafe.mockResolvedValue([{ id: 1 }]);

    const response = await PATCH(
      jsonRequest("http://localhost/api/admin/motorists/1", "PATCH", validUpdate),
      withParams("1")
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true });
    expect(mockUnsafe).toHaveBeenCalledWith(
      expect.stringContaining("UPDATE motorists"),
      ["Amina Kamau", "DL999999", "0712345678", "amina@example.com", "123 Main St", 1]
    );
  });
});

describe("DELETE /api/admin/motorists/[id]", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsWorkerRuntime.mockReturnValue(false);
  });

  it("rejects unauthenticated requests", async () => {
    mockGetSessionFromRequest.mockResolvedValue(null);

    const response = await DELETE(jsonRequest("http://localhost/api/admin/motorists/1", "DELETE"), withParams("1"));

    expect(response.status).toBe(401);
    expect(mockUnsafe).not.toHaveBeenCalled();
  });

  it("returns 404 when the motorist does not exist", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockUnsafe.mockResolvedValue([]);

    const response = await DELETE(jsonRequest("http://localhost/api/admin/motorists/999", "DELETE"), withParams("999"));

    expect(response.status).toBe(404);
  });

  it("deletes an existing motorist and cascades to their motorbikes", async () => {
    mockGetSessionFromRequest.mockResolvedValue(ADMIN_SESSION);
    mockUnsafe.mockResolvedValue([{ id: 1 }]);

    const response = await DELETE(jsonRequest("http://localhost/api/admin/motorists/1", "DELETE"), withParams("1"));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ ok: true });
    expect(mockUnsafe).toHaveBeenCalledWith("DELETE FROM motorists WHERE id = $1 RETURNING id", [1]);
  });
});
