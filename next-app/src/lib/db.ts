import { neonConfig, Pool, type QueryResultRow } from "@neondatabase/serverless";

// Set only inside the actual Cloudflare Workers runtime, never on Node (Render/Docker).
// See https://developers.cloudflare.com/workers/reference/how-workers-works/#navigatoruseragent
export const isCloudflareWorkers = typeof navigator !== "undefined" && navigator.userAgent === "Cloudflare-Workers";

let pool: Pool | null = null;
let wsConfigured = false;

async function ensureNodeWebSocket() {
  // Workers have a native global WebSocket; Node needs one supplied.
  if (wsConfigured || isCloudflareWorkers) {
    return;
  }
  const { default: ws } = await import("ws");
  neonConfig.webSocketConstructor = ws;
  wsConfigured = true;
}

export async function getPool() {
  await ensureNodeWebSocket();

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is not set.");
  }

  if (isCloudflareWorkers) {
    // Workers can't reuse a WebSocket connection across requests, so each
    // request gets its own Pool; callers are responsible for calling `.end()`.
    return new Pool({ connectionString: databaseUrl });
  }

  if (!pool) {
    pool = new Pool({ connectionString: databaseUrl });
  }

  return pool;
}

export async function query<T extends QueryResultRow = QueryResultRow>(text: string, values: unknown[] = []) {
  if (isCloudflareWorkers) {
    const workersPool = await getPool();
    try {
      return await workersPool.query<T>(text, values);
    } finally {
      await workersPool.end();
    }
  }

  const activePool = await getPool();
  return activePool.query<T>(text, values);
}
