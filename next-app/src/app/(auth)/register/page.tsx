import Link from "next/link";
import { getServerSession } from "@/lib/auth";
import { redirect } from "next/navigation";
import RegisterForm from "@/components/register-form";

export default async function RegisterPage() {
  const session = await getServerSession();
  if (session?.role === "user") {
    redirect("/user/dashboard");
  }

  return (
    <div className="auth-wrap">
      <RegisterForm />
      <p className="auth-link">
        Already registered? <Link href="/login">Sign in</Link>.
      </p>
    </div>
  );
}
