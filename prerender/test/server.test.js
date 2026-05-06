// Unit + integration tests for the pre-render service (todo/20 chunk E).
// Pure render-utils tests run without Chromium. The HTTP test stubs
// renderHtml/loadSitemap so it doesn't need a real browser either.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
    SUPPORTED_LOCALES,
    buildRecipeSeoHead,
    buildSpaUrl,
    cacheFileName,
    cacheKey,
    injectRecipeSeo,
    isSupportedLocale,
    parseRecipePath,
    recipeFromLookup,
    scrubFlutterShell,
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

test('scrubFlutterShell does not eat <head> when comments mention <flutter-view>', () => {
  // Regression: recipe_list/web/index.html documents the standalone
  // safe-area shim with a comment that contains the literal text
  // `<flutter-view>` and `<flt-glass-pane>`. Before the comment-strip
  // pass, the non-greedy `<flutter-view> … </flutter-view>` regex
  // anchored on that comment and ate the entire <head> (og atoms,
  // canonical, JSON-LD) up to the real Flutter shell — Telegram
  // unfurled a blank card for every recipe URL.
  const input = `<!doctype html><html><head>
<!-- Push the <flutter-view> + <flt-glass-pane> down by inset-top. -->
<title>Pasta — Otus Food</title>
<meta property="og:title" content="Pasta">
<meta property="og:image" content="https://x/og.jpg">
</head><body>
<flutter-view><flt-glass-pane></flt-glass-pane></flutter-view>
<p>body</p>
</body></html>`;
  const out = scrubFlutterShell(input);
  assert.match(out, /<title>Pasta — Otus Food<\/title>/);
  assert.match(out, /og:title/);
  assert.match(out, /og:image/);
  assert.equal(out.includes('flutter-view'), false);
  assert.equal(out.includes('flt-glass-pane'), false);
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

// ─── todo/20 chunk F: server-side per-recipe SEO injection ───────

test('recipeFromLookup parses themealdb-shaped lookup payload', () => {
  const json = {
    meals: [{
      idMeal: '52772',
      strMeal: 'Teriyaki Chicken Casserole',
      strMealThumb: 'https://example.com/img.jpg',
      strCategory: 'Chicken',
      strArea: 'Japanese',
      strInstructions: 'Step one.\nStep two.\n',
      strIngredient1: 'soy sauce',
      strMeasure1: '3/4 cup',
      strIngredient2: 'sugar',
      strMeasure2: '',
      strIngredient3: '',
      strMeasure3: '1/2 tsp',
    }],
  };
  const r = recipeFromLookup(json, { locale: 'en' });
  assert.equal(r.id, 52772);
  assert.equal(r.locale, 'en');
  assert.equal(r.title, 'Teriyaki Chicken Casserole');
  assert.equal(r.image, 'https://example.com/img.jpg');
  assert.equal(r.category, 'Chicken');
  assert.equal(r.area, 'Japanese');
  assert.deepEqual(r.ingredients, ['3/4 cup soy sauce', 'sugar']);
  assert.deepEqual(r.instructions, ['Step one.', 'Step two.']);
});

test('recipeFromLookup returns null on empty / invalid payloads', () => {
  assert.equal(recipeFromLookup(null), null);
  assert.equal(recipeFromLookup({ meals: [] }), null);
  assert.equal(recipeFromLookup({ meals: [{ idMeal: '0' }] }), null);
  assert.equal(recipeFromLookup({ meals: [{ idMeal: '7', strMeal: '' }] }), null);
});

test('recipeFromLookup falls back to en for unsupported locale', () => {
  const r = recipeFromLookup(
    { meals: [{ idMeal: '1', strMeal: 'X' }] },
    { locale: 'zz' },
  );
  assert.equal(r.locale, 'en');
});

test('buildRecipeSeoHead emits title, hreflang ring and JSON-LD', () => {
  const head = buildRecipeSeoHead({
    id: 52772,
    locale: 'ru',
    title: 'Курица',
    image: 'https://example.com/i.jpg',
    category: 'Chicken',
    area: 'Japanese',
    ingredients: ['100г соевого соуса'],
    instructions: ['Смешать.', 'Запечь.'],
  });
  // <title>
  assert.match(head, /<title data-recipe-seo="1">Курица — Otus Food<\/title>/);
  // canonical
  assert.match(head, /<link[^>]+rel="canonical"[^>]+href="https:\/\/recipies\.mahallem\.ist\/ru\/recipes\/52772"/);
  // 10 hreflangs + x-default
  const hreflangs = head.match(/<link[^>]+hreflang="[a-z-]+"/g) || [];
  assert.equal(hreflangs.length, 11);
  assert.ok(head.includes('hreflang="x-default"'));
  // JSON-LD Recipe
  assert.match(head, /<script[^>]+application\/ld\+json[^>]*>/);
  assert.match(head, /"@type":"Recipe"/);
  assert.match(head, /"inLanguage":"ru"/);
  assert.match(head, /"recipeIngredient":\["100г соевого соуса"\]/);
  // ssr-ready marker
  assert.match(head, /<meta[^>]+name="ssr-ready"/);
});

test('buildRecipeSeoHead html-escapes user-supplied strings', () => {
  const head = buildRecipeSeoHead({
    id: 1,
    locale: 'en',
    title: 'A & B "<script>"',
    instructions: ['drop </script><script>alert(1)</script>'],
  });
  assert.ok(!head.includes('A & B "<script>"'));
  assert.ok(head.includes('A &amp; B &quot;&lt;script&gt;&quot;'));
  assert.ok(!/<script>alert\(1\)<\/script>/.test(head));
});

test('buildRecipeSeoHead returns "" for invalid input', () => {
  assert.equal(buildRecipeSeoHead(null), '');
  assert.equal(buildRecipeSeoHead({ id: 0, locale: 'en', title: 'X' }), '');
});

test('injectRecipeSeo replaces the static <title> and inserts before </head>', () => {
  const spaHtml =
    '<!doctype html><html><head>' +
    '<meta charset="UTF-8">' +
    '<title>Otus Food</title>' +
    '<link rel="canonical" href="https://recipies.mahallem.ist/">' +
    '</head><body>BODY</body></html>';
  const out = injectRecipeSeo(spaHtml, {
    id: 52772,
    locale: 'en',
    title: 'Pasta',
    instructions: ['Boil.'],
  });
  // Static <title>Otus Food</title> stripped:
  assert.ok(!/<title>Otus Food<\/title>/.test(out));
  // New title injected:
  assert.ok(/<title data-recipe-seo="1">Pasta — Otus Food<\/title>/.test(out));
  // Fragment lives inside <head>:
  assert.ok(out.indexOf('hreflang="x-default"') < out.indexOf('</head>'));
  // Body untouched:
  assert.ok(out.endsWith('<body>BODY</body></html>'));
});

test('injectRecipeSeo is idempotent against a previously-injected snapshot', () => {
  const base =
    '<!doctype html><html><head><meta charset="UTF-8"></head><body></body></html>';
  const recipe = { id: 1, locale: 'en', title: 'X' };
  const once = injectRecipeSeo(base, recipe);
  const twice = injectRecipeSeo(once, recipe);
  // Should still have exactly one canonical / one ssr-ready / 11 hreflangs:
  assert.equal((twice.match(/rel="canonical"/g) || []).length, 1);
  assert.equal((twice.match(/name="ssr-ready"/g) || []).length, 1);
  assert.equal((twice.match(/hreflang="[a-z-]+"/g) || []).length, 11);
});

test('injectRecipeSeo returns the input unchanged when recipe is null', () => {
  const html = '<html><head><title>X</title></head><body></body></html>';
  assert.equal(injectRecipeSeo(html, null), html);
});

test('injectRecipeSeo strips static og:* / twitter:* / description landmarks', () => {
  // Regression: the SPA's index.html ships a complete set of landing-
  // page social atoms (og:title="Otus Food — recipes from around the
  // world", og:image=og-image.jpg, twitter:card, etc.). Most OG
  // scrapers (Telegram, Facebook, X) honour the FIRST og:title they
  // encounter, so leaving the static atoms in place would unfurl the
  // landing card for every recipe URL even though our per-recipe atoms
  // were also injected before </head>.
  const spaHtml =
    '<!doctype html><html><head>' +
    '<meta charset="UTF-8">' +
    '<title>Otus Food — recipes from around the world</title>' +
    '<meta name="description" content="Static landing description.">' +
    '<meta property="og:title" content="Otus Food">' +
    '<meta property="og:description" content="Browse, search and cook.">' +
    '<meta property="og:image" content="https://recipies.mahallem.ist/og-image.jpg">' +
    '<meta property="og:image:width" content="1024">' +
    '<meta property="og:url" content="https://recipies.mahallem.ist/">' +
    '<meta name="twitter:card" content="summary_large_image">' +
    '<meta name="twitter:title" content="Otus Food">' +
    '<meta name="twitter:image" content="https://recipies.mahallem.ist/og-image.jpg">' +
    '</head><body></body></html>';
  const out = injectRecipeSeo(spaHtml, {
    id: 1000012,
    locale: 'en',
    title: 'Unloading bag',
    image: 'https://cdn.example/unloading-bag.jpg',
    instructions: ['Buy Guinness & Cheese.'],
  });
  // Static social atoms gone (no occurrence without the recipe-seo marker).
  assert.equal(
    /<meta\b(?![^>]*\bdata-recipe-seo)[^>]*\bproperty="og:[a-z_:]+"/i.test(out),
    false,
  );
  assert.equal(
    /<meta\b(?![^>]*\bdata-recipe-seo)[^>]*\bname="twitter:[a-z_:]+"/i.test(out),
    false,
  );
  assert.equal(
    /<meta\b(?![^>]*\bdata-recipe-seo)[^>]*\bname="description"/i.test(out),
    false,
  );
  // Per-recipe atoms present and carrying the recipe values.
  assert.match(out, /<meta data-recipe-seo="1" property="og:title" content="Unloading bag">/);
  assert.match(out, /content="https:\/\/cdn\.example\/unloading-bag\.jpg"/);
});
