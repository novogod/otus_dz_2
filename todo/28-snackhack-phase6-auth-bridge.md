# 28 — Snack Hack migration: Phase 6 — Cross-origin auth bridge

**Refs:** [migration-to-snackhack.app.md §3.3, §5](../docs/extensions_for_v2/migration-to-snackhack.app.md).
**Priority:** P1 (can run in parallel with Phases 3–4).
**Scope:** `[client][server][parent-backend]`. **Owner:** TBD.
**Depends on:** [23-snackhack-phase2-cors-allowlist.md](23-snackhack-phase2-cors-allowlist.md).

## Goal

Re-establish authenticated sessions for users on `snackhack.app` without
forcing every user to log in again. **WebAuthn RP-ID must remain
`mahallem.ist`** — passkey ceremonies happen on the parent origin.

## Decision

Adopt **Option B** from §3.3: separate first-party session cookie on
`snackhack.app`, populated by a one-time cross-sign handshake to
`mahallem.ist`.

## Changes

### Parent backend (`mahallem.ist`)

Add endpoint:

```
GET https://mahallem.ist/auth/cross-sign?to=https://snackhack.app/auth/callback
```

Behaviour:
- If the request carries a valid `mahallem_session` cookie, mint a short-lived
  (60 s, single-use) signed token bound to the user + target origin.
- 302 to `${to}?token=<jwt>`.
- If no session: 302 to `https://mahallem.ist/login?return_to=<encoded original>`.

### `snackhack.app` SPA

* New route `/auth/callback` (handled in `lib/router/`): reads `?token=`
  from the URL, POSTs it to `https://snackhack.app/api/auth/exchange` which
  validates the JWT (HS256, shared secret with parent backend), and sets a
  first-party `snackhack_session` cookie.
* On any 401 from the recipes API, before showing the login screen:
  redirect to `https://mahallem.ist/auth/cross-sign?to=…` *exactly once*
  per session (track via `sessionStorage` to avoid loops).

### Passkey flow

* The "Sign in with passkey" button on `snackhack.app` opens
  `https://mahallem.ist/passkey/start` in a top-level navigation
  (RP-ID = `mahallem.ist` requires same-origin ceremony).
* On success, `mahallem.ist` redirects back through the same cross-sign
  bridge with a fresh token.

## Acceptance

* Logged-in user on `mahallem.ist` who navigates to `snackhack.app` is
  silently signed in (no manual re-login).
* Logged-out user is shown the login screen and can complete a passkey
  ceremony on `mahallem.ist`, then return signed-in on `snackhack.app`.
* Tokens are single-use, expire in ≤ 60 s, and bound to the target origin.

## Tests

### Backend unit tests (parent repo)

* Token expires after 60 s.
* Token is rejected if `target_origin` claim != verifier’s origin.
* Token is rejected on second use (`jti` consumed).
* Without `mahallem_session`, endpoint redirects to login.

### SPA tests (`recipe_list`)

* `flutter test --no-pub test/auth/cross_sign_callback_test.dart`:
  * Happy path: `/auth/callback?token=<valid>` → `snackhack_session`
    cookie set, router pushes home.
  * Tampered token: 400 banner shown, user logged out.
  * Replay attempt: second visit with same token → 401.
* Loop guard: simulate repeated 401s → at most one redirect to
  `/auth/cross-sign` per session.

### End-to-end (manual or Playwright)

```bash
# 1. Log into mahallem.ist (cookie set).
curl -c /tmp/cj -s -X POST \
  -H 'Content-Type: application/json' \
  -d '{"email":"u@test","password":"…"}' \
  https://mahallem.ist/api/auth/login

# 2. Hit cross-sign with that cookie.
curl -b /tmp/cj -sI \
  'https://mahallem.ist/auth/cross-sign?to=https://snackhack.app/auth/callback' \
  | grep -i ^location
# Expect: location: https://snackhack.app/auth/callback?token=…

# 3. Exchange the token.
TOKEN="<from step 2>"
curl -c /tmp/cj2 -sI -X POST \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\"}" \
  https://snackhack.app/api/auth/exchange \
  | grep -iE '^(HTTP|set-cookie)'
# Expect: 200 + Set-Cookie: snackhack_session=…; SameSite=Lax; Secure; HttpOnly

# 4. Replay must fail.
curl -sI -X POST \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\"}" \
  https://snackhack.app/api/auth/exchange \
  | head -1
# Expect: HTTP/2 401
```

### Passkey smoke

* On a device with an enrolled passkey (RP-ID = `mahallem.ist`), open
  `https://snackhack.app/login`, tap "Sign in with passkey" — verify the
  OS prompt shows `mahallem.ist` as the relying party, and that the user
  lands back on `snackhack.app` authenticated.
