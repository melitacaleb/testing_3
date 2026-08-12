export type AppRole = "admin" | "user";

export type SessionPayload = {
  userId: number;
  role: AppRole;
  email: string;
  name: string;
};

export type DashboardStats = {
  totalMotorists: number;
  totalMotorbikes: number;
  commercialCount: number;
  hireCount: number;
  personalCount: number;
};

export type PurposeStats = {
  commercial: number;
  personal_transport: number;
  hire: number;
};

export type UserAccount = {
  id: number;
  full_name: string;
  email: string;
  role: AppRole;
  status: "active" | "inactive";
  motorist_id: number | null;
};
