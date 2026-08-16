import type { NextConfig } from "next";
import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";

const nextConfig: NextConfig = {
  output: "standalone",
  // pg-cloudflare's package.json only exposes dist/index.js under the "workerd"
  // export condition; without this, Next's file tracer resolves the "default"
  // condition (dist/empty.js) and never copies the real file for the Workers build.
  serverExternalPackages: ["pg", "pg-cloudflare"],
};

// Enables local access to Cloudflare bindings when running `next dev`.
// Guarded so plain `next build` (used for the Docker/Render deploy) doesn't
// require a local Hyperdrive connection string.
if (process.env.NODE_ENV === "development") {
  initOpenNextCloudflareForDev();
}

export default nextConfig;
