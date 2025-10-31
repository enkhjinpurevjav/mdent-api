# ------------------------------
# Stage 1: deps  (build toolchain + install + prisma generate)
# ------------------------------
FROM node:20-bullseye AS deps
WORKDIR /app

# Keep npm quiet & fast
ENV NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    npm_config_loglevel=warn \
    npm_config_update_notifier=false

# Toolchain for any node-gyp/native deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ pkg-config git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Ensure predictable npm version
RUN npm i -g npm@10 && npm -v

# Copy package metadata
COPY package*.json ./

# Diagnostics (separated RUNs so logs show exactly which command fails)
RUN echo ">>> DIAGNOSTICS: PATH=$PATH"
RUN echo ">>> LIST /usr/local/bin" && ls -la /usr/local/bin || true
RUN echo ">>> LIST /usr/bin" && ls -la /usr/bin || true
RUN echo ">>> LIST /bin" && ls -la /bin || true
RUN echo ">>> node --version (if present):" && node --version || echo "node missing"
RUN echo ">>> npm --version (if present):" && npm --version || echo "npm missing"

# Install dependencies (separate RUN so failure is clear)
RUN npm ci --omit=optional || npm install --omit=optional
RUN npm config set legacy-peer-deps true

# Generate Prisma client at build time
COPY prisma ./prisma
RUN npx prisma generate

# ------------------------------
# Stage 2: runtime  (slim, non-root)
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

# Run as the non-root 'node' user
RUN chown -R node:node /app
USER node

# Install curl for healthcheck (done under root then switch back)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS http://127.0.0.1:3000/health || exit 1

EXPOSE 3000
CMD ["node","server.js"]
