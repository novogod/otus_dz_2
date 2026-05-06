// Minimal service worker so the PWA satisfies the browser install
// criteria (Chrome / Edge / Samsung require a service worker with
// a functional `fetch` handler before exposing the "Install app"
// button or `beforeinstallprompt` event).
//
// We intentionally keep this dumb: network-first, no caching,
// no offline support. Flutter app shell + assets are big and
// version-busted, so adding cache-aside here would just risk
// stale UIs without much benefit. The SW only exists so the
// browser is willing to install the app.

'use strict';

const CACHE = 'otus-food-shell-v1';
const SHELL = ['/', '/index.html', '/manifest.json', '/favicon.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(SHELL)).catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  event.respondWith(
    fetch(req).catch(() => caches.match(req).then((r) => r || caches.match('/')))
  );
});
