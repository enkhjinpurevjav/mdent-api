# ------------------------------
# Stage 1: deps  (build toolchain + install + prisma generate)
# ------------------------------
FROM node:20 AS deps
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

# Keep npm at a predictable major (v10 works great with most lockfiles)
RUN npm i -g npm@10 && npm -v

# Install deps first for better layer caching
COPY package*.json ./

# Diagnostic + portable install step
# - prints PATH and common bin directories
# - prints node and npm versions (if present)
# - then tries npm ci, falls back to npm install
RUN echo ">>> DIAGNOSTICS: PATH=$PATH" && \
    echo ">>> LIST /usr/local/bin /usr/bin /bin" && ls -la /usr/local/bin /usr/bin /bin || true && \
    echo ">>> node --version (if present):" && node --version || true && \
    echo ">>> npm --version (if present):" && npm --version || true && \
    echo ">>> starting npm install (ci preferred) ..." && \
    ( npm ci --omit=optional || npm install --omit=optional ) && \
    npm config set legacy-peer-deps true

# Generate Prisma client at build time (faster startup, fewer surprises)
COPY prisma ./prisma
RUN npx prisma generate

# ------------------------------
# Stage 2: runtime  (slim, non-root)
# ------------------------------
FROM node:20
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

# Optional: basic healthcheck hitting /health
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
USER node
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS http://127.0.0.1:3000/health || exit 1

EXPOSE 3000
CMD ["node","server.js"]
