# ── dev: vite dev server with HMR ────────────────────────────────────────────
FROM node:20-alpine AS dev
WORKDIR /app
EXPOSE 5173
CMD ["sh", "-c", "npm install && npm run dev -- --host"]

# ── builder ──────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ── prod: caddy ───────────────────────────────────────────────────────────────
FROM caddy:2-alpine AS prod
COPY --from=builder /app/dist /srv
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80
