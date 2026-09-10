import { describe, expect, it } from "vitest";
import { complaintResponseSchema, createComplaintSchema, loginSchema, registerSchema } from "./validators";

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