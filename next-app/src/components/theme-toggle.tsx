"use client";

import { useEffect, useState } from "react";
import { Sun, Moon } from "lucide-react";

type Theme = "dark" | "light";

export default function ThemeToggle() {
  const [theme, setTheme] = useState<Theme | null>(null);

  useEffect(() => {
    // Reads the theme already applied by the pre-hydration script in layout.tsx.
    // Doing this in an effect (not a lazy useState initializer) avoids a
    // server/client hydration mismatch, since the server always renders "dark".
    const current = document.documentElement.getAttribute("data-theme") as Theme | null;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setTheme(current ?? "dark");
  }, []);

  function toggle() {
    const next: Theme = theme === "light" ? "dark" : "light";
    setTheme(next);
    document.documentElement.setAttribute("data-theme", next);
    try {
      localStorage.setItem("theme", next);
    } catch {
      // localStorage may be unavailable (private browsing); theme just won't persist.
    }
  }

  if (!theme) {
    return null;
  }

  return (
    <button type="button" onClick={toggle} className="theme-toggle" aria-label="Toggle color theme">
      {theme === "light" ? <Moon size={16} /> : <Sun size={16} />}
      {theme === "light" ? "Dark" : "Light"}
    </button>
  );
}
