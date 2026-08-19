import postgres, { type Sql } from "postgres";
import { getCloudflareContext } from "@opennextjs/cloudflare";

let sql: Sql | null = null;

type WorkerRuntimeEnv = {
  DATABASE_URL?: string;
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

function getDatabaseUrl(): string {
  const workerEnv = getWorkerRuntimeEnv();
  const databaseUrl = workerEnv?.DATABASE_URL ?? process.env.DATABASE_URL;

  if (!databaseUrl) {
    throw new Error(workerEnv ? "DATABASE_URL is missing from Worker runtime variables." : "DATABASE_URL is not set.");
  }

  return databaseUrl;
}

function createSql() {
  const databaseUrl = getDatabaseUrl();
  const workerRuntime = isWorkerRuntime();

  // Hosted providers (Supabase, Neon, etc.) require SSL; only skip it for
  // local/loopback development databases.
  const isLocal = /(^|@)(localhost|127\.0\.0\.1)([:/]|$)/.test(databaseUrl);

  return postgres(databaseUrl, {
    ssl: isLocal ? false : "require",
    max: workerRuntime ? 1 : 10,
    // Safe with connection poolers (e.g. Supabase's transaction-mode pooler).
    prepare: false,
  });
}

export function getSql() {
  if (isWorkerRuntime()) {
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
    if (isWorkerRuntime()) {
      await client.end();
    }
  }
}
