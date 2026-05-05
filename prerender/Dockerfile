# Pre-render service for recipies.mahallem.ist (todo/20 chunk E).
#
# Headless-Chromium snapshot of the Flutter SPA, served only to bots
# via the host-nginx UA-split (see ops/nginx-recipies.mahallem.ist.conf).
# Cache key is `${locale}:${id}:${updatedAt}` — invalidated by the
# /recipes/sitemap endpoint (chunk A) whenever a recipe row is bumped.
FROM node:20-alpine

# Chromium + fonts so headless rendering produces real text in every
# locale we support (Latin / Cyrillic / Arabic / Persian / Kurdish).
RUN apk add --no-cache \
      chromium \
      nss \
      freetype \
      harfbuzz \
      ca-certificates \
      ttf-freefont \
      font-noto \
      font-noto-arabic \
      font-noto-cjk \
      dumb-init \
 && rm -rf /var/cache/apk/*

ENV PUPPETEER_SKIP_DOWNLOAD=1 \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
    NODE_ENV=production

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY server.js ./
COPY lib ./lib

# Cache directory is mounted as a Docker volume in compose.
RUN mkdir -p /var/cache/prerender && chown -R node:node /var/cache/prerender /app
USER node

EXPOSE 8089

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
