import { Pool, type QueryResultRow } from "pg";

// Set only inside the actual Cloudflare Workers runtime, never on Node (Render/Docker).
// See https://developers.cloudflare.com/workers/reference/how-workers-works/#navigatoruseragent
const isCloudflareWorkers = typeof navigator !== "undefined" && navigator.userAgent === "Cloudflare-Workers";

let pool: Pool | null = null;

async function getWorkersPool() {
  // Workers isolates can't share a pooled TCP connection across requests, so we
  // create a fresh, single-use pool per request. Hyperdrive handles pooling for us.
  const { getCloudflareContext } = await import("@opennextjs/cloudflare");
  const { env } = getCloudflareContext();
  if (!env.HYPERDRIVE) {
    throw new Error("HYPERDRIVE binding is not configured in wrangler.jsonc.");
  }

  return new Pool({
    connectionString: env.HYPERDRIVE.connectionString,
    maxUses: 1,
  });
}

export async function getPool() {
  if (isCloudflareWorkers) {
    return getWorkersPool();
  }

  if (!pool) {
    const databaseUrl = process.env.DATABASE_URL;
    if (!databaseUrl) {
      throw new Error("DATABASE_URL is not set.");
    }

    // Hosted providers (Supabase, Neon, etc.) require SSL and don't always
    // include `sslmode=require` in the connection string they hand you.
    // Only skip SSL for local/loopback development databases.
    const isLocal = /(^|@)(localhost|127\.0\.0\.1)([:/]|$)/.test(databaseUrl);
    const ssl = isLocal ? false : { rejectUnauthorized: false };

    pool = new Pool({
      connectionString: databaseUrl,
      ssl,
    });
  }

  return pool;
}

export async function query<T extends QueryResultRow = QueryResultRow>(text: string, values: unknown[] = []) {
  const activePool = await getPool();
  return activePool.query<T>(text, values);
}
