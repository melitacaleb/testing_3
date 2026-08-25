#!/usr/bin/env bash
set -e

echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
  echo "ERROR: run this from next-app/ (package.json and src/ not found here)."
  exit 1
fi

echo ""
echo "You'll need two things ready before continuing:"
echo "  1) Your Hyperdrive config ID (from 'npx wrangler hyperdrive create ...')"
echo "  2) Your Supabase DIRECT connection string (port 5432), e.g.:"
echo "     postgresql://postgres:PASSWORD@db.PROJECT_REF.supabase.co:5432/postgres"
echo ""

read -rp "Paste your Hyperdrive config ID: " HYPERDRIVE_ID
read -rp "Paste your Supabase DIRECT connection string: " DIRECT_DB_URL

if [ -z "$HYPERDRIVE_ID" ] || [ -z "$DIRECT_DB_URL" ]; then
  echo "ERROR: both values are required."
  exit 1
fi

echo ""
echo "==> Writing src/middleware.ts (and removing src/proxy.ts if present)"
rm -f src/proxy.ts
cat > src/middleware.ts << 'FILE_EOF'
import { NextResponse, type NextRequest } from "next/server";
import { getSessionFromRequest } from "@/lib/session";

const adminPaths = ["/admin/dashboard", "/admin/motorists", "/admin/reports", "/admin/complaints"];
const userPaths = ["/user/dashboard", "/user/profile", "/user/complaints", "/user/receipts"];

export async function middleware(request: NextRequest) {
  const session = await getSessionFromRequest(request);
  const { pathname } = request.nextUrl;

  const isAdminPath = adminPaths.some((path) => pathname.startsWith(path));
  const isUserPath = userPaths.some((path) => pathname.startsWith(path));

  if (isAdminPath && (!session || session.role !== "admin")) {
    return NextResponse.redirect(new URL("/admin/login", request.url));
  }

  if (isUserPath && (!session || session.role !== "user")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (pathname === "/admin/login" && session?.role === "admin") {
    return NextResponse.redirect(new URL("/admin/dashboard", request.url));
  }

  if ((pathname === "/login" || pathname === "/register") && session?.role === "user") {
    return NextResponse.redirect(new URL("/user/dashboard", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*", "/user/:path*", "/login", "/register"],
};
FILE_EOF

echo "==> Writing src/lib/db.ts"
cat > src/lib/db.ts << 'FILE_EOF'
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
FILE_EOF

echo "==> Writing wrangler.jsonc"
cat > wrangler.jsonc << FILE_EOF
{
	"\$schema": "node_modules/wrangler/config-schema.json",
	"main": ".open-next/worker.js",
	"name": "testing-3",
	"compatibility_date": "2026-08-12",
	"compatibility_flags": ["nodejs_compat", "global_fetch_strictly_public"],
	"keep_vars": true,
	"assets": {
		"directory": ".open-next/assets",
		"binding": "ASSETS"
	},
	"hyperdrive": [
		{
			"binding": "HYPERDRIVE",
			"id": "$HYPERDRIVE_ID"
		}
	],
	"services": [
		{
			"binding": "WORKER_SELF_REFERENCE",
			"service": "testing-3"
		}
	]
}
FILE_EOF

echo "==> Updating .dev.vars"
touch .dev.vars
grep -v '^CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE=' .dev.vars > .dev.vars.tmp 2>/dev/null || true
mv .dev.vars.tmp .dev.vars
grep -v '^DATABASE_URL=' .dev.vars > .dev.vars.tmp 2>/dev/null || true
mv .dev.vars.tmp .dev.vars
echo "DATABASE_URL=$DIRECT_DB_URL" >> .dev.vars
echo "CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE=$DIRECT_DB_URL" >> .dev.vars

echo ""
echo "All files written."
echo ""
echo "Reminder: if you haven't already, also set your JWT_SECRET on the deployed Worker:"
echo "  npx wrangler secret put JWT_SECRET"
echo ""
echo "And remove the old raw DATABASE_URL Worker secret, now replaced by Hyperdrive:"
echo "  npx wrangler secret delete DATABASE_URL"
echo ""
echo "Then deploy:"
echo "  npm run deploy"
