import postgres, { type Sql } from "postgres";

// Set only inside the actual Cloudflare Workers runtime, never on Node (Render/Docker).
// See https://developers.cloudflare.com/workers/reference/how-workers-works/#navigatoruseragent
export const isCloudflareWorkers = typeof navigator !== "undefined" && navigator.userAgent === "Cloudflare-Workers";

let sql: Sql | null = null;

function createSql() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is not set.");
  }

  // Hosted providers (Supabase, Neon, etc.) require SSL; only skip it for
  // local/loopback development databases.
  const isLocal = /(^|@)(localhost|127\.0\.0\.1)([:/]|$)/.test(databaseUrl);

  return postgres(databaseUrl, {
    ssl: isLocal ? false : "require",
    max: isCloudflareWorkers ? 1 : 10,
    // Safe with connection poolers (e.g. Supabase's transaction-mode pooler).
    prepare: false,
  });
}

export function getSql() {
  if (isCloudflareWorkers) {
    // Workers can't reuse a connection across requests, so each request gets its own.
    return createSql();
  }

  if (!sql) {
    sql = createSql();
  }

  return sql;
}

export async function query<T extends Record<string, unknown> = Record<string, unknown>>(
  text: string,
  values: unknown[] = []
): Promise<{ rows: T[] }> {
  const client = getSql();
  try {
    const rows = await client.unsafe(text, values as never[]);
    return { rows: rows as unknown as T[] };
  } finally {
    if (isCloudflareWorkers) {
      await client.end();
    }
  }
}
