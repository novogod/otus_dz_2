# 22 — Snack Hack migration: Phase 1 — Parallel hosting + certbot

**Refs:** [migration-to-snackhack.app.md §2 Phase 1](../docs/extensions_for_v2/migration-to-snackhack.app.md),
[ops/nginx-snackhack.app.conf](../ops/nginx-snackhack.app.conf) (commit `31ee42c`).
**Priority:** P0. **Scope:** `[ops]`. **Owner:** TBD.
**Depends on:** DNS A records for `snackhack.app` + `www` propagated (done 2026-05-11).

## Goal

Serve the existing Flutter-web build at `https://snackhack.app` in parallel
with `recipies.mahallem.ist`. Zero user-visible impact: both hosts return
the same SPA. No code change yet — this is pure infra.

## Changes

On `72.61.181.62` (SSH key `~/.ssh/mahallem_key_2`):

```bash
ssh -i ~/.ssh/mahallem_key_2 root@72.61.181.62 '
  cd /var/www/recipie/otus_dz_2 && git pull --ff-only origin main &&
  install -m 0644 ops/nginx-snackhack.app.conf \
    /etc/nginx/sites-available/snackhack.app &&
  ln -sf /etc/nginx/sites-available/snackhack.app \
    /etc/nginx/sites-enabled/snackhack.app &&
  nginx -t && systemctl reload nginx &&
  certbot --nginx -d snackhack.app -d www.snackhack.app \
    --non-interactive --agree-tos -m admin@mahallem.ist
'
```

## Acceptance

* `https://snackhack.app/` responds `200` with valid Let’s Encrypt cert.
* `https://www.snackhack.app/` either `200` or `301` to apex (vhost choice).
* `https://recipies.mahallem.ist/` continues to serve normally.
* `nginx -t` passes; `systemctl status nginx` is `active (running)`.

## Tests

```bash
# Cert validity + chain
curl -vI https://snackhack.app/ 2>&1 | grep -E '^(< HTTP|.*subject:|.*issuer:|.*expire date:)'
# Expect: HTTP/2 200, issuer=Let's Encrypt, subject CN snackhack.app

# Both hosts return identical SPA bytes
diff <(curl -s https://snackhack.app/ | sha256sum) \
     <(curl -s https://recipies.mahallem.ist/ | sha256sum)
# Expect: identical hashes (still the old build).

# HSTS preload precondition — .app TLD enforces HTTPS
curl -sI http://snackhack.app/ | head -1
# Expect: 301 → https

# Prerender path on new host
curl -sA 'Googlebot' https://snackhack.app/en/recipes/52772 | grep -c '<title>'
# Expect: >= 1 (prerender chain wired in vhost).
```
