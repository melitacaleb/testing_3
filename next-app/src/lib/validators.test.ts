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
