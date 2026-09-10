import postgres, { type Sql } from "postgres";
import { getCloudflareContext } from "@opennextjs/cloudflare";

let sql: Sql | null = null;

type WorkerRuntimeEnv = {
  DATABASE_URL?: string;
  HYPERDRIVE?: { connectionString: string };
};

function getWorkerRuntimeEnv(): WorkerRuntimeEnv | null {
  try {
    return getCloudflareContext().env as WorkerRuntimeEnv;
  } catch {
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
        "HYPERDRIVE binding is missing. Add a 'hyperdrive' entry to wrangler.jsonc and redeploy."
      );
    }

    return postgres(hyperdriveUrl, {
      max: 5,
      fetch_types: false,
      prepare: true,
    });
  }

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
