FROM node:20

WORKDIR /app
COPY package*.json ./
RUN npm ci

# generate prisma client at build time
COPY prisma ./prisma
RUN npx prisma generate

COPY . .
EXPOSE 3000
CMD ["node","server.js"]
