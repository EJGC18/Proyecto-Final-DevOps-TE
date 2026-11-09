# --- Etapa 1: "build" del frontend ---
# Inserta la versión (SHA del commit) en el HTML para poder verificar qué versión está desplegada.
FROM alpine:3.20 AS build
ARG APP_VERSION=dev
WORKDIR /src
COPY public/ ./
RUN sed -i "s/__APP_VERSION__/${APP_VERSION}/g" index.html

# --- Etapa 2: servidor web ---
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/ /usr/share/nginx/html/
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1
