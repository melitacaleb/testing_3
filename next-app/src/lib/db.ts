import { Pool, type QueryResultRow } from "pg";

let pool: Pool | null = null;

export function getPool() {
  if (!pool) {
    const databaseUrl = process.env.DATABASE_URL;
    if (!databaseUrl) {
      throw new Error("DATABASE_URL is not set.");
    }

    const ssl = databaseUrl.includes("sslmode=require")
      ? { rejectUnauthorized: false }
      : false;

    pool = new Pool({
      connectionString: databaseUrl,
      ssl,
    });
  }

  return pool;
}

export async function query<T extends QueryResultRow = QueryResultRow>(text: string, values: unknown[] = []) {
  return getPool().query<T>(text, values);
}
