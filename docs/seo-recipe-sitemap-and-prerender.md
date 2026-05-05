# Recipe-level SEO: dynamic sitemap + multi-locale indexing

Status: **planned** (this doc is the design + runbook). When the
phases below are implemented, link them from
[docs/seo.md](docs/seo.md) §6 ("Future work").

Audience: search engines (Google, Bing, Yandex, DuckDuckGo) and
link-preview scrapers (Facebook, Twitter/X, Telegram, WhatsApp,
LinkedIn, Reddit, Slack, Pinterest).

Goal: make every recipe in the DB discoverable in every supported
locale, with a real preview card and a chance at rich-result
cards. Today's [recipe_list/web/sitemap.xml](recipe_list/web/sitemap.xml)
lists only `/` and `/recipes`, so Search Console reports
"Discovered pages: 2" — the static list cannot grow with the DB.

---

## 1. Scope

### 1.1 Supported locales

10 locales, all sourced from
[recipe_list/lib/i18n/](recipe_list/lib/i18n/):

| Code | Language | Notes |
|------|----------|-------|
| `en` | English | default / canonical content |
| `ru` | Russian | |
| `de` | German | |
| `es` | Spanish | |
| `fr` | French | |
| `it` | Italian | |
| `tr` | Turkish | |
| `ar` | Arabic | RTL |
| `fa` | Persian | RTL |
| `ku` | Kurdish | LTR (Kurmanji) |

The backend stores per-locale title/description/instructions; the
nightly translation cron fills gaps (see
[docs/themealdb-ingest-cron-and-translate-gap.md](docs/themealdb-ingest-cron-and-translate-gap.md)
and [docs/translation-pipeline.md](docs/translation-pipeline.md)).
Therefore each `recipe_id` × `locale` pair is a real, distinct
piece of indexable content.

### 1.2 Distinct from `mahallem.ist`

This is the recipes app on `recipies.mahallem.ist` only. The
parent portal at `mahallem.ist` is a separate SEO surface with
its own sitemap and Search Console scope — see
[docs/seo.md](docs/seo.md) §2.

---

## 2. Two-phase plan

| Phase | What | Effort | Effect |
|-------|------|--------|--------|
| **1** | Dynamic per-recipe sitemap with `hreflang` | small | Search Console "Discovered pages" jumps from 2 → N×L (recipes × locales). Crawled, but most pages will be flagged "Crawled — currently not indexed" because the SPA shell is identical for every id. |
| **2** | Bot-only pre-render with locale-aware HTML + JSON-LD `Recipe` schema | medium | Each recipe becomes a real indexed page per locale, with rich-result eligibility (recipe cards in Google), per-recipe Open Graph for proper FB/X/WhatsApp previews. |

Phase 1 is mandatory for Phase 2 to be useful, and it surfaces
the URLs to crawlers so they're queued for indexing the moment
Phase 2 ships.

---

## 3. Phase 1 — dynamic sitemap

### 3.1 URL strategy

Decision: **locale-prefixed URLs** for sitemap entries (and
eventually for the SPA's `go_router`). Without locale-prefixed
URLs, `hreflang` annotations are meaningless because every
locale resolves to the exact same URL. Search Console flags this
as a duplicate-content / hreflang-loop issue.

Proposed canonical paths:

```
https://recipies.mahallem.ist/<locale>/recipes/<id>
e.g.
https://recipies.mahallem.ist/en/recipes/52772
https://recipies.mahallem.ist/ru/recipes/52772
https://recipies.mahallem.ist/ar/recipes/52772
```

Backwards compatibility: keep the existing `/recipes/details/:id`
route as a 301 redirect to the user's current-locale prefixed
URL. The Flutter `go_router` config in
[recipe_list/lib/router/routes.dart](recipe_list/lib/router/routes.dart)
gains an optional locale segment — see Phase 2 §4.2 below.

Until the router change ships, sitemap entries can use the
existing `/recipes/details/:id` form for English and **omit**
hreflang alternates. That's still a 40× improvement over today's
2-URL sitemap, but it leaves Google with no signal that
translations exist.

### 3.2 Sitemap structure (with hreflang)

One `<url>` per recipe id with one `<xhtml:link rel="alternate">`
per locale. For 10 locales that's `1 + 10 = 11` lines per
recipe. With ~500 recipes → ~5 500 URL entries → still well
under the 50 000-URL / 50 MB sitemap cap. No need to split into
a sitemap-index yet.

```xml
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">

  <url>
    <loc>https://recipies.mahallem.ist/en/recipes/52772</loc>
    <lastmod>2026-05-04</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
    <xhtml:link rel="alternate" hreflang="en"      href="https://recipies.mahallem.ist/en/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="ru"      href="https://recipies.mahallem.ist/ru/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="de"      href="https://recipies.mahallem.ist/de/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="es"      href="https://recipies.mahallem.ist/es/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="fr"      href="https://recipies.mahallem.ist/fr/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="it"      href="https://recipies.mahallem.ist/it/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="tr"      href="https://recipies.mahallem.ist/tr/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="ar"      href="https://recipies.mahallem.ist/ar/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="fa"      href="https://recipies.mahallem.ist/fa/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="ku"      href="https://recipies.mahallem.ist/ku/recipes/52772"/>
    <xhtml:link rel="alternate" hreflang="x-default" href="https://recipies.mahallem.ist/en/recipes/52772"/>
  </url>

  <!-- one block per recipe id … -->
</urlset>
```

`x-default` points at the English variant — Google serves it to
users whose browser locale doesn't match any of the 10 explicit
languages.

We list **only** the `en` URL in `<loc>` for each recipe (one
`<url>` block per id). Google uses the `<xhtml:link>` annotations
on that single block to discover all 10 locale variants without
the sitemap doubling in size to 10× the rows. This is the form
recommended in
https://developers.google.com/search/docs/specialty/international/localized-versions#sitemap.

### 3.3 Generator script

Owner: backend container (`mahallem-user-portal`, since it has DB
access already; running this in the Flutter web container would
require a public ID-list endpoint and add a network round-trip).

Pseudo-code:

```bash
#!/usr/bin/env bash
# /root/build_recipe_sitemap.sh
set -euo pipefail

OUT=/var/www/recipie/otus_dz_2/recipe_list/web/sitemap.xml
TMP=$(mktemp)
LOCALES=(en ru de es fr it tr ar fa ku)

# Pull all recipe ids + lastmod from the backend DB.
# Endpoint TBD; either:
#   - new GET /recipes/sitemap   → returns [{id, updatedAt}]
#   - existing /recipes/page paginated (id only)
ids_json=$(curl -fsSL "http://172.25.0.41:4000/recipes/sitemap")

cat >"$TMP" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <url>
    <loc>https://recipies.mahallem.ist/</loc>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
EOF

echo "$ids_json" | jq -r '.[] | "\(.id)\t\(.updatedAt)"' | while IFS=$'\t' read -r id updated; do
  cat >>"$TMP" <<EOF
  <url>
    <loc>https://recipies.mahallem.ist/en/recipes/${id}</loc>
    <lastmod>${updated:0:10}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
EOF
  for lang in "${LOCALES[@]}"; do
    echo "    <xhtml:link rel=\"alternate\" hreflang=\"${lang}\" href=\"https://recipies.mahallem.ist/${lang}/recipes/${id}\"/>" >>"$TMP"
  done
  echo "    <xhtml:link rel=\"alternate\" hreflang=\"x-default\" href=\"https://recipies.mahallem.ist/en/recipes/${id}\"/>" >>"$TMP"
  echo "  </url>" >>"$TMP"
done

echo "</urlset>" >>"$TMP"

# Atomic swap into the build/web volume mounted in the container.
docker cp "$TMP" recipe_list_web:/usr/share/nginx/html/sitemap.xml
rm -f "$TMP"

echo "[$(date -Iseconds)] sitemap.xml regenerated"
```

### 3.4 Cron schedule

Add to `/etc/cron.d/recipes-backfill` (or new
`/etc/cron.d/recipes-sitemap`) immediately after the daily
ingest+translate completes:

```
# Regenerate per-recipe sitemap nightly at 06:00 UTC,
# 30 min after the backfill cron at 05:30.
0 6 * * * root /root/build_recipe_sitemap.sh >> /var/log/recipes_sitemap.log 2>&1
```

Static fallback: keep
[recipe_list/web/sitemap.xml](recipe_list/web/sitemap.xml) in git
as the bootstrap content (current 2-URL file). The cron
overwrites it inside the running container; on container rebuild
the static file is restored, then the next 06:00 run replaces it
again.

### 3.5 Backend endpoint

Pick one:

1. **New `/recipes/sitemap`** — single shot, returns
   `[{id, updatedAt}]` with no auth, light JSON. Cheap, ideal
   for cron. **Recommended.**
2. **Existing `/recipes/page` paginated** — works today but the
   payload includes full recipe rows (heavy) and the script
   has to loop. Acceptable as a temporary measure.

The `/recipes/page` endpoint is well documented in
[docs/recipe-ingester-and-size-cap.md](docs/recipe-ingester-and-size-cap.md);
add a sibling `/recipes/sitemap` returning a slim projection.

### 3.6 Submitting to search consoles

After the first cron run:

```bash
curl -sI https://recipies.mahallem.ist/sitemap.xml | head -4
```

Should return 200 + `text/xml`. Then:

- **Google Search Console** ([docs/seo.md](docs/seo.md) §3.1) —
  the previously-submitted sitemap URL stays the same; Google
  re-fetches automatically. Watch
  **Sitemaps → Discovered pages** climb to ≈ recipe count.
- **Bing Webmaster Tools** ([docs/seo.md](docs/seo.md) §3.2) —
  same.
- **Yandex Webmaster** ([docs/seo.md](docs/seo.md) §3.3) —
  same.

Optional: ping Google + Bing on every regen for faster recrawl:

```bash
curl -fsS "https://www.google.com/ping?sitemap=https%3A%2F%2Frecipies.mahallem.ist%2Fsitemap.xml" >/dev/null || true
curl -fsS "https://www.bing.com/ping?sitemap=https%3A%2F%2Frecipies.mahallem.ist%2Fsitemap.xml" >/dev/null || true
```

(Google deprecated its ping endpoint in 2023 but still accepts;
harmless if it 404s.)

For Yandex / Bing real-time push, consider **IndexNow** (single
HTTP POST per new URL) — viable because Bing, Yandex, Seznam,
Naver all consume the same endpoint.

---

## 4. Phase 2 — bot-only pre-render

Phase 1 puts URLs on the map; Phase 2 makes them index-worthy.

### 4.1 Why pre-render

Today every URL on `recipies.mahallem.ist` returns the same
`index.html` SPA shell. Googlebot does run JavaScript on a
second-pass render, but:

- The render budget is small for large catalogs; many pages will
  be skipped or downgraded to `Crawled — currently not indexed`.
- Bing/Yandex run very limited JS; effectively never for content.
- Facebook/Twitter/X/Telegram/WhatsApp/LinkedIn/Reddit/Slack
  scrapers run **zero** JS — they only parse the static HTML.

So the OG card today shows the homepage hero image + title for
every recipe URL. We need real per-recipe HTML at the bot's first
fetch.

### 4.2 Locale-prefixed routing in Flutter

Update [recipe_list/lib/router/routes.dart](recipe_list/lib/router/routes.dart):

- Add `/:lang(en|ru|de|es|fr|it|tr|ar|fa|ku)?` as a top-level
  segment.
- New constants:
  ```dart
  static const String localePathPattern = r'(en|ru|de|es|fr|it|tr|ar|fa|ku)';
  static String localizedRecipe(String lang, int id) =>
      '/$lang/recipes/$id';
  ```
- The router defaults the `lang` param to the user's current
  locale on push and rewrites the URL via `context.go(...)`
  whenever the locale changes (so deep-links and shares are
  always locale-correct).
- Old URLs (`/recipes/details/:id`) become a redirect:
  `redirect: (ctx, state) => '/$currentLocale/recipes/$id'`.

### 4.3 Pre-render service

Stack: a tiny Node service running headless Chromium
(Puppeteer / Playwright). One container per host.

Behaviour:

1. Receives `GET /<locale>/recipes/<id>`.
2. Computes a cache key `${locale}:${id}:${recipe.updatedAt}`.
3. If the cache file exists, returns the static HTML.
4. Otherwise launches a headless Chromium pointed at
   `https://recipies.mahallem.ist/<locale>/recipes/<id>?ssr=1`
   (the `ssr=1` flag tells the SPA to skip animations and emit
   `<meta name="ssr-ready">` once the recipe data is rendered).
5. Waits for `ssr-ready`, captures `document.documentElement.outerHTML`.
6. Strips Flutter `<script>` tags and the `<flt-*>` shell, keeps
   the SEO landmarks injected by the SPA: `<title>`, OG tags,
   canonical, JSON-LD `Recipe`, the prose body.
7. Writes the cache file and returns it.

Cache lives in a Docker volume; invalidated whenever the recipe's
`updatedAt` changes. The nightly translate cron triggers a cache
sweep so newly-translated locales appear within 24 h.

### 4.4 Nginx user-agent split

Add to
[/etc/nginx/sites-available/recipies.mahallem.ist](https://72.61.181.62)
(host vhost):

```nginx
map $http_user_agent $is_bot {
    default 0;
    ~*googlebot                   1;
    ~*bingbot                     1;
    ~*yandex                      1;
    ~*duckduckbot                 1;
    ~*baiduspider                 1;
    ~*facebookexternalhit         1;
    ~*facebookcatalog             1;
    ~*facebot                     1;
    ~*twitterbot                  1;
    ~*linkedinbot                 1;
    ~*whatsapp                    1;
    ~*telegrambot                 1;
    ~*slackbot                    1;
    ~*discordbot                  1;
    ~*pinterestbot                1;
    ~*redditbot                   1;
    ~*applebot                    1;
}

server {
    server_name recipies.mahallem.ist;
    # … existing TLS / gzip blocks …

    location ~ ^/(en|ru|de|es|fr|it|tr|ar|fa|ku)/recipes/[0-9]+/?$ {
        if ($is_bot) {
            proxy_pass http://127.0.0.1:8089;   # pre-render service
            break;
        }
        proxy_pass http://127.0.0.1:8088;       # Flutter SPA (humans)
    }

    location / {
        proxy_pass http://127.0.0.1:8088;
    }
}
```

UA-cloaking is **explicitly allowed** by Google's guidelines for
"dynamic rendering" as long as the pre-rendered HTML is a
faithful representation of the JS-rendered page. See
https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering.

### 4.5 Per-recipe metadata in pre-rendered HTML

For each `(recipe_id, locale)` the pre-renderer must emit:

- `<title>` = `${recipe.title[locale]} — Otus Food`
- `<meta name="description" content="${recipe.summary[locale]}">`
- `<link rel="canonical" href="https://recipies.mahallem.ist/<locale>/recipes/<id>">`
- 9 × `<link rel="alternate" hreflang="<lang>" href="…">` + `x-default`
- Open Graph:
  - `og:title`, `og:description`, `og:url` localised
  - `og:image` = the recipe's hero image (already stored in DB)
  - `og:locale` matches `<locale>`, `og:locale:alternate` for the other 9
- Twitter Card: `summary_large_image` with the same image
- JSON-LD `Recipe` schema:
  ```json
  {
    "@context": "https://schema.org",
    "@type": "Recipe",
    "name": "<localised title>",
    "image": ["<hero image URL>"],
    "description": "<localised summary>",
    "inLanguage": "<locale>",
    "recipeIngredient": ["...", "..."],
    "recipeInstructions": [
      { "@type": "HowToStep", "text": "step 1 …" },
      …
    ],
    "recipeCategory": "<category>",
    "recipeCuisine": "<cuisine>",
    "totalTime": "PT45M",
    "datePublished": "2026-05-04",
    "author": { "@type": "Organization", "name": "Otus Food" }
  }
  ```

JSON-LD `Recipe` is what unlocks the **Google "rich result"
recipe card** in search and **Pinterest Rich Pins**. Validate at
https://search.google.com/test/rich-results before going live.

### 4.6 Per-recipe OG previews

After Phase 2, sharing
`https://recipies.mahallem.ist/en/recipes/52772` to Facebook /
Telegram / WhatsApp will show the recipe's own image and title
instead of the global homepage card. This fixes the long-standing
"all shares look the same" complaint without changing the
client-side share button (already documented in
[docs/share-pwa-and-backfill.md](docs/share-pwa-and-backfill.md)).

### 4.7 Validation checklist

After Phase 2 deploy:

```bash
# pre-render returns real HTML to bot UA
curl -sA "Googlebot/2.1" https://recipies.mahallem.ist/en/recipes/52772 | grep -E '<title>|application/ld\+json|hreflang'

# humans still get the SPA shell
curl -s https://recipies.mahallem.ist/en/recipes/52772 | grep -c flutter_bootstrap.js   # should be 1

# rich-result eligibility
open "https://search.google.com/test/rich-results?url=https%3A%2F%2Frecipies.mahallem.ist%2Fen%2Frecipes%2F52772"
```

---

## 5. Multi-locale SEO traps to avoid

1. **Don't** emit `hreflang` annotations pointing at the same
   URL for every locale. Search Console flags "alternate page
   with proper canonical tag" warnings. Locale-prefixed paths
   (Phase 2) are the only correct fix.
2. **Don't** use `Accept-Language`-based redirects on the
   canonical recipe URLs — Googlebot crawls from US datacenters
   and would only ever see English. Use **explicit URL
   prefixes**, let users pick locale from the UI.
3. **Don't** translate `og:url` or `<link rel="canonical">` —
   they must point at the same locale-prefixed URL the bot
   fetched.
4. **Do** include `og:locale` matching the page locale and
   9 × `og:locale:alternate` for the others. Facebook uses these
   to render the right preview in the user's locale.
5. **Do** set `<html lang="<locale>" dir="rtl|ltr">` in
   pre-rendered HTML for `ar` / `fa` so Google's snippet uses the
   correct script direction.
6. **Do** keep one canonical translation per locale. If the
   nightly translate cron hasn't filled `<locale>` yet,
   pre-render falls back to English and emits
   `<link rel="canonical" href=".../en/...">` — this prevents
   duplicate-content penalties.

---

## 6. Rollout order

1. **Now**: Phase 1.1 — backend endpoint
   `GET /recipes/sitemap` returning `[{id, updatedAt}]`. Owner:
   backend.
2. **Now**: Phase 1.2 — `/root/build_recipe_sitemap.sh` + cron at
   06:00 UTC. Owner: ops.
3. **Now**: Phase 1.3 — submit the freshly-populated
   `sitemap.xml` URL is unchanged in Search Console / Bing /
   Yandex; expect "Discovered" count to climb within 24–72 h.
4. **Next sprint**: Phase 2 — locale-prefixed router + 301s for
   old paths. Ship the SPA changes first; nothing user-visible
   breaks.
5. **Next sprint**: Phase 2 — pre-render service container +
   nginx UA split + per-recipe JSON-LD `Recipe` schema. Validate
   in the rich-results test.
6. **After Phase 2 ships**: regenerate sitemap with
   locale-prefixed `<loc>` + `<xhtml:link hreflang>` (script
   already designed for it).
7. **Optional**: IndexNow integration for instant Bing/Yandex
   recrawl on new recipes; per-recipe Pinterest Rich Pins
   activation.

---

## 7. References

- [docs/seo.md](docs/seo.md) — base SEO setup (this app), search-engine registration steps.
- [docs/share-pwa-and-backfill.md](docs/share-pwa-and-backfill.md) — share-button, OG image, FB scraper notes.
- [docs/recipe-ingester-and-size-cap.md](docs/recipe-ingester-and-size-cap.md) — daily ingest cron (good cron-ordering precedent).
- [docs/translation-pipeline.md](docs/translation-pipeline.md) — how locales get filled per recipe.
- [docs/themealdb-ingest-cron-and-translate-gap.md](docs/themealdb-ingest-cron-and-translate-gap.md) — translate-gap behaviour.
- Google: https://developers.google.com/search/docs/specialty/international/localized-versions
- Google: https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering
- Schema.org: https://schema.org/Recipe
- IndexNow: https://www.indexnow.org/
