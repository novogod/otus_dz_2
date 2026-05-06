# ── Stage 1: build Flutter web ────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.41.0 AS builder

WORKDIR /app

# Copy dependency manifests first for layer-cache efficiency.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the source and build.
COPY . .
# Note: Flutter 3.27+ ignores --pwa-strategy and always emits a
# noop flutter_service_worker.js. We ship our own SW at
# web/pwa_sw.js (registered from web/index.html) to satisfy
# Chrome / Edge / Samsung install criteria.
RUN flutter build web --release --no-tree-shake-icons

# ── Stage 2: serve with nginx ──────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Remove default nginx static content.
RUN rm -rf /usr/share/nginx/html/*

# Copy Flutter web output.
COPY --from=builder /app/build/web /usr/share/nginx/html

# nginx config: serve index.html for all routes (Flutter router).
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
