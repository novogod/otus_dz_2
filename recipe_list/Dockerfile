# ── Stage 1: build Flutter web ────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.41.0 AS builder

WORKDIR /app

# Copy dependency manifests first for layer-cache efficiency.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the source and build.
COPY . .
# --pwa-strategy=offline-first ships a real service worker with a
# fetch handler so Chrome / Edge show the "Install app" button and
# the PWA works offline. Without this flag Flutter 3.27+ emits a
# noop service worker that just unregisters itself.
RUN flutter build web --release --no-tree-shake-icons --pwa-strategy=offline-first

# ── Stage 2: serve with nginx ──────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Remove default nginx static content.
RUN rm -rf /usr/share/nginx/html/*

# Copy Flutter web output.
COPY --from=builder /app/build/web /usr/share/nginx/html

# nginx config: serve index.html for all routes (Flutter router).
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
