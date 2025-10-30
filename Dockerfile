FROM node:20-alpine
WORKDIR /app

# 1) install deps
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev || npm install --omit=dev

# 2) copy source (includes prisma/, server.js, etc.)
COPY . .

# 3) tools for healthcheck
RUN apk add --no-cache curl

EXPOSE 80
ENV PORT=80 NODE_ENV=production


# replace your HEALTHCHECK with this:
HEALTHCHECK --interval=20s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://127.0.0.1/health || exit 1


# 5) startup: generate client using real env, migrate, then start server
CMD ["sh","-lc", "\
 
  echo '[entrypoint] prisma generate...'; npx prisma generate --schema=./prisma/schema.prisma; \
  echo '[entrypoint] prisma migrate deploy...'; npx prisma migrate deploy --schema=./prisma/schema.prisma || (echo '[entrypoint] migrate failed; trying db push' && npx prisma db push --schema=./prisma/schema.prisma); \
  echo '[entrypoint] starting server...'; exec node server.js \
"]

# Build + runtime (simple) – Debian base to match Prisma binary
FROM node:20

WORKDIR /app

# Install deps first (better layer caching)
COPY package*.json ./
RUN npm ci

# Generate Prisma client at build time (prevents crash loops)
COPY prisma ./prisma
RUN npx prisma generate

# Copy the rest
COPY . .

EXPOSE 3000
CMD ["node","server.js"]

