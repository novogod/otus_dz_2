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
