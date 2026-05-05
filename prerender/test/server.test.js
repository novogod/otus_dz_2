// Unit + integration tests for the pre-render service (todo/20 chunk E).
// Pure render-utils tests run without Chromium. The HTTP test stubs
// renderHtml/loadSitemap so it doesn't need a real browser either.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import {
  SUPPORTED_LOCALES,
  isSupportedLocale,
  parseRecipePath,
  cacheKey,
  cacheFileName,
  scrubFlutterShell,
  buildSpaUrl,
} from '../lib/render-utils.js';
import { buildApp } from '../server.js';

test('SUPPORTED_LOCALES is alphabetical and exactly 10', () => {
  const sorted = [...SUPPORTED_LOCALES].sort();
  assert.deepEqual(SUPPORTED_LOCALES, sorted);
  assert.equal(SUPPORTED_LOCALES.length, 10);
});

test('isSupportedLocale accepts the SPA locales and rejects others', () => {
  assert.equal(isSupportedLocale('en'), true);
  assert.equal(isSupportedLocale('ku'), true);
  assert.equal(isSupportedLocale('zz'), false);
  assert.equal(isSupportedLocale(''), false);
  assert.equal(isSupportedLocale(null), false);
  assert.equal(isSupportedLocale(undefined), false);
});

test('parseRecipePath matches /<locale>/recipes/<id> with optional trailing slash', () => {
  assert.deepEqual(parseRecipePath('/en/recipes/52772'), { locale: 'en', id: 52772 });
  assert.deepEqual(parseRecipePath('/ku/recipes/1000011/'), { locale: 'ku', id: 1000011 });
  assert.equal(parseRecipePath('/zz/recipes/1'), null);
  assert.equal(parseRecipePath('/en/recipes/'), null);
  assert.equal(parseRecipePath('/en/recipes/abc'), null);
  assert.equal(parseRecipePath('/recipes/details/52772'), null);
});

test('cacheKey changes when updatedAt changes (cache-bust contract)', () => {
  const a = cacheKey({ locale: 'en', id: 52772, updatedAt: '2026-04-28T19:16:41.858Z' });
  const b = cacheKey({ locale: 'en', id: 52772, updatedAt: '2026-04-29T00:00:00.000Z' });
  assert.notEqual(a, b);
});

test('cacheKey changes when locale or id changes', () => {
  const base = cacheKey({ locale: 'en', id: 52772, updatedAt: 't' });
  assert.notEqual(base, cacheKey({ locale: 'ru', id: 52772, updatedAt: 't' }));
  assert.notEqual(base, cacheKey({ locale: 'en', id: 52773, updatedAt: 't' }));
});

test('cacheKey rejects invalid input', () => {
  assert.throws(() => cacheKey({ locale: 'zz', id: 1, updatedAt: 't' }));
  assert.throws(() => cacheKey({ locale: 'en', id: 0, updatedAt: 't' }));
  assert.throws(() => cacheKey({ locale: 'en', id: 1, updatedAt: '' }));
});

test('cacheFileName is deterministic and ends with .html', () => {
  const fn = cacheFileName('en:52772:2026-01-01T00:00:00.000Z');
  assert.match(fn, /^[0-9a-f]{40}\.html$/);
  assert.equal(
    cacheFileName('en:52772:2026-01-01T00:00:00.000Z'),
    cacheFileName('en:52772:2026-01-01T00:00:00.000Z'),
  );
});

test('scrubFlutterShell removes flutter_bootstrap.js, flutter.js, main.dart.js', () => {
  const input = `
<!doctype html><html><head><title>x</title></head>
<body>
<p>kept</p>
<script src="/flutter_bootstrap.js" async></script>
<script src="https://cdn/flutter.js"></script>
<script src='/main.dart.js'></script>
<script src="/flutter_service_worker.js"></script>
</body></html>`;
  const out = scrubFlutterShell(input);
  assert.equal(out.includes('flutter_bootstrap'), false);
  assert.equal(out.includes('main.dart.js'), false);
  assert.equal(out.includes('flutter_service_worker'), false);
  assert.equal(out.includes('cdn/flutter.js'), false);
  assert.equal(out.includes('<p>kept</p>'), true);
});

test('scrubFlutterShell removes inline FlutterLoader scripts and <flt-*> shells', () => {
  const input = `
<head></head>
<body>
<flutter-view><flt-glass-pane></flt-glass-pane></flutter-view>
<flt-scene-host id="x"></flt-scene-host>
<script>
  if (window._flutter) { _flutter.loader.load(); }
</script>
<script>
  let l = new FlutterLoader();
</script>
<p>kept</p>
</body>`;
  const out = scrubFlutterShell(input);
  assert.equal(out.includes('flutter-view'), false);
  assert.equal(out.includes('flt-glass-pane'), false);
  assert.equal(out.includes('flt-scene-host'), false);
  assert.equal(out.includes('FlutterLoader'), false);
  assert.equal(out.includes('_flutter'), false);
  assert.equal(out.includes('<p>kept</p>'), true);
});

test('scrubFlutterShell preserves SEO landmarks (title, og, canonical, JSON-LD)', () => {
  const input = `
<!doctype html><html><head>
<title>Pasta — Otus Food</title>
<link rel="canonical" href="https://recipies.mahallem.ist/en/recipes/52772">
<meta property="og:title" content="Pasta">
<script type="application/ld+json">{"@type":"Recipe","name":"Pasta"}</script>
</head><body>
<script src="/flutter_bootstrap.js"></script>
<p>body</p>
</body></html>`;
  const out = scrubFlutterShell(input);
  assert.match(out, /<title>Pasta — Otus Food<\/title>/);
  assert.match(out, /rel="canonical"/);
  assert.match(out, /og:title/);
  assert.match(out, /application\/ld\+json/);
  assert.equal(out.includes('flutter_bootstrap'), false);
});

test('buildSpaUrl produces the canonical /<locale>/recipes/<id>?ssr=1 URL', () => {
  const url = buildSpaUrl({
    origin: 'http://recipe_list_web',
    locale: 'en',
    id: 52772,
  });
  assert.equal(url, 'http://recipe_list_web/en/recipes/52772?ssr=1');
});

// ---------------------------------------------------------------------------
// HTTP integration tests with stubbed renderer & sitemap (no Chromium).
// ---------------------------------------------------------------------------

async function withServer({ overrides }, fn) {
  const app = buildApp({ overrides });
  const server = http.createServer(app);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const { port } = server.address();
  try {
    await fn(`http://127.0.0.1:${port}`);
  } finally {
    server.close();
  }
}

test('GET /healthz returns ok', async () => {
  await withServer({ overrides: {} }, async (base) => {
    const res = await fetch(`${base}/healthz`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.status, 'ok');
  });
});

test('GET /<locale>/recipes/<id> renders, caches, and serves cache on hit', async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'prerender-test-'));
  let renderCalls = 0;
  const overrides = {
    cacheDir: tmp,
    loadSitemap: async () => ({
      fetchedAt: Date.now(),
      byId: new Map([[52772, '2026-04-28T19:16:41.858Z']]),
    }),
    renderHtml: async ({ locale, id }) => {
      renderCalls++;
      return `<!doctype html><title>${locale}/${id}</title>`;
    },
  };
  await withServer({ overrides }, async (base) => {
    const r1 = await fetch(`${base}/en/recipes/52772`);
    assert.equal(r1.status, 200);
    assert.equal(r1.headers.get('x-prerender-cache'), 'miss');
    assert.match(await r1.text(), /<title>en\/52772<\/title>/);

    const r2 = await fetch(`${base}/en/recipes/52772`);
    assert.equal(r2.status, 200);
    assert.equal(r2.headers.get('x-prerender-cache'), 'hit');
    assert.equal(renderCalls, 1, 'cache hit must NOT re-render');
  });
  await fs.rm(tmp, { recursive: true, force: true });
});

test('GET unknown recipe id → 404', async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'prerender-test-'));
  await withServer(
    {
      overrides: {
        cacheDir: tmp,
        loadSitemap: async () => ({ fetchedAt: 0, byId: new Map() }),
        renderHtml: async () => '<should-not-render/>',
      },
    },
    async (base) => {
      const r = await fetch(`${base}/en/recipes/9999999`);
      assert.equal(r.status, 404);
    },
  );
  await fs.rm(tmp, { recursive: true, force: true });
});

test('GET /<locale>/recipes/<id> with newer updatedAt re-renders (cache-bust)', async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'prerender-test-'));
  let renderCalls = 0;
  let stamp = '2026-04-28T19:16:41.858Z';
  const overrides = {
    cacheDir: tmp,
    loadSitemap: async () => ({
      fetchedAt: Date.now(),
      byId: new Map([[52772, stamp]]),
    }),
    renderHtml: async () => {
      renderCalls++;
      return `<!doctype html><title>${stamp}</title>`;
    },
  };
  await withServer({ overrides }, async (base) => {
    await fetch(`${base}/en/recipes/52772`);
    stamp = '2026-05-01T00:00:00.000Z';
    const r = await fetch(`${base}/en/recipes/52772`);
    assert.equal(r.headers.get('x-prerender-cache'), 'miss');
    assert.match(await r.text(), /2026-05-01/);
    assert.equal(renderCalls, 2, 'updatedAt change must invalidate the cache');
  });
  await fs.rm(tmp, { recursive: true, force: true });
});

test('GET non-recipe path → 404 (defensive; nginx already filters)', async () => {
  await withServer({ overrides: {} }, async (base) => {
    const r = await fetch(`${base}/some/other/path`);
    assert.equal(r.status, 404);
  });
});

test('renderHtml failure → 502, no cache file written', async () => {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'prerender-test-'));
  const overrides = {
    cacheDir: tmp,
    loadSitemap: async () => ({
      fetchedAt: Date.now(),
      byId: new Map([[52772, 't']]),
    }),
    renderHtml: async () => {
      throw new Error('chromium crash');
    },
  };
  await withServer({ overrides }, async (base) => {
    const r = await fetch(`${base}/en/recipes/52772`);
    assert.equal(r.status, 502);
    const files = await fs.readdir(tmp);
    assert.equal(files.length, 0);
  });
  await fs.rm(tmp, { recursive: true, force: true });
});
