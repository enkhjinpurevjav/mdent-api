FROM node:20
WORKDIR /app

# make npm quieter/faster
ENV NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    NODE_ENV=production

# 1) Install with standard "npm install" (includes dev deps)
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm install

# 2) Generate Prisma client (needs "prisma" which is usually a devDependency)
COPY prisma ./prisma
RUN npx prisma generate

# 3) Copy the rest of the app
COPY . .

# 4) Remove dev dependencies for a slimmer final image
RUN npm prune --omit=dev

EXPOSE 3000
CMD ["node","server.js"]
