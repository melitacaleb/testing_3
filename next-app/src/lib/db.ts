import postgres, { type Sql } from "postgres";
import { getCloudflareContext } from "@opennextjs/cloudflare";

let sql: Sql | null = null;

type WorkerRuntimeEnv = {
  DATABASE_URL?: string;
  // Bound via wrangler.jsonc -> "hyperdrive". Cloudflare pools/proxies the
  // connection to Postgres for us; this is the officially recommended way
  // to reach Postgres (including Supabase) from a Worker, instead of a raw
  // TCP connection string, which is prone to CONNECT_TIMEOUT at the edge.
  HYPERDRIVE?: { connectionString: string };
};

function getWorkerRuntimeEnv(): WorkerRuntimeEnv | null {
  try {
    return getCloudflareContext().env as WorkerRuntimeEnv;
  } catch {
    // The Worker context only exists during a deployed Worker request.
    return null;
  }
}

export function isWorkerRuntime(): boolean {
  return getWorkerRuntimeEnv() !== null;
}

function createSql() {
  const workerEnv = getWorkerRuntimeEnv();
  const workerRuntime = workerEnv !== null;

  if (workerRuntime) {
    const hyperdriveUrl = workerEnv?.HYPERDRIVE?.connectionString;
    if (!hyperdriveUrl) {
      throw new Error(
        "HYPERDRIVE binding is missing. Add a 'hyperdrive' entry to wrangler.jsonc (see README) and redeploy."
      );
    }

    // Hyperdrive terminates TLS to the origin itself; the connection between
    // the Worker and Hyperdrive doesn't need an ssl option here.
    return postgres(hyperdriveUrl, {
      // Workers cap concurrent external connections; Cloudflare recommends 5.
      max: 5,
      fetch_types: false,
      prepare: true,
    });
  }

  // Local/non-Worker (e.g. `next dev`, scripts) path: talk to Postgres directly.
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is not set.");
  }

  const isLocal = /(^|@)(localhost|127\.0\.0\.1)([:/]|$)/.test(databaseUrl);

  return postgres(databaseUrl, {
    ssl: isLocal ? false : "require",
    max: 10,
    prepare: false,
  });
}

export function getSql() {
  if (isWorkerRuntime()) {
    // Workers can't reuse a connection across requests, so each request gets its own.
    // Hyperdrive keeps the real underlying pool warm on Cloudflare's side.
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
    if (isWorkerRuntime()) {
      await client.end();
    }
  }
}
