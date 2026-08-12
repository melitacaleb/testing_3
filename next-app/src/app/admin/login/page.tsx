import AuthLoginForm from "@/components/auth-login-form";
import { getServerSession } from "@/lib/auth";
import { redirect } from "next/navigation";

export default async function AdminLoginPage() {
  const session = await getServerSession();
  if (session?.role === "admin") {
    redirect("/admin/dashboard");
  }

  return (
    <div className="auth-wrap">
      <AuthLoginForm scope="admin" title="Admin Login" />
    </div>
  );
}
