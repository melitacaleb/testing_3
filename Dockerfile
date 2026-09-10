# Multi-stage build for the Next.js app in ./next-app

FROM node:20-alpine AS deps
WORKDIR /app
COPY next-app/package.json next-app/package-lock.json* ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY next-app/ ./
# Dummy values so `next build` can statically analyze env access; real
# values are supplied at runtime via Render's environment variables.
ENV DATABASE_URL="postgres://user:pass@localhost:5432/db"
ENV JWT_SECRET="build-time-placeholder"
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Next.js standalone output bundles only the files needed to run the server.
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
# Render injects $PORT at runtime; the standalone server reads it directly.
CMD ["node", "server.js"]

