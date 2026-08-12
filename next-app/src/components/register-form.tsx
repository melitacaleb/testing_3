"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function RegisterForm() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setLoading(true);

    const formData = new FormData(event.currentTarget);
    const payload = {
      fullName: String(formData.get("fullName") ?? ""),
      email: String(formData.get("email") ?? ""),
      password: String(formData.get("password") ?? ""),
      confirmPassword: String(formData.get("confirmPassword") ?? ""),
      licenseNumber: String(formData.get("licenseNumber") ?? ""),
      phoneNumber: String(formData.get("phoneNumber") ?? ""),
      address: String(formData.get("address") ?? ""),
    };

    try {
      const response = await fetch("/api/auth/register", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = await response.json();
      if (!response.ok) {
        setError(data.error ?? "Registration failed");
        return;
      }

      router.push("/user/dashboard");
      router.refresh();
    } catch {
      setError("Unexpected network error. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="card">
      <h1>Create account</h1>
      <p className="muted">Register as a motorist user account.</p>

      <label>Full name<input name="fullName" required minLength={3} /></label>
      <label>Email<input type="email" name="email" required /></label>
      <label>Password<input type="password" name="password" required minLength={6} /></label>
      <label>Confirm password<input type="password" name="confirmPassword" required minLength={6} /></label>
      <label>License number<input name="licenseNumber" required /></label>
      <label>Phone number<input name="phoneNumber" required /></label>
      <label>Address<textarea name="address" rows={3} /></label>

      {error ? <p className="error">{error}</p> : null}
      <button type="submit" disabled={loading}>{loading ? "Creating account..." : "Register"}</button>
    </form>
  );
}
