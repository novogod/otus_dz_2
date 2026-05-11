# 29 — Snack Hack migration: Final cleanup + sunset

**Refs:** [migration-to-snackhack.app.md §7 Rollback, §8 Acceptance](../docs/extensions_for_v2/migration-to-snackhack.app.md).
**Priority:** P2. **Scope:** `[ops][docs]`. **Owner:** TBD.
**Depends on:** [27-snackhack-phase5-seo-channels.md](27-snackhack-phase5-seo-channels.md).
**Earliest:** 7 days after Phase 4 deploy (rollback window closed).
**Latest:** 12 months after Phase 4 (full SEO transfer done).

## Goal

Lock in the migration: confirm metrics, archive the rollback artifacts,
optionally retire `recipies.mahallem.ist`.

## Changes

* Verify Search Console Change-of-Address completion (status = "Move processed").
* Delete the `.preredirect.bak` vhost file from the server.
* Remove `recipies.mahallem.ist:host-gateway` from `docker-compose.web.yml`
  `extra_hosts`.
* Optionally retire `recipies.mahallem.ist` cert renewal cron once 95%+ of
  traffic has shifted (measured via nginx access log analysis).
* Update internal docs: any doc still showing `recipies.mahallem.ist` as
  primary should be footnoted "historical — use snackhack.app".

## Acceptance

* `nginx -t` still passes after vhost cleanup.
* Production logs show < 5% of total traffic hitting the redirect vhost.
* `docker compose -f docker-compose.web.yml config` no longer references
  `recipies.mahallem.ist` (except in comments/history).

## Tests

```bash
# Traffic share over the last 7 days
ssh -i ~/.ssh/mahallem_key_2 root@72.61.181.62 '
  zcat -f /var/log/nginx/access.log* | awk "{print \$2}" | sort | uniq -c | sort -rn | head
'
# Expect: snackhack.app >> recipies.mahallem.ist.

# Search Console (manual UI) — Move status = processed.
# Sitemap coverage: indexed pages count for snackhack.app ≥ old indexed count.

# Final acceptance criteria from the plan (re-run against production)
curl -sI https://snackhack.app/ | head -1                    # 200
curl -sI https://recipies.mahallem.ist/ | head -2            # 301 → snackhack.app
curl -s  https://snackhack.app/manifest.json | jq -r .name   # "Snack Hack — recipes from around the world"
curl -s  https://snackhack.app/robots.txt | grep Sitemap     # snackhack.app
curl -s  https://snackhack.app/ | grep canonical             # snackhack.app
curl -sA Googlebot https://snackhack.app/en/recipes/52772 \
  | grep -E 'canonical|<title>' | head -2                    # prerender OK
# All 6 must pass.
```

## Rollback note (kept for the record)

If a critical regression appears within 7 days:

```bash
ssh -i ~/.ssh/mahallem_key_2 root@72.61.181.62 '
  cp /etc/nginx/sites-available/recipies.mahallem.ist.preredirect.bak \
     /etc/nginx/sites-available/recipies.mahallem.ist &&
  nginx -t && systemctl reload nginx
'
```

…and rebuild the SPA with
`--dart-define=RECIPES_WEB_ORIGIN=https://recipies.mahallem.ist`.
After 7 days, this is no longer a clean rollback because SEO equity has
started transferring.
