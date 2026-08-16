import type { NextConfig } from "next";
import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";

const nextConfig: NextConfig = {
  output: "standalone",
};

// Enables local access to Cloudflare bindings when running `next dev`.
// Guarded so plain `next build` (used for the Docker/Render deploy) isn't
// affected by dev-only Cloudflare context setup.
if (process.env.NODE_ENV === "development") {
  initOpenNextCloudflareForDev();
}

export default nextConfig;
