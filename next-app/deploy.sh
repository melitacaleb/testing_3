#!/usr/bin/env bash
set -e

echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -f ".dev.vars" ]; then
  echo "ERROR: run this from next-app/ (package.json and .dev.vars not found here)."
  exit 1
fi

DB_URL="$(grep '^DATABASE_URL=' .dev.vars | cut -d= -f2-)"

if [ -z "$DB_URL" ]; then
  echo "ERROR: no DATABASE_URL line found in .dev.vars."
  echo "Add one like: DATABASE_URL=postgresql://postgres:PASSWORD@db.PROJECT_REF.supabase.co:5432/postgres"
  exit 1
fi

export CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE="$DB_URL"
echo "==> Hyperdrive local connection string set for this deploy."
npm run deploy
