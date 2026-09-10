#!/usr/bin/env bash
set -e

echo "This script must be run from inside the next-app/ folder."
if [ ! -f "package.json" ] || [ ! -d "src" ]; then
  echo "ERROR: run this from next-app/ (package.json and src/ not found here)."
  exit 1
fi

FILE="src/lib/server-data.ts"

if grep -q "ORDER BY bike_count::int DESC" "$FILE"; then
  # portable in-place sed for both GNU (Linux/git-bash) and BSD (mac) sed
  sed -i.bak 's/ORDER BY bike_count::int DESC/ORDER BY COUNT(mb.id) DESC/' "$FILE"
  rm -f "$FILE.bak"
  echo "==> Fixed invalid ORDER BY in $FILE"
else
  echo "==> Pattern not found in $FILE (already fixed, or file differs from expected) — no changes made."
fi

echo ""
echo "Done. Run: npm run deploy"
