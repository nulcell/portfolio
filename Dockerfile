# Stage 1: Build the Astro site
FROM oven/bun:1.4-alpine AS builder

WORKDIR /app

# Install dependencies first (layer-cached separately from source)
COPY package.json bun.lock* ./
RUN bun install

# Copy source and build
COPY astro.config.mjs tsconfig.json ./
COPY public/ ./public/
COPY src/ ./src/
RUN bun run build

# Stage 2: Serve the static output with nginx
FROM nginxinc/nginx-unprivileged:1.31-alpine-slim

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
