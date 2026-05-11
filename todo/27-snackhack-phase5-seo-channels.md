# 27 — Snack Hack migration: Phase 5 — SEO + channel migration

**Refs:** [migration-to-snackhack.app.md §2 Phase 5](../docs/extensions_for_v2/migration-to-snackhack.app.md).
**Priority:** P1. **Scope:** `[seo][marketing]`. **Owner:** TBD.
**Depends on:** [26-snackhack-phase4-cutover-301.md](26-snackhack-phase4-cutover-301.md).

## Goal

Tell every search engine + social platform that `recipies.mahallem.ist` has
moved to `snackhack.app`, and refresh cached share previews.

## Changes (procedure, not code)

1. **Google Search Console**
   * Add property: Domain `snackhack.app` (DNS TXT verification — auto).
   * Submit `https://snackhack.app/sitemap.xml`.
   * In old property → Settings → **Change of Address** → point at
     `snackhack.app`.
2. **Bing Webmaster Tools** — add `snackhack.app`, submit sitemap, use
   *Site Move* tool.
3. **Yandex Webmaster** — add `snackhack.app`, submit sitemap, use
   *Site move* feature.
4. **Re-scrape OG cards** for at least one recipe URL per locale:
   * Facebook Sharing Debugger: <https://developers.facebook.com/tools/debug/>
   * Twitter/X Card Validator: <https://cards-dev.twitter.com/validator>
   * LinkedIn Post Inspector: <https://www.linkedin.com/post-inspector/>
   * Telegram: post one `snackhack.app` URL in a controlled channel to
     trigger preview refresh.
5. **External backlinks** — update GitHub repo description, social bios,
   any marketing pages.

## Acceptance

* Both old and new properties verified in Search Console; Change of Address
  status = "Processing" or "Active".
* New sitemap accepted (`Submitted: N` URLs, `Indexed: > 0` within 7 days).
* Social platforms render fresh OG cards with `snackhack.app` titles + images.

## Tests

```bash
# DNS TXT verification record present
dig +short TXT snackhack.app | grep -i google-site-verification
# Expect: at least one matching TXT.

# Sitemap reachable to Googlebot
curl -sA Googlebot https://snackhack.app/sitemap.xml | head -5
# Expect: <?xml + <urlset> opening.

# Sample social re-scrape (Facebook scraper UA)
curl -sA 'facebookexternalhit/1.1' https://snackhack.app/en/recipes/52772 \
  | grep -E 'og:title|og:image|og:url' | head -3
# Expect: og:url=https://snackhack.app/...

# Old URL → new URL preserved across the redirect chain
curl -sILA 'facebookexternalhit/1.1' \
  https://recipies.mahallem.ist/en/recipes/52772 \
  | grep -E '^(HTTP|location)'
# Expect: 301 → https://snackhack.app/en/recipes/52772, then 200.

# Search Console API (optional, if token configured) — submitted URL count
# left as manual UI step.
```

Day-7 follow-up checks:

```bash
# Google index sample
curl -s "https://www.google.com/search?q=site:snackhack.app" \
  -A 'Mozilla/5.0' | grep -oE 'snackhack\.app/[^"]*' | sort -u | head -10
# Expect: a few indexed paths. Manual UI in Search Console is authoritative.
```
