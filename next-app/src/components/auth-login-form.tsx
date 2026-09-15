"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

type Props = {
  scope: "admin" | "user";
  title: string;
};

export default function AuthLoginForm({ scope, title }: Props) {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const oauthError = params.get("error");
    if (oauthError) {
      // Reading the error the Google OAuth callback redirected back with —
      // an external system (the URL), read once after mount.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setError(oauthError);
    }
  }, []);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setLoading(true);

    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email, password, scope }),
      });

      const data = (await response.json()) as { error?: string; redirectTo?: string };
      if (!response.ok) {
        setError(data.error ?? "Login failed");
        return;
      }

      router.push(data.redirectTo ?? "/");
      router.refresh();
    } catch {
      setError("Unexpected network error. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={onSubmit} className="card">
      <h1>{title}</h1>
      <p className="muted">Sign in with your existing account credentials.</p>

      <label>
        Email
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          placeholder="name@example.com"
        />
      </label>

      <label>
        Password
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          placeholder="Enter your password"
        />
      </label>

      {error ? <p className="error">{error}</p> : null}

      <button type="submit" disabled={loading}>
        {loading ? "Signing in..." : "Sign in"}
      </button>

      <div className="auth-divider">
        <span>or</span>
      </div>

      <a href={`/api/auth/google/start?scope=${scope}`} className="oauth-button">
        <span className="oauth-google-mark">G</span>
        Continue with Google
      </a>
    </form>
  );
}
