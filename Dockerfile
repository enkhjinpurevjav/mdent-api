# ------------------------------
# Stage 1: deps  (install deps + prisma generate)
# ------------------------------
FROM node:20-bullseye AS deps
WORKDIR /app

ENV NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    npm_config_loglevel=warn \
    npm_config_update_notifier=false

# Toolchain for native deps (safe to keep)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ pkg-config git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copy package metadata first for caching
COPY package*.json ./

# Ensure npm exists (some builders/images can be missing npm in PATH)
RUN if ! command -v npm >/dev/null 2>&1; then \
      apt-get update && apt-get install -y --no-install-recommends npm && rm -rf /var/lib/apt/lists/*; \
    fi && \
    npm -v && npm i -g npm@10 && npm -v

# Install dependencies (prefer ci, fallback to install)
RUN npm ci --omit=optional || npm install --omit=optional

# Generate Prisma client at build time
COPY prisma ./prisma
RUN npx prisma generate

# ------------------------------
# Stage 2: runtime
# ------------------------------
FROM node:20-bullseye
WORKDIR /app

ENV NODE_ENV=production \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    npm_config_loglevel=warn

# Bring in node_modules + generated Prisma client from deps stage
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/prisma ./prisma

# Copy the rest of the app
COPY . .

# Drop devDependencies to slim the final image
RUN npm prune --omit=dev

# Healthcheck dependency
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS http://127.0.0.1:3000/health || exit 1

EXPOSE 3000
CMD ["node","server.js"]
