import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
  scope: z.enum(["admin", "user"]),
});

export const registerSchema = z
  .object({
    fullName: z.string().min(3),
    email: z.string().email(),
    password: z.string().min(6),
    confirmPassword: z.string().min(6),
    licenseNumber: z.string().min(4),
    phoneNumber: z.string().min(10),
    address: z.string().optional(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

export const createComplaintSchema = z.object({
  subject: z.string().min(3),
  message: z.string().min(10),
});

export const complaintResponseSchema = z.object({
  status: z.enum(["open", "in_progress", "resolved", "closed"]),
  adminResponse: z.string().min(3),
});

export const addMotoristSchema = z.object({
  fullName: z.string().min(3),
  licenseNumber: z.string().min(4),
  phoneNumber: z.string().min(10),
  email: z.string().email().optional().or(z.literal("")),
  address: z.string().optional(),
});

export const editMotoristSchema = addMotoristSchema;

export const addMotorbikeSchema = z
  .object({
    motoristId: z.coerce.number().int().positive(),
    registrationNumber: z.string().min(3),
    brand: z.string().min(1),
    model: z.string().min(1),
    color: z.string().optional(),
    manufactureYear: z.coerce.number().int().min(1900).max(2100).optional(),
    purpose: z.enum(["commercial", "personal_transport", "hire"]),
    powerType: z.enum(["electric", "fuel"]),
    ownerName: z.string().optional(),
    ownerPhone: z.string().optional(),
    ownerEmail: z.string().email().optional().or(z.literal("")),
    ownerAddress: z.string().optional(),
    hireRate: z.coerce.number().nonnegative().optional(),
    hireStartDate: z.string().optional(),
    hireEndDate: z.string().optional(),
  })
  .refine(
    (data) =>
      data.purpose !== "hire" || (data.ownerName && data.ownerPhone && data.hireRate !== undefined),
    {
      message: "Owner name, owner phone, and hire rate are required when purpose is 'hire'.",
      path: ["ownerName"],
    }
  );

export const createReceiptSchema = z.object({
  userId: z.coerce.number().int().positive(),
  title: z.string().min(3),
  amount: z.coerce.number().nonnegative(),
  description: z.string().optional(),
});
