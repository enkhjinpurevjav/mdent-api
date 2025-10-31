FROM node:20
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
RUN npx prisma generate

COPY . .
EXPOSE 3000
CMD ["node","server.js"]
