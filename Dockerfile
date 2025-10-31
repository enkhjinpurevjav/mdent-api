# ---- deps stage with build tools (robust) ----
FROM node:20 AS deps
WORKDIR /app

# Keep npm quiet & fast
ENV NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    npm_config_loglevel=warn \
    npm_config_update_notifier=false

# Native build toolchain for node-gyp packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ pkg-config git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Ensure npm major matches what usually generated the lockfile (v10 is common)
RUN npm i -g npm@10 && npm -v

# Install deps (tolerant to peer deps, skip optional that often fail to compile)
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm install --legacy-peer-deps --omit=optional

# Generate Prisma client at build time
COPY prisma ./prisma
RUN npx prisma generate

# ---- runtime stage (clean) ----
FROM node:20
WORKDIR /app

ENV NODE_ENV=production \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    npm_config_loglevel=warn

# Bring node_modules + generated client
COPY --from=deps /app /app

# Copy the rest of the app
COPY . .

# Drop dev dependencies to slim the image
RUN npm prune --omit=dev

EXPOSE 3000
CMD ["node","server.js"]
