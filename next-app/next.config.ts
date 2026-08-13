import type { NextConfig } from "next";
import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";

const nextConfig: NextConfig = {
  output: "standalone",
};

// Enables local access to Cloudflare bindings when running `next dev`.
// Guarded so plain `next build` (used for the Docker/Render deploy) doesn't
// require a local Hyperdrive connection string.
if (process.env.NODE_ENV === "development") {
  initOpenNextCloudflareForDev();
}

export default nextConfig;
