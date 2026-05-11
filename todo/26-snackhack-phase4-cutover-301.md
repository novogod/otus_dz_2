# 26 — Snack Hack migration: Phase 4 — Cutover + 301 redirect

**Refs:** [migration-to-snackhack.app.md §2 Phase 4](../docs/extensions_for_v2/migration-to-snackhack.app.md),
[ops/nginx-recipies.mahallem.ist.conf](../ops/nginx-recipies.mahallem.ist.conf).
**Priority:** P0. **Scope:** `[ops]`. **Owner:** TBD.
**Depends on:** [25-snackhack-phase3b-static-assets.md](25-snackhack-phase3b-static-assets.md)
deployed to production (Snack Hack build serving on `snackhack.app`).

## Goal

Redirect `recipies.mahallem.ist` (all paths, all schemes) permanently to
`snackhack.app` while preserving path/query/fragment. Update the sitemap
cron to publish the new host.

**Note:** Zero clients exist on the old host — no API preservation needed.

## Changes

### `ops/nginx-recipies.mahallem.ist.redirect.conf` (new)

```nginx
server {
    listen 443 ssl http2;
    server_name recipies.mahallem.ist;

    ssl_certificate     /etc/letsencrypt/live/recipies.mahallem.ist/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/recipies.mahallem.ist/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # 301 preserves SEO link equity. Keep path + query + fragment.
    return 301 https://snackhack.app$request_uri;
}

server {
    listen 80;
    server_name recipies.mahallem.ist;
    return 301 https://snackhack.app$request_uri;
}
```

### Server steps (low-traffic window)

```bash
ssh -i ~/.ssh/mahallem_key_2 root@72.61.181.62 '
  cd /var/www/recipie/otus_dz_2 && git pull --ff-only origin main &&

  # Back up current vhost
  cp /etc/nginx/sites-available/recipies.mahallem.ist \
     /etc/nginx/sites-available/recipies.mahallem.ist.preredirect.bak &&

  # Install redirect vhost
  install -m 0644 ops/nginx-recipies.mahallem.ist.redirect.conf \
     /etc/nginx/sites-available/recipies.mahallem.ist &&
  nginx -t && systemctl reload nginx
'
```

### Update sitemap cron env

```bash
ssh -i ~/.ssh/mahallem_key_2 root@72.61.181.62 '
  sed -i "s|RECIPES_PUBLIC_HOST=.*|RECIPES_PUBLIC_HOST=https://snackhack.app|" \
    /etc/cron.d/recipes-sitemap &&
  /usr/bin/env RECIPES_PUBLIC_HOST=https://snackhack.app \
    bash /root/build_recipe_sitemap.sh
'
```

Update repo copy: `ops/etc-cron.d-recipes-sitemap` env line → `https://snackhack.app`.

## Acceptance

* Every old URL redirects with `301` to the same path on `snackhack.app`.
* Sitemap at `https://snackhack.app/sitemap.xml` lists `snackhack.app` URLs only.
* No active connections lost (nginx `reload`, not `restart`).

## Tests

```bash
# Apex
curl -sI https://recipies.mahallem.ist/ | head -2
# Expect: HTTP/2 301 ; location: https://snackhack.app/

# Recipe path with query + fragment preservation
curl -sI 'https://recipies.mahallem.ist/en/recipes/52772?x=1' | grep -i ^location
# Expect: location: https://snackhack.app/en/recipes/52772?x=1

# All locales redirect
for loc in en ru es fr de it tr ar fa ku; do
  printf "%-3s " $loc
  curl -sI "https://recipies.mahallem.ist/$loc/" | grep -i ^location
done
# Expect: each → https://snackhack.app/$loc/

# HTTP→HTTPS→new domain (one hop or two; both acceptable)
curl -sIL http://recipies.mahallem.ist/ | grep -E '^(HTTP|location)'

# Sitemap freshness
curl -s https://snackhack.app/sitemap.xml | head -20
grep -c 'snackhack.app' <(curl -s https://snackhack.app/sitemap.xml)
# Expect: matches > 0.
grep -c 'recipies.mahallem.ist' <(curl -s https://snackhack.app/sitemap.xml)
# Expect: 0.

# Bot path still prerenders on the live host
curl -sA 'Googlebot' https://snackhack.app/en/recipes/52772 \
  | grep -E 'canonical|<title>' | head -2
# Expect: canonical=snackhack.app + non-empty title.

# Cron file
ssh -i ~/.ssh/mahallem_key_2 root@72.61.181.62 \
  'grep RECIPES_PUBLIC_HOST /etc/cron.d/recipes-sitemap'
# Expect: =https://snackhack.app
```
