# SEO for recipies.mahallem.ist (Otus Food)

Scope: this document covers the **recipes** web app served from
`recipies.mahallem.ist`. It is a separate SEO surface from the
parent portal `mahallem.ist` — the two share no metadata, no
sitemap, and must be **registered independently** with each search
engine and link-preview service.

The recipes app is a Flutter web SPA hosted in nginx
(`recipe_list/Dockerfile` + [recipe_list/nginx.conf](recipe_list/nginx.conf)).
All crawlable metadata lives in static files under
[recipe_list/web/](recipe_list/web/) and is shipped to
`build/web/` on every `flutter build web --release`.

---

## 1. What's implemented

### 1.1 [recipe_list/web/index.html](recipe_list/web/index.html)

Crawler-visible payload (all crawlers parse the served HTML before
running JS, except Googlebot which also runs JS):

| Block | Purpose |
|-------|---------|
| `<title>` + `<meta name="description">` | Google SERP snippet, browser tab title |
| `<meta name="robots">` / `googlebot` | Allow indexing, allow large image previews |
| `<meta name="keywords">` | Mostly ignored by Google, used by Yandex/Baidu |
| `<meta name="theme-color">` `#2ECC71` | Mobile browser chrome colour, brand green |
| `<link rel="canonical">` | Single source-of-truth URL — prevents duplicate-content penalties |
| `<link rel="sitemap">` | Hint for crawlers that prefer in-page discovery |
| `og:*` (Open Graph) | Facebook / WhatsApp / Telegram / LinkedIn / VK / Slack link previews |
| `og:locale` + `og:locale:alternate` × 9 | Tells FB the same URL serves 10 locales |
| `twitter:card="summary_large_image"` | X / Mastodon / Slack hero card with the 1024×1024 og-image |
| JSON-LD `WebSite` | Enables Google sitelinks search box |
| JSON-LD `Organization` | Distinct `@id` from mahallem.ist → separate Google knowledge entity |

The JSON-LD `@id` values are anchored at
`https://recipies.mahallem.ist/#website` and `…/#organization`, so
Google's entity graph treats Otus Food as a child publisher of the
recipes domain — **not** as the same entity as `mahallem.ist`.

### 1.2 [recipe_list/web/robots.txt](recipe_list/web/robots.txt)

Permissive default + explicit allowlist for link-preview bots
(`facebookexternalhit`, `WhatsApp`, `TelegramBot`, `Twitterbot`,
`LinkedInBot`, `Slackbot`, `Discordbot`). Without this file nginx
fell through `try_files` and served `index.html` for `/robots.txt`,
which Facebook's scraper interpreted as a malformed deny-all
(symptom: HTTP 403 in the FB Sharing Debugger).

The last line points to the sitemap:

```
Sitemap: https://recipies.mahallem.ist/sitemap.xml
```

### 1.3 [recipe_list/web/sitemap.xml](recipe_list/web/sitemap.xml)

Minimal, two-URL sitemap — `/` and `/recipes`. Per-recipe URLs
(`/recipes/details/:id`) are **not** listed because the SPA renders
their content client-side; submitting them today would produce
soft-404s in Search Console (the HTML payload is identical for
every id). See **Future work** below for the SSR plan.

### 1.4 [recipe_list/web/manifest.json](recipe_list/web/manifest.json)

PWA manifest cleaned up — proper `name`, `short_name`, brand
`theme_color` `#2ECC71`, descriptive `description`, `lang: "en"`,
`categories: ["food", "lifestyle", "utilities"]`. Google uses the
manifest both for Lighthouse SEO scoring and for the Android "Add
to Home screen" shortcut metadata.

### 1.5 [recipe_list/nginx.conf](recipe_list/nginx.conf)

Already correct: `try_files $uri $uri/ /index.html;` serves real
files (sitemap.xml, robots.txt, og-image.jpg) directly and falls
back to the SPA shell for app routes.

---

## 2. Distinction from mahallem.ist

| Aspect | `mahallem.ist` | `recipies.mahallem.ist` |
|--------|----------------|-------------------------|
| Search Console property | one | **register separately** |
| robots.txt | its own | [recipe_list/web/robots.txt](recipe_list/web/robots.txt) |
| sitemap.xml | its own | [recipe_list/web/sitemap.xml](recipe_list/web/sitemap.xml) |
| og:site_name | (parent portal) | `Otus Food` |
| JSON-LD `@id` | (parent's URL) | `https://recipies.mahallem.ist/#organization` |
| OG image | (parent's) | `https://recipies.mahallem.ist/og-image.jpg` |

**Do not** add the recipes domain as a path under the parent
property in Search Console — Google treats sub-domains as separate
sites and a wildcard property won't carry over per-domain sitemap
submissions reliably. Always register the recipes host as its own
URL-prefix property.

---

## 3. How to register the site (one-time, per engine)

Replace the stub instructions below with the actual verification
tokens after you obtain them. Verification meta-tags should be
added to [recipe_list/web/index.html](recipe_list/web/index.html)
inside the `<head>` block, then re-build and re-deploy.

### 3.1 Google Search Console

You can register either as a **Domain property** (recommended —
covers all current and future subdomains, e.g. `recipies.`,
`admin.`, `www.`) or as a **URL-prefix property** scoped to
`https://recipies.mahallem.ist/`. Either works; the only
difference is the verification method and the form of the
sitemap URL you submit.

#### 3.1.a Domain property (DNS TXT verification) — recommended

1. Open https://search.google.com/search-console
2. **Add property → Domain → `mahallem.ist`**
3. Google issues a `google-site-verification=…` TXT record.
   Add it at your DNS provider as a TXT record on the apex
   `mahallem.ist`. Wait 1–10 min, click **Verify**.
4. **Sitemaps** → submit the **fully-qualified** sitemap URL:
   ```
   https://recipies.mahallem.ist/sitemap.xml
   ```
   In the Search Console UI the input field shows only the path
   suffix (`sitemap.xml`) for URL-prefix properties, but for a
   Domain property you must paste the **full URL including the
   `https://recipies.mahallem.ist/` prefix** because the property
   covers multiple hostnames. Google then attributes crawl stats
   to the `recipies` subdomain automatically.
5. Use **URL Inspection** on `https://recipies.mahallem.ist/` and
   click **Request indexing**. First crawl within 1–7 days.

No HTML changes needed — DNS TXT verification means we don't
have to ship a `google-site-verification` meta tag in
[recipe_list/web/index.html](recipe_list/web/index.html).

#### 3.1.b URL-prefix property (HTML-tag verification) — alternative

1. **Add property → URL prefix → `https://recipies.mahallem.ist/`**
2. Pick **HTML tag**. Google gives you
   `<meta name="google-site-verification" content="…token…">`.
3. Paste that line into `<head>` of
   [recipe_list/web/index.html](recipe_list/web/index.html)
   immediately under `<meta name="googlebot" …>`.
4. `flutter build web --release && git commit && git push` → deploy.
5. Back in Search Console click **Verify**.
6. **Sitemaps → Add a new sitemap →** type **`sitemap.xml`** (the
   form prefills the host, you only enter the path).
7. **URL Inspection → Request indexing** as above.

### 3.2 Bing Webmaster Tools (covers Bing + DuckDuckGo + Ecosia)

1. Open https://www.bing.com/webmasters
2. **Import from Google Search Console** if available — Bing will
   pull the verified property + sitemap automatically. Otherwise:
3. **Add a site → `https://recipies.mahallem.ist/`** and verify with
   `<meta name="msvalidate.01" content="…token…">`.
4. Submit `sitemap.xml`.

### 3.3 Yandex Webmaster (significant traffic from RU/CIS users)

1. Open https://webmaster.yandex.com
2. **Add site → `https://recipies.mahallem.ist/`**
3. Verification: `<meta name="yandex-verification" content="…token…">`.
4. Submit `sitemap.xml` under **Indexing → Sitemap files**.
5. Optionally enable **IndexNow** to push new recipe URLs in real
   time once SSR is added.

### 3.4 Facebook (link previews)

Facebook does not have a "register the site" flow — it scrapes on
demand. To prime the cache after every meta change:

1. Open https://developers.facebook.com/tools/debug/
2. Paste `https://recipies.mahallem.ist/` and click
   **Debug → Scrape Again** twice (first run refreshes robots.txt,
   second run refreshes OG tags).
3. Verify response code = 200, `og:image` resolves, preview card
   renders. If you see HTTP 403 again, robots.txt has regressed —
   re-check section 1.2.

Optional but recommended: connect a **Facebook App ID** so you
have a debugger insights tab. Add
`<meta property="fb:app_id" content="…">` to
[recipe_list/web/index.html](recipe_list/web/index.html).

### 3.5 X (Twitter) Card validation

The classic Card Validator was sunset. To verify:

1. Post the URL in a draft tweet on https://x.com/compose/post
2. The compose box should render the `summary_large_image` card
   with `og-image.jpg`. If not, X has cached the old version —
   wait ≈7 days or force a re-fetch by appending a harmless query
   string (`?v=2`).

### 3.6 LinkedIn Post Inspector

1. Open https://www.linkedin.com/post-inspector/
2. Paste `https://recipies.mahallem.ist/`
3. Click **Inspect**. Re-inspect after every OG-tag change —
   LinkedIn caches aggressively (~7 days otherwise).

### 3.7 Reddit / Discord / Slack / Telegram / WhatsApp

These all read Open Graph live, no registration needed. Validate
manually by pasting the URL into a private message / sandbox
channel. If a preview is stale, append `?v=N` to bust caches.

### 3.8 Pinterest Rich Pins (optional, high-leverage for recipes)

If/when per-recipe pages become crawlable (SSR — see Future work),
add JSON-LD `Recipe` schema to each detail page and validate at
https://developers.pinterest.com/tools/url-debugger/ to enable
Recipe Rich Pins. Skip for now — the SPA can't serve per-recipe
metadata yet.

---

## 4. Validation checklist (run after every deploy)

```bash
# robots.txt is text/plain and includes facebookexternalhit
curl -sI https://recipies.mahallem.ist/robots.txt | grep -i 'content-type'
curl -s  https://recipies.mahallem.ist/robots.txt | grep -i facebookexternalhit

# sitemap.xml is application/xml and reachable
curl -sI https://recipies.mahallem.ist/sitemap.xml

# og-image.jpg is image/jpeg, 200 OK
curl -sI https://recipies.mahallem.ist/og-image.jpg | head -3

# OG / canonical / JSON-LD present in index.html
curl -s  https://recipies.mahallem.ist/ | grep -E 'og:title|canonical|application/ld\+json'
```

Online validators:

| What | URL |
|------|-----|
| Google Rich Results Test | https://search.google.com/test/rich-results?url=https%3A%2F%2Frecipies.mahallem.ist%2F |
| Schema.org validator | https://validator.schema.org/#url=https%3A%2F%2Frecipies.mahallem.ist%2F |
| Google Mobile-Friendly Test | https://search.google.com/test/mobile-friendly?url=https%3A%2F%2Frecipies.mahallem.ist%2F |
| PageSpeed Insights | https://pagespeed.web.dev/report?url=https%3A%2F%2Frecipies.mahallem.ist%2F |
| Facebook Sharing Debugger | https://developers.facebook.com/tools/debug/?q=https%3A%2F%2Frecipies.mahallem.ist%2F |
| LinkedIn Post Inspector | https://www.linkedin.com/post-inspector/inspect/https:%2F%2Frecipies.mahallem.ist%2F |

---

## 5. Known limitations

1. **SPA, no SSR.** Googlebot does run JavaScript, but the second-
   pass render budget is small and other engines (Bing, DuckDuckGo,
   social scrapers) only see the static `index.html`. Today they
   index a single page — the homepage — described by the OG/JSON-LD
   block. Per-recipe content is not indexable until SSR.
2. **Single canonical URL.** All locales share `/`; locale is
   chosen client-side from `Accept-Language` / user preference.
   Google won't differentiate translated content. `hreflang` was
   intentionally omitted — pointing 10 hreflang tags to the same
   URL is a no-op and can trigger Search Console warnings. Add
   `hreflang` only when locale-prefixed paths exist (`/en/`,
   `/ru/`, …).
3. **Sitemap is static.** Two URLs only. The recipe DB grows
   nightly via the ingest cron (see [docs/recipe-ingester-and-size-cap.md](docs/recipe-ingester-and-size-cap.md)),
   but those new recipes are not surfaced in the sitemap.
4. **No `fb:app_id`.** Optional but recommended once a Facebook
   App is provisioned.

---

## 6. Future work

- **SSR / pre-render** for `/recipes/details/:id` so each recipe
  becomes a real indexable page. Cheapest path: a tiny Node-based
  pre-renderer (e.g. `puppeteer` + nginx side-cache) that snapshots
  HTML once per recipe-id and serves it to bots via
  `User-Agent`-based `map` in nginx. Then:
  - emit per-recipe JSON-LD `Recipe` schema (cookTime, recipeIngredient,
    recipeInstructions, image, aggregateRating)
  - regenerate `sitemap.xml` from the DB at deploy time (or split
    into a sitemap-index with one file per ~50 000 URLs)
  - enable Pinterest Rich Pins
  - submit per-recipe URLs via Google Indexing API + IndexNow
- **Locale-prefixed URLs** (`/en/`, `/ru/`, …) → real `hreflang`
  tags + per-locale OG titles/descriptions.
- **Web vitals monitoring** via Search Console "Core Web Vitals"
  report; fix LCP if Flutter bootstrap pushes it over 2.5 s.
- **Add recipe-detail share image** (currently every share uses
  the same hero image).

---

## 7. File-change summary

- [recipe_list/web/index.html](recipe_list/web/index.html) — full SEO `<head>`: viewport, robots, canonical, OG locales, twitter:summary_large_image, JSON-LD WebSite + Organization, sitemap link.
- [recipe_list/web/manifest.json](recipe_list/web/manifest.json) — proper name/description/theme_color/categories/lang.
- [recipe_list/web/robots.txt](recipe_list/web/robots.txt) — permissive default + social-bot allowlist + sitemap reference.
- [recipe_list/web/sitemap.xml](recipe_list/web/sitemap.xml) — new, two URLs.
- [recipe_list/nginx.conf](recipe_list/nginx.conf) — unchanged; existing `try_files` already serves these files correctly.
