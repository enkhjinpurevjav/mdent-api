# ---- deps stage (has build tools) ----
FROM node:20 AS deps
WORKDIR /app

# speed & fewer surprises
ENV NPM_CONFIG_AUDIT=false NPM_CONFIG_FUND=false
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ git && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm install --omit=optional

# generate prisma client (needs dev deps present)
COPY prisma ./prisma
RUN npx prisma generate

# ---- runtime stage (slim) ----
FROM node:20
WORKDIR /app
ENV NODE_ENV=production NPM_CONFIG_AUDIT=false NPM_CONFIG_FUND=false

# bring node_modules + generated client
COPY --from=deps /app /app

# add the rest of the app
COPY . .

# strip dev deps from final image
RUN npm prune --omit=dev

EXPOSE 3000
CMD ["node","server.js"]
