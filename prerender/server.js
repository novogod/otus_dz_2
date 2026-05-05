// Pre-render service for recipies.mahallem.ist (todo/20 chunk E).
//
// Express server on port 8089. Receives `GET /<locale>/recipes/<id>`
// (proxied here by the host nginx UA-split — only bots reach this
// service). Returns a static HTML snapshot of the SPA, cached on disk
// keyed by `${locale}:${id}:${updatedAt}`.
//
// Rendering pipeline:
//   1. Look up the row's updatedAt via the local-user-portal endpoint
//      `/recipes/sitemap` (chunk A). One in-memory map, refreshed every
//      RECIPES_SITEMAP_TTL_MS (default 5 min) — the same TTL the
//      endpoint advertises with `Cache-Control: max-age=300`.
//   2. Compute the cache key. If the file is on disk, serve it.
//   3. Otherwise launch headless Chromium against
//      `${SPA_ORIGIN}/<locale>/recipes/<id>?ssr=1`, wait for either
//      `<meta name="ssr-ready">` or networkidle (whichever first),
//      capture `document.documentElement.outerHTML`.
//   4. Run scrubFlutterShell() to drop Flutter scripts / flt-* elements.
//   5. Persist to cache, respond.
//
// On Chromium / network failures we respond with a clean 502 and let
// nginx fall back to the SPA — bots see degraded UX, never a stale
// snapshot.
//
// Health probe: GET /healthz → 200 "ok".
import express from 'express';
import fs from 'node:fs/promises';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import {
    buildSpaUrl,
    cacheFileName,
    cacheKey,
    parseRecipePath,
    scrubFlutterShell,
    SUPPORTED_LOCALES,
} from './lib/render-utils.js';

const PORT = Number(process.env.PORT || 8089);
const SPA_ORIGIN = process.env.SPA_ORIGIN || 'http://recipe_list_web';
const RECIPES_API = process.env.RECIPES_API_BASE || 'http://172.25.0.41:4000';
const SITEMAP_TTL_MS = Number(process.env.RECIPES_SITEMAP_TTL_MS || 300_000);
const RENDER_TIMEOUT_MS = Number(process.env.RENDER_TIMEOUT_MS || 25_000);
const SSR_READY_TIMEOUT_MS = Number(process.env.SSR_READY_TIMEOUT_MS || 12_000);
const CACHE_DIR = process.env.CACHE_DIR || '/var/cache/prerender';
const CHROME_PATH =
  process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium-browser';

let _sitemap = { fetchedAt: 0, byId: new Map() };
let _browser = null;
let _browserPromise = null;

async function ensureCacheDir() {
  await fs.mkdir(CACHE_DIR, { recursive: true });
}

async function loadSitemap() {
  const now = Date.now();
  if (_sitemap.byId.size > 0 && now - _sitemap.fetchedAt < SITEMAP_TTL_MS) {
    return _sitemap;
  }
  const res = await fetch(`${RECIPES_API}/recipes/sitemap`, {
    headers: { accept: 'application/json' },
  });
  if (!res.ok) {
    throw new Error(`sitemap fetch ${res.status}`);
  }
  const list = await res.json();
  const byId = new Map();
  for (const row of list) {
    if (row && Number.isInteger(row.id) && typeof row.updatedAt === 'string') {
      byId.set(row.id, row.updatedAt);
    }
  }
  _sitemap = { fetchedAt: now, byId };
  return _sitemap;
}

async function getBrowser() {
  if (_browser) return _browser;
  if (_browserPromise) return _browserPromise;
  _browserPromise = puppeteer
    .launch({
      executablePath: CHROME_PATH,
      headless: 'new',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--no-first-run',
        '--no-zygote',
      ],
    })
    .then((b) => {
      _browser = b;
      _browser.on('disconnected', () => {
        _browser = null;
        _browserPromise = null;
      });
      return b;
    })
    .catch((err) => {
      _browserPromise = null;
      throw err;
    });
  return _browserPromise;
}

async function renderHtml({ locale, id }) {
  const browser = await getBrowser();
  const url = buildSpaUrl({ origin: SPA_ORIGIN, locale, id });
  const page = await browser.newPage();
  try {
    await page.setUserAgent('RecipeListPrerender/1.0 (+https://recipies.mahallem.ist)');
    await page.setViewport({ width: 1200, height: 1800, deviceScaleFactor: 1 });
    await page.goto(url, {
      // domcontentloaded fires as soon as the SPA shell is parsed; we
      // then wait for the SPA-emitted ssr-ready signal (or a short
      // fallback delay if the SPA build doesn't ship that signal yet —
      // chunk F adds it). Using `networkidle2` here was unreliable
      // because Flutter web keeps issuing small fetches during canvas
      // init for ~minutes and never reaches network idle.
      waitUntil: 'domcontentloaded',
      timeout: RENDER_TIMEOUT_MS,
    });
    // Prefer the SPA-emitted readiness signal; fall back to a short
    // grace period if the SPA build doesn't ship it yet.
    try {
      await page.waitForSelector('meta[name="ssr-ready"]', {
        timeout: SSR_READY_TIMEOUT_MS,
      });
    } catch (_e) {
      // Acceptable degraded mode — give the SPA a moment to paint
      // anything it can before we snapshot.
      await new Promise((r) => setTimeout(r, 1500));
    }
    const html = await page.content();
    return scrubFlutterShell(html);
  } finally {
    await page.close().catch(() => {});
  }
}

async function readCache(file) {
  try {
    return await fs.readFile(file, 'utf8');
  } catch (err) {
    if (err.code === 'ENOENT') return null;
    throw err;
  }
}

async function writeCache(file, html) {
  // Atomic write: tmp + rename → never serve a half-written file.
  // Place the tmp file alongside the destination so rename(2) stays
  // within the same filesystem (the cache lives on a Docker volume,
  // /tmp does not — cross-device rename throws EXDEV).
  const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
  await fs.writeFile(tmp, html, 'utf8');
  await fs.rename(tmp, file);
}

export function buildApp({ overrides } = {}) {
  // Test seam: overrides may stub renderHtml / loadSitemap.
  const _renderHtml = overrides?.renderHtml || renderHtml;
  const _loadSitemap = overrides?.loadSitemap || loadSitemap;
  const _cacheDir = overrides?.cacheDir || CACHE_DIR;

  const app = express();
  app.disable('x-powered-by');

  app.get('/healthz', (_req, res) => {
    res.set('Cache-Control', 'no-store');
    res.json({ status: 'ok', locales: SUPPORTED_LOCALES });
  });

  app.get(/^.*$/, async (req, res) => {
    const parsed = parseRecipePath(req.path);
    if (!parsed) {
      // Anything that's not a canonical recipe URL: degrade to upstream
      // (nginx will only proxy us /<locale>/recipes/<id> anyway, this
      // is just a defensive guard for direct hits).
      res.status(404).type('text/plain').send('not a recipe path');
      return;
    }
    const { locale, id } = parsed;
    try {
      const sitemap = await _loadSitemap();
      const updatedAt = sitemap.byId.get(id);
      if (!updatedAt) {
        res.status(404).type('text/plain').send('recipe not found');
        return;
      }
      const key = cacheKey({ locale, id, updatedAt });
      const file = path.join(_cacheDir, cacheFileName(key));
      let html = await readCache(file);
      let cacheHit = true;
      if (html === null) {
        cacheHit = false;
        html = await _renderHtml({ locale, id });
        await writeCache(file, html);
      }
      res.set('Cache-Control', 'public, max-age=300');
      res.set('X-Prerender-Cache', cacheHit ? 'hit' : 'miss');
      res.set('Content-Type', 'text/html; charset=utf-8');
      res.send(html);
    } catch (err) {
      console.error(`prerender ${req.path}: ${err.message}`);
      res.status(502).type('text/plain').send('prerender unavailable');
    }
  });

  return app;
}

export async function start() {
  await ensureCacheDir();
  const app = buildApp();
  return new Promise((resolve) => {
    const server = app.listen(PORT, () => {
      console.log(`prerender listening on :${PORT} (origin=${SPA_ORIGIN})`);
      resolve(server);
    });
  });
}

// Entry-point guard so tests can `import { buildApp }` without booting
// the server.
const isMain =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith('/server.js');
if (isMain) {
  start().catch((err) => {
    console.error('prerender failed to start:', err);
    process.exit(1);
  });
}
