// Minimal ambient typing for the bindings db.ts reads via getCloudflareContext().
// Intentionally NOT the full `wrangler types` output (cloudflare-env.d.ts) - that file
// redefines global Request/Response/etc. and breaks the plain Node.js build used for
// the Docker/Render deploy target. Regenerate with `npm run cf-typegen` only for local
// reference; do not commit/include the generated file in tsconfig.
declare global {
  interface CloudflareEnv {
    HYPERDRIVE?: { connectionString: string };
  }
}

export {};
