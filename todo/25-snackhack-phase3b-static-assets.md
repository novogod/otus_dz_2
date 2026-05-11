# 25 — Snack Hack migration: Phase 3b — Static web assets + prerender

**Refs:** [migration-to-snackhack.app.md §3.3, §3.4, §3.6](../docs/extensions_for_v2/migration-to-snackhack.app.md).
**Priority:** P0. **Scope:** `[web][prerender][ops]`. **Owner:** TBD.
**Depends on:** [24-snackhack-phase3a-web-origin-constant.md](24-snackhack-phase3a-web-origin-constant.md).

## Goal

Update everything outside Dart source (HTML shell, robots, sitemap, prerender
config, docker compose) to point at `snackhack.app`.

## Changes

### `recipe_list/web/index.html`

Replace every `https://recipies.mahallem.ist` literal with `https://snackhack.app`:
- `<link rel="canonical">` line 146.
- `og:url`, `og:image`, `og:image:secure_url` lines 153–155.
- `twitter:image` line 176.
- JSON-LD `@id`, `url`, publisher refs, `logo.url` lines 206–220.
- `var ORIGIN = 'https://snackhack.app';` line 318.
- Update comments lines 124–125, 198.

### `recipe_list/web/robots.txt` line 35

```
Sitemap: https://snackhack.app/sitemap.xml
```

### `recipe_list/web/sitemap.xml`

Regenerate via the sitemap script (see Phase 4) or hand-edit the two
`<loc>` entries + comment header.

### `prerender/server.js`

- Line 133: User-Agent string → `SnackHackPrerender/1.0 (+https://snackhack.app)`.
- Verify `process.env.PUBLIC_HOST` is the canonicalisation source; if any
  hard-coded `recipies.mahallem.ist` remains, replace with the env read.

### `prerender/package.json` line 6

- `description` → "Prerender service for snackhack.app SPA".

### `prerender/test/server.test.js`

- Update the 6+ canonical/og fixture URLs to `https://snackhack.app/...`.

### `docker-compose.web.yml`

```yaml
prerender:
  environment:
    - PUBLIC_HOST=https://snackhack.app
  extra_hosts:
    - "snackhack.app:host-gateway"
    - "recipies.mahallem.ist:host-gateway"   # keep during overlap
```

### `recipe_list/test/seo_head_test.dart` lines 18, 29

- Fixture image URL → `https://snackhack.app/img/pasta.jpg`.

## Acceptance

* `grep -rE 'recipies\.mahallem\.ist' recipe_list/web prerender docker-compose.web.yml` returns 0 hits (apart from `extra_hosts` overlap line, which is intentional).
* Built bundle's `web/index.html` shows `og:url=https://snackhack.app/`.

## Tests

```bash
# Static asset audit
grep -rnE 'recipies\.mahallem\.ist' \
  recipe_list/web recipe_list/lib prerender docker-compose.web.yml \
  | grep -v 'extra_hosts'
# Expect: no output.

# SEO tests
cd recipe_list && flutter test --no-pub test/seo_head_test.dart
# Expect: pass.

# Prerender tests
cd ../prerender && npm test
# Expect: all green; canonical assertions hit snackhack.app.
```

Local build smoke:

```bash
cd recipe_list
flutter build web --release --no-tree-shake-icons \
  --dart-define=RECIPES_WEB_ORIGIN=https://snackhack.app

grep -c 'snackhack.app' build/web/index.html
# Expect: >= 10 (canonical + og + twitter + JSON-LD).

grep -c 'recipies.mahallem.ist' build/web/index.html
# Expect: 0.
```

Run the local container:

```bash
docker compose -f docker-compose.web.yml up --build -d
curl -s http://127.0.0.1:8088/ | grep -E 'canonical|og:url' | head -3
# Expect: snackhack.app URLs.

curl -sA Googlebot http://127.0.0.1:8088/en/recipes/52772 \
  | grep -E 'canonical|og:url' | head -2
# Expect: prerender chain still works, URLs canonicalised to snackhack.app.
```
