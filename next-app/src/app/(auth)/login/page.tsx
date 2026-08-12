import Link from "next/link";
import { getServerSession } from "@/lib/auth";
import { redirect } from "next/navigation";
import AuthLoginForm from "@/components/auth-login-form";

export default async function LoginPage() {
  const session = await getServerSession();
  if (session?.role === "user") {
    redirect("/user/dashboard");
  }

  return (
    <div className="auth-wrap">
      <AuthLoginForm scope="user" title="User Login" />
      <p className="auth-link">
        No account? <Link href="/register">Register here</Link>.
      </p>
      <p className="auth-link">
        Admin? <Link href="/admin/login">Go to admin login</Link>.
      </p>
    </div>
  );
}
