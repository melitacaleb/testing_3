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
