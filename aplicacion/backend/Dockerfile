# --- Etapa 1: dependencias de producción ---
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# --- Etapa 2: imagen final ---
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=3000
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# No ejecutar como root
USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/health || exit 1

CMD ["node", "src/server.js"]
