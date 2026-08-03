# Multi-stage production Dockerfile
FROM node:22-alpine AS base
WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 5000
ENV NODE_ENV=production

CMD ["node", "src/server.js"]
