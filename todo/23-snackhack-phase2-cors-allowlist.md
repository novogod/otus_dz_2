# 23 — Snack Hack migration: Phase 2 — CORS + backend allowlist

**Refs:** [migration-to-snackhack.app.md §2 Phase 2, §3.2](../docs/extensions_for_v2/migration-to-snackhack.app.md),
[docs/cors-recipes.md](../docs/cors-recipes.md).
**Priority:** P0. **Scope:** `[server][parent-backend]`. **Owner:** TBD.
**Depends on:** [22-snackhack-phase1-parallel-hosting.md](22-snackhack-phase1-parallel-hosting.md).

## Goal

Allow `https://snackhack.app` and `https://www.snackhack.app` as origins on:
1. Recipes API (Express) at `recipies.mahallem.ist/recipes/*`.
2. Parent admin/auth API at `mahallem.ist/api/*` (login, ratings, favorites,
   passkey, image upload).
3. imgproxy at `mahallem.ist/imgproxy/*`.
4. Storage at `mahallem.ist/storage/*`.

Keep all existing origins (`recipies.mahallem.ist`, localhost dev hosts).

## Changes

In each service’s CORS middleware (separate repos):

```js
const allowedOrigins = new Set([
  'https://recipies.mahallem.ist',
  'https://snackhack.app',
  'https://www.snackhack.app',
  // dev origins unchanged
]);
```

Response headers on allowed origins:

```
Access-Control-Allow-Origin: <echoed origin>
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH
Access-Control-Allow-Headers: Authorization, Content-Type,
                              X-Recipes-User-Token, X-CSRF-Token
Access-Control-Max-Age: 600
Vary: Origin
```

For session cookies set by `mahallem.ist`: change `SameSite=Lax` → `SameSite=None; Secure`.

## Acceptance

* Preflight from `snackhack.app` succeeds against all four services.
* Existing `recipies.mahallem.ist` clients still work (no regression).
* Cookies set on `mahallem.ist` carry `SameSite=None; Secure`.

## Tests

```bash
# Recipes API preflight
curl -sI -X OPTIONS \
  -H "Origin: https://snackhack.app" \
  -H "Access-Control-Request-Method: GET" \
  https://recipies.mahallem.ist/recipes/health \
  | grep -iE 'access-control-allow-(origin|credentials|methods)'
# Expect: Allow-Origin: https://snackhack.app, Allow-Credentials: true

# imgproxy preflight
curl -sI -X OPTIONS \
  -H "Origin: https://snackhack.app" \
  https://mahallem.ist/imgproxy/insecure/resize:fit:100:100:0/aHR0cHM6Ly9leGFtcGxlLmNvbS8.png \
  | grep -i 'access-control-allow-origin'

# Auth API preflight (login)
curl -sI -X OPTIONS \
  -H "Origin: https://snackhack.app" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type" \
  https://mahallem.ist/api/auth/login \
  | grep -iE 'access-control'

# Regression: existing recipies.mahallem.ist origin still allowed
curl -sI -X OPTIONS \
  -H "Origin: https://recipies.mahallem.ist" \
  -H "Access-Control-Request-Method: GET" \
  https://recipies.mahallem.ist/recipes/health \
  | grep -i 'access-control-allow-origin'

# Cookie SameSite=None on login
curl -sI -X POST \
  -H "Origin: https://snackhack.app" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test","password":"x"}' \
  https://mahallem.ist/api/auth/login \
  | grep -i '^set-cookie:'
# Expect: SameSite=None; Secure attributes present.
```

Browser smoke (manual): open DevTools on `https://snackhack.app/`, run in
console:

```js
fetch('https://recipies.mahallem.ist/recipes/health', {credentials:'include'})
  .then(r => console.log(r.status))
// Expect: 200, no CORS error in console.
```
