// Pre-render service for recipies.mahallem.ist (todo/20 chunk E).
//
// Pure helper module exporting:
//   * SUPPORTED_LOCALES — alphabetical list of the 10 SPA locales.
//   * cacheKey({ locale, id, updatedAt })
//       → "<locale>:<id>:<updatedAt>" used as the file-cache key.
//   * cacheFileName(key)
//       → `<sha1(key)>.html` — a flat, fs-safe filename.
//   * scrubFlutterShell(html)
//       → strips <script src=".../flutter_bootstrap.js"> and the
//         empty <flt-*> shell that Chromium leaves in document.documentElement
//         after the SPA finishes rendering. The static <head> SEO
//         landmarks (title, og, canonical, JSON-LD) survive untouched.
//   * isSupportedLocale(s) / parseRecipePath(pathname)
//       → matches the canonical `/<locale>/recipes/<id>` pattern.
//
// Kept side-effect-free so unit tests run without spinning up Chromium.
import crypto from 'node:crypto';

export const SUPPORTED_LOCALES = Object.freeze([
  'ar', 'de', 'en', 'es', 'fa', 'fr', 'it', 'ku', 'ru', 'tr',
]);

const RECIPE_PATH_RE = new RegExp(
  `^/(${SUPPORTED_LOCALES.join('|')})/recipes/(\\d+)/?$`,
);

export function isSupportedLocale(value) {
  return typeof value === 'string' && SUPPORTED_LOCALES.includes(value);
}

export function parseRecipePath(pathname) {
  if (typeof pathname !== 'string') return null;
  const match = RECIPE_PATH_RE.exec(pathname);
  if (!match) return null;
  const id = Number(match[2]);
  if (!Number.isFinite(id) || id <= 0) return null;
  return { locale: match[1], id };
}

export function cacheKey({ locale, id, updatedAt }) {
  if (!isSupportedLocale(locale)) {
    throw new Error(`unsupported locale: ${locale}`);
  }
  if (!Number.isInteger(id) || id <= 0) {
    throw new Error(`invalid recipe id: ${id}`);
  }
  if (!updatedAt || typeof updatedAt !== 'string') {
    throw new Error('updatedAt is required');
  }
  return `${locale}:${id}:${updatedAt}`;
}

export function cacheFileName(key) {
  if (typeof key !== 'string' || key.length === 0) {
    throw new Error('cache key required');
  }
  // Flat, deterministic, fs-safe — sha1 is fine here, this is not a
  // security boundary.
  const digest = crypto.createHash('sha1').update(key).digest('hex');
  return `${digest}.html`;
}

// Strip Flutter scaffolding from the rendered HTML so what we serve to
// bots is a static document, not a SPA shell that they'd try to execute.
//
// Removes:
//   * any <script src="…flutter_bootstrap.js…">
//   * any <script src="…flutter.js…">
//   * any <script src="…main.dart.js…">
//   * <flutter-view> and <flt-*> elements (the empty shell Flutter
//     leaves once the canvas is initialised).
//
// We do this with regex rather than DOM parsing on purpose: the input is
// a fully-rendered Chromium snapshot, so the structure is well-formed,
// and pulling in jsdom for a one-shot scrub is overkill. Tests pin the
// exact patterns we care about.
export function scrubFlutterShell(html) {
  if (typeof html !== 'string') return '';
  let out = html;
  // <script ... src="…flutter*.js…" …></script>  (any quoting).
  out = out.replace(
    /<script\b[^>]*\bsrc\s*=\s*["'][^"']*(?:flutter_bootstrap|flutter\.js|main\.dart\.js|flutter_service_worker\.js)[^"']*["'][^>]*>\s*<\/script>/gi,
    '',
  );
  // Inline <script>… that defines _flutter / FlutterLoader.
  out = out.replace(
    /<script\b[^>]*>(?:[\s\S]*?_flutter[\s\S]*?|[\s\S]*?FlutterLoader[\s\S]*?)<\/script>/gi,
    '',
  );
  // <flutter-view>…</flutter-view> shells.
  out = out.replace(/<flutter-view\b[^>]*>[\s\S]*?<\/flutter-view>/gi, '');
  // Stray <flt-*> custom elements (canvas / glass-pane / scene-host).
  out = out.replace(/<flt-[a-z-]+\b[^>]*>[\s\S]*?<\/flt-[a-z-]+>/gi, '');
  out = out.replace(/<flt-[a-z-]+\b[^>]*\/?>/gi, '');
  return out;
}

// Build the `?ssr=1` URL the headless browser should hit for a given
// (locale, id) pair. Caller passes the SPA origin (e.g.
// `http://recipe_list_web` inside the docker network).
export function buildSpaUrl({ origin, locale, id }) {
  if (!origin) throw new Error('origin required');
  if (!isSupportedLocale(locale)) {
    throw new Error(`unsupported locale: ${locale}`);
  }
  if (!Number.isInteger(id) || id <= 0) {
    throw new Error(`invalid recipe id: ${id}`);
  }
  // `?ssr=1` flag tells the SPA to emit <meta name="ssr-ready"> once
  // the recipe data is rendered (see recipe_list/web/index.html and
  // recipe_details_page.dart). Without the flag the SPA still works,
  // but the prerender falls back to networkidle + a short delay.
  const u = new URL(origin);
  u.pathname = `/${locale}/recipes/${id}`;
  u.searchParams.set('ssr', '1');
  return u.toString();
}

// ─── todo/20 chunk F: server-side per-recipe SEO injection ─────────
//
// Originally chunk F drove head injection from the SPA (Dart calling
// `window.setRecipeSeo` from RecipeDetailsPage). That worked for human
// visitors but turned out to be unreliable inside headless Chromium
// running in our prerender container — Flutter web could fail to fetch
// the recipe (CORS, DNS, slow paint past the 12s `ssr-ready` timeout)
// and bots ended up snapshotting the SPA shell with the static
// `<title>Otus Food</title>`.
//
// To make the bot surface deterministic, we now build the canonical
// head atoms server-side from the recipe payload we fetch from the
// user-portal API and rewrite the captured HTML's `<head>` before
// shipping the snapshot to the bot. The SPA-side helper still runs
// for human visitors who land on `/<lang>/recipes/<id>` directly,
// which keeps the share-link unfurl correct.

const PUBLIC_HOST = 'https://recipies.mahallem.ist';

// HTML-escape for attribute / text contexts. We only emit a small,
// well-known set of tags so a single escaper is enough.
function htmlEscape(s) {
  if (s == null) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Pulls the localized recipe out of the user-portal `/lookup/:id`
// payload. The API returns themealdb-shaped `{meals: [{...}]}`; we
// derive title, image, ingredients, instructions, category, area.
//
// Pure / synchronous so unit tests don't need a server.
export function recipeFromLookup(json, { locale } = {}) {
  if (!json || typeof json !== 'object') return null;
  const meals = Array.isArray(json.meals) ? json.meals : null;
  if (!meals || meals.length === 0) return null;
  const m = meals[0];
  if (!m || typeof m !== 'object') return null;
  const idStr = m.idMeal != null ? String(m.idMeal) : null;
  const id = idStr ? Number(idStr) : null;
  if (!Number.isFinite(id) || id <= 0) return null;
  const title = (m.strMeal || '').toString().trim();
  if (!title) return null;
  const image = (m.strMealThumb || '').toString().trim() || null;
  const category = (m.strCategory || '').toString().trim() || null;
  const area = (m.strArea || '').toString().trim() || null;
  const ingredients = [];
  for (let i = 1; i <= 20; i += 1) {
    const name = (m[`strIngredient${i}`] || '').toString().trim();
    const measure = (m[`strMeasure${i}`] || '').toString().trim();
    if (!name) continue;
    ingredients.push(measure ? `${measure} ${name}`.trim() : name);
  }
  const instructionsRaw = (m.strInstructions || '').toString();
  const instructions = instructionsRaw
    .split(/\r?\n+/)
    .map((s) => s.trim())
    .filter(Boolean);
  return {
    id,
    locale: isSupportedLocale(locale) ? locale : 'en',
    title,
    image,
    category,
    area,
    ingredients,
    instructions,
  };
}

// Builds the canonical per-recipe head fragment: <title>, description,
// canonical, hreflang ring (10 + x-default), OG, Twitter, JSON-LD
// `Recipe`. Each atom carries `data-recipe-seo="1"` so the SPA-side
// `clearRecipeSeo()` (web/index.html) recognises and removes them on
// locale switch / unmount, and so this function is idempotent against
// previously-injected snapshots.
export function buildRecipeSeoHead(recipe) {
  if (!recipe || typeof recipe !== 'object') return '';
  const id = recipe.id;
  if (!Number.isInteger(id) || id <= 0) return '';
  const locale = isSupportedLocale(recipe.locale) ? recipe.locale : 'en';
  const title = (recipe.title || '').toString().trim() || 'Otus Food';
  const desc = (
    Array.isArray(recipe.instructions) && recipe.instructions.length > 0
      ? recipe.instructions[0]
      : ''
  )
    .toString()
    .slice(0, 320)
    .trim();
  const image = (recipe.image || `${PUBLIC_HOST}/og-image.jpg`).toString();
  const canonical = `${PUBLIC_HOST}/${locale}/recipes/${id}`;
  const lines = [];
  const e = htmlEscape;
  lines.push(`<title data-recipe-seo="1">${e(title)} — Otus Food</title>`);
  if (desc) {
    lines.push(`<meta data-recipe-seo="1" name="description" content="${e(desc)}">`);
  }
  lines.push(`<link data-recipe-seo="1" rel="canonical" href="${canonical}">`);
  for (const lng of SUPPORTED_LOCALES) {
    lines.push(
      `<link data-recipe-seo="1" rel="alternate" hreflang="${lng}" href="${PUBLIC_HOST}/${lng}/recipes/${id}">`,
    );
  }
  lines.push(
    `<link data-recipe-seo="1" rel="alternate" hreflang="x-default" href="${PUBLIC_HOST}/en/recipes/${id}">`,
  );
  lines.push(`<meta data-recipe-seo="1" property="og:type" content="article">`);
  lines.push(`<meta data-recipe-seo="1" property="og:title" content="${e(title)}">`);
  if (desc) {
    lines.push(`<meta data-recipe-seo="1" property="og:description" content="${e(desc)}">`);
  }
  lines.push(`<meta data-recipe-seo="1" property="og:url" content="${canonical}">`);
  lines.push(`<meta data-recipe-seo="1" property="og:image" content="${e(image)}">`);
  lines.push(`<meta data-recipe-seo="1" property="og:locale" content="${locale}">`);
  lines.push(`<meta data-recipe-seo="1" name="twitter:card" content="summary_large_image">`);
  lines.push(`<meta data-recipe-seo="1" name="twitter:title" content="${e(title)}">`);
  if (desc) {
    lines.push(`<meta data-recipe-seo="1" name="twitter:description" content="${e(desc)}">`);
  }
  lines.push(`<meta data-recipe-seo="1" name="twitter:image" content="${e(image)}">`);
  const jsonld = {
    '@context': 'https://schema.org',
    '@type': 'Recipe',
    name: title,
    inLanguage: locale,
    url: canonical,
    image: [image],
    author: { '@type': 'Organization', name: 'Otus Food' },
  };
  if (desc) jsonld.description = desc;
  if (Array.isArray(recipe.ingredients) && recipe.ingredients.length > 0) {
    jsonld.recipeIngredient = recipe.ingredients;
  }
  if (Array.isArray(recipe.instructions) && recipe.instructions.length > 0) {
    jsonld.recipeInstructions = recipe.instructions.map((s) => ({
      '@type': 'HowToStep',
      text: s,
    }));
  }
  if (recipe.category) jsonld.recipeCategory = recipe.category;
  if (recipe.area) jsonld.recipeCuisine = recipe.area;
  // JSON.stringify already escapes </script via \u003c when the json
  // is valid — we rely on the JSON contract. No < in keys/values
  // beyond what stringify handles.
  const jsonldText = JSON.stringify(jsonld).replace(/<\/script/gi, '<\\/script');
  lines.push(
    `<script data-recipe-seo="1" type="application/ld+json">${jsonldText}</script>`,
  );
  // Snapshot signal — kept for back-compat with anything that probes
  // for it. Bots have already received a complete head by the time
  // they parse this far, so the marker is informational only.
  lines.push(`<meta data-recipe-seo="1" name="ssr-ready" content="1">`);
  return lines.join('\n');
}

// Surgically replaces the SPA's static `<title>` and any pre-existing
// `data-recipe-seo="1"` atoms with our newly-built head fragment.
// Inserts the fragment immediately before `</head>` so it wins over
// the static landmarks (browsers and crawlers honour the LAST tag).
export function injectRecipeSeo(html, recipe) {
  if (typeof html !== 'string' || html.length === 0) return html;
  const fragment = buildRecipeSeoHead(recipe);
  if (!fragment) return html;
  // Drop any partial atoms the SPA-side helper may have already placed
  // (idempotency on cache regen).
  let out = html.replace(
    /<(?:meta|link|script|title)\b[^>]*\bdata-recipe-seo="1"[^>]*>(?:[\s\S]*?<\/(?:script|title)>)?/gi,
    '',
  );
  // Drop the static <title> too — we replace it with our own.
  out = out.replace(/<title\b[^>]*>[\s\S]*?<\/title>/i, '');
  // Drop the static landing-page <link rel="canonical">; otherwise the
  // bot sees two canonicals (the index.html default and our per-recipe
  // one) which is ambiguous to crawlers.
  out = out.replace(
    /<link\b(?=[^>]*\brel="canonical")(?![^>]*\bdata-recipe-seo="1")[^>]*>\s*/i,
    '',
  );
  const headClose = out.search(/<\/head>/i);
  if (headClose < 0) return out;
  return `${out.slice(0, headClose)}${fragment}\n${out.slice(headClose)}`;
}
