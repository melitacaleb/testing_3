#!/usr/bin/env bash
set -e
echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
  echo "ERROR: run this from next-app/ (package.json and src/ not found here)."
  exit 1
fi

echo "==> Writing src/lib/validators.test.ts"
mkdir -p "$(dirname "src/lib/validators.test.ts")"
cat > "src/lib/validators.test.ts" << 'FILE_EOF'
import { describe, expect, it } from "vitest";
import {
  addMotoristSchema,
  addMotorbikeSchema,
  complaintResponseSchema,
  createComplaintSchema,
  createReceiptSchema,
  editMotoristSchema,
  loginSchema,
  registerSchema,
} from "./validators";

describe("loginSchema", () => {
  it("accepts a valid admin login", () => {
    expect(loginSchema.safeParse({ email: "admin@example.com", password: "secret", scope: "admin" }).success).toBe(true);
  });

  it("rejects an invalid email", () => {
    expect(loginSchema.safeParse({ email: "not-an-email", password: "secret", scope: "admin" }).success).toBe(false);
  });
});

describe("registerSchema", () => {
  const registration = {
    fullName: "Amina Kamau",
    email: "amina@example.com",
    password: "secret12",
    confirmPassword: "secret12",
    licenseNumber: "DL123456",
    phoneNumber: "0712345678",
  };

  it("accepts a valid registration", () => {
    expect(registerSchema.safeParse(registration).success).toBe(true);
  });

  it("rejects different passwords", () => {
    expect(registerSchema.safeParse({ ...registration, confirmPassword: "different" }).success).toBe(false);
  });
});

describe("complaint schemas", () => {
  it("enforces complaint and response minimum lengths", () => {
    expect(createComplaintSchema.safeParse({ subject: "Road", message: "Unsafe junction" }).success).toBe(true);
    expect(complaintResponseSchema.safeParse({ status: "resolved", adminResponse: "Done" }).success).toBe(true);
    expect(createComplaintSchema.safeParse({ subject: "No", message: "Short" }).success).toBe(false);
  });
});

describe("addMotoristSchema / editMotoristSchema", () => {
  const motorist = {
    fullName: "Amina Kamau",
    licenseNumber: "DL123456",
    phoneNumber: "0712345678",
    email: "amina@example.com",
    address: "123 Main St",
  };

  it("accepts a valid motorist", () => {
    expect(addMotoristSchema.safeParse(motorist).success).toBe(true);
    expect(editMotoristSchema.safeParse(motorist).success).toBe(true);
  });

  it("allows an empty email but rejects a malformed one", () => {
    expect(addMotoristSchema.safeParse({ ...motorist, email: "" }).success).toBe(true);
    expect(addMotoristSchema.safeParse({ ...motorist, email: "not-an-email" }).success).toBe(false);
  });

  it("rejects a short license number or phone number", () => {
    expect(addMotoristSchema.safeParse({ ...motorist, licenseNumber: "AB" }).success).toBe(false);
    expect(addMotoristSchema.safeParse({ ...motorist, phoneNumber: "123" }).success).toBe(false);
  });
});

describe("addMotorbikeSchema", () => {
  const commercialBike = {
    motoristId: 1,
    registrationNumber: "KBA 123A",
    brand: "Honda",
    model: "CBR 150",
    purpose: "commercial" as const,
    powerType: "fuel" as const,
  };

  it("accepts a valid commercial or personal bike without owner/hire fields", () => {
    expect(addMotorbikeSchema.safeParse(commercialBike).success).toBe(true);
    expect(
      addMotorbikeSchema.safeParse({ ...commercialBike, purpose: "personal_transport" }).success
    ).toBe(true);
  });

  it("accepts electric as a power type", () => {
    expect(addMotorbikeSchema.safeParse({ ...commercialBike, powerType: "electric" }).success).toBe(true);
  });

  it("rejects an on-hire bike missing owner name, phone, or hire rate", () => {
    expect(addMotorbikeSchema.safeParse({ ...commercialBike, purpose: "hire" }).success).toBe(false);
    expect(
      addMotorbikeSchema.safeParse({
        ...commercialBike,
        purpose: "hire",
        ownerName: "Mike",
        ownerPhone: "0745678901",
      }).success
    ).toBe(false);
  });

  it("accepts an on-hire bike with owner name, phone, and hire rate", () => {
    expect(
      addMotorbikeSchema.safeParse({
        ...commercialBike,
        purpose: "hire",
        ownerName: "Mike Wilson",
        ownerPhone: "0745678901",
        hireRate: 1500,
      }).success
    ).toBe(true);
  });

  it("rejects an invalid or missing power type", () => {
    expect(addMotorbikeSchema.safeParse({ ...commercialBike, powerType: "diesel" }).success).toBe(false);
    const withoutPowerType: Partial<typeof commercialBike> = { ...commercialBike };
    delete withoutPowerType.powerType;
    expect(addMotorbikeSchema.safeParse(withoutPowerType).success).toBe(false);
  });
});

describe("createReceiptSchema", () => {
  it("accepts a valid receipt and coerces numeric strings", () => {
    const result = createReceiptSchema.safeParse({
      userId: "3",
      title: "Registration fee",
      amount: "1500.50",
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.userId).toBe(3);
      expect(result.data.amount).toBe(1500.5);
    }
  });

  it("rejects a negative amount or a too-short title", () => {
    expect(createReceiptSchema.safeParse({ userId: 1, title: "Fee", amount: -5 }).success).toBe(false);
    expect(createReceiptSchema.safeParse({ userId: 1, title: "Ab", amount: 10 }).success).toBe(false);
  });
});
FILE_EOF

echo "==> Writing e2e/home.spec.ts"
mkdir -p "$(dirname "e2e/home.spec.ts")"
cat > "e2e/home.spec.ts" << 'FILE_EOF'
import { expect, test } from "@playwright/test";

test("home page offers entry points for users and administrators", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByRole("heading", { name: "Motorist Traffic Control System" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Motorist login" })).toHaveAttribute("href", "/login");
  await expect(page.getByRole("link", { name: "Admin console" })).toHaveAttribute("href", "/admin/login");
});
FILE_EOF

echo "==> Writing e2e/admin-motorist-crud.spec.ts"
mkdir -p "$(dirname "e2e/admin-motorist-crud.spec.ts")"
cat > "e2e/admin-motorist-crud.spec.ts" << 'FILE_EOF'
import { expect, test } from "@playwright/test";

// These credentials come from supabase/seed.sql's default admin record.
// If you've changed the seeded admin password, update ADMIN_PASSWORD to match.
const ADMIN_EMAIL = "admin@example.com";
const ADMIN_PASSWORD = "melita@123";

test.describe("Admin: motorist CRUD", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/admin/login");
    await page.getByLabel(/email/i).fill(ADMIN_EMAIL);
    await page.getByLabel(/password/i).fill(ADMIN_PASSWORD);
    await page.getByRole("button", { name: /log ?in|sign ?in/i }).click();
    await page.waitForURL("**/admin/dashboard");
  });

  test("admin can add, edit, and delete a motorist", async ({ page }) => {
    const uniqueSuffix = Date.now().toString().slice(-6);
    const fullName = `E2E Test Motorist ${uniqueSuffix}`;
    const licenseNumber = `E2E${uniqueSuffix}`;
    const updatedName = `${fullName} (Edited)`;

    await page.goto("/admin/motorists");

    // --- Add ---
    await page.getByRole("button", { name: "+ Add Motorist" }).click();
    await page.getByLabel(/full name/i).fill(fullName);
    await page.getByLabel(/license number/i).fill(licenseNumber);
    await page.getByLabel(/phone number/i).fill("0700000000");
    await page.getByRole("button", { name: /save motorist/i }).click();

    const row = page.getByRole("row", { name: new RegExp(fullName) });
    await expect(row).toBeVisible();
    await expect(row).toContainText(licenseNumber);

    // --- Edit ---
    await row.getByTitle("Edit").click();
    const editRow = page.locator("tr", { has: page.locator("form") });
    await editRow.getByLabel(/full name/i).fill(updatedName);
    await editRow.locator("button[type=submit]").click();

    const updatedRow = page.getByRole("row", { name: new RegExp(updatedName.replace(/[()]/g, "\\$&")) });
    await expect(updatedRow).toBeVisible();

    // --- Delete ---
    page.once("dialog", (dialog) => dialog.accept());
    await updatedRow.getByTitle("Delete").click();
    await expect(page.getByRole("row", { name: new RegExp(updatedName.replace(/[()]/g, "\\$&")) })).toHaveCount(0);
  });
});
FILE_EOF

echo "==> Writing src/app/api/admin/motorists/route.test.ts"
mkdir -p "$(dirname "src/app/api/admin/motorists/route.test.ts")"
cat > "src/app/api/admin/motorists/route.test.ts" << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/app/api/admin/motorists/[id]/route.test.ts"
mkdir -p "$(dirname "src/app/api/admin/motorists/[id]/route.test.ts")"
cat > "src/app/api/admin/motorists/[id]/route.test.ts" << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/app/api/admin/motorbikes/route.test.ts"
mkdir -p "$(dirname "src/app/api/admin/motorbikes/route.test.ts")"
cat > "src/app/api/admin/motorbikes/route.test.ts" << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing src/app/api/admin/receipts/route.test.ts"
mkdir -p "$(dirname "src/app/api/admin/receipts/route.test.ts")"
cat > "src/app/api/admin/receipts/route.test.ts" << 'FILE_EOF'
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
FILE_EOF

echo ""
echo "Test suite expanded: unit tests for all new validators, integration tests"
echo "for motorist/motorbike/receipt admin routes, and a real e2e CRUD flow."
echo ""
echo "Run unit + integration tests now:"
echo "  npm run test"
echo ""
echo "Run the e2e suite (needs a real DATABASE_URL and JWT_SECRET in .env.local,"
echo "separate from .dev.vars, since it runs a plain node server, not a Worker):"
echo "  npm run test:install-browser   (first time only)"
echo "  npm run test:e2e"
