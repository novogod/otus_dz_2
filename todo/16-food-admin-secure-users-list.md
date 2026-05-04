# 16 — Secure Food Admin: users list/edit/delete in production

> **Status:** planned
> **Depends on:** `docs/food-app-admin-production-architecture.md`
> **Priority:** P0
> **Scope:** `[server]` + `[client]` + `[infra]`

Goal: implement production-safe food admin user management where admin is a separate entity and DB permissions are limited to food-app domain only.

---

## Chunk A — DB isolation foundation (schema + role) `[infra][server]`

### Changes

- Add SQL migration:
  - create schema `recipe_app` (if not exists)
  - move/create food-app tables in this schema (`recipe_app_users`, `recipe_app_user_favorites`, ...)
  - create role `recipe_app_service`
  - grant usage/select/insert/update/delete only for `recipe_app` objects
  - explicitly revoke/default-deny on Mahallem domain tables
- Add dedicated DB credentials in deploy env for recipe-admin runtime.

### Tests

- DB permission test script:
  - `recipe_app_service` can query `recipe_app.recipe_app_users`
  - `recipe_app_service` **cannot** query `public.users` (expect permission denied)
- Migration idempotency test (run migration twice, no failure).

### Acceptance

- Least-privilege boundary is enforced in DB, not only in app code.

---

## Chunk B — Admin identity model `[server]`

### Changes

- Add table `recipe_app.recipe_app_admins`:
  - email, password_hash, role, status, timestamps
- Add bootstrap script to create first super admin from env (one-time guarded).
- Add password policy + bcrypt/argon2 hashing.

### Tests

- Unit tests for admin creation/validation.
- Duplicate email constraint test.
- Inactive admin cannot authenticate test.

### Acceptance

- Food-admin identity exists independently from `recipe_app_users` and Mahallem `users`.

---

## Chunk C — Token-based admin auth `[server]`

### Changes

- Implement `POST /api/recipe-admin/login`.
- Return short-lived bearer token with claims (`scope=recipe_admin`, `role`, `exp`, `sub`).
- Add middleware `requireRecipeAdminScope`:
  - verify signature/exp
  - verify active admin
  - inject admin context to request

### Tests

- Unit tests:
  - valid token accepted
  - expired token rejected
  - wrong scope rejected
  - disabled admin rejected
- API tests for login success/failure matrix.

### Acceptance

- Admin endpoints can be protected without static header credentials.

---

## Chunk D — Users list/edit/delete endpoints on isolated pool `[server]`

### Changes

- Introduce endpoints:
  - `GET /api/recipe-admin/users`
  - `PATCH /api/recipe-admin/users/:id`
  - `DELETE /api/recipe-admin/users/:id`
  - `POST /api/recipe-admin/users/bulk-delete`
- Use dedicated pool with `recipe_app_service` role only.
- Role matrix:
  - `viewer`: list
  - `operator`: list/edit/delete
  - `super_admin`: all + admin management (future)

### Tests

- Integration tests for each endpoint and role matrix.
- Negative tests for malformed IDs/payload.
- Permission boundary tests to ensure only `recipe_app` tables are used.

### Acceptance

- All required user manipulations work against food-app users only.

---

## Chunk E — Audit logging + observability `[server][infra]`

### Changes

- Add `recipe_app.recipe_app_admin_audit_log` table.
- Write audit record on every list/edit/delete action.
- Add structured logs (JSON) with `request_id`, `admin_id`, `action`, `status`.
- Ensure Nginx forwards/sets request id.

### Tests

- Integration tests asserting audit row created for mutation/list actions.
- Log smoke test in staging/prod container output.

### Acceptance

- Every admin action is traceable and debuggable.

---

## Chunk F — Flutter client migration `[client]`

### Changes

- In `recipe_list/lib/auth/admin_session.dart`:
  - add `loginRecipeAdmin()` against `/api/recipe-admin/login`
  - replace header-based admin calls with bearer token calls
  - remove legacy `_adminAuthHeaderCandidates` fallback path
- Update admin UI flow for token-expiry handling (re-auth prompt).

### Tests

- Unit tests for admin session token handling.
- Widget/integration tests:
  - list loads after admin login
  - edit/delete success paths
  - expired token => re-auth flow

### Acceptance

- Admin users list/edit/delete works from app using token auth only.

---

## Chunk G — Backward-compat removal + hardening `[server][client]`

### Changes

- Remove old compat admin header routes (`/api/users/admin/*`, `/users/admin/*`) or keep temporary read-only with explicit deprecation window.
- Remove static compat admin env secret usage from prod path.
- Add rate limit + lockout for `/api/recipe-admin/login`.

### Tests

- Regression suite for old endpoint deprecation behavior.
- Security tests for brute-force throttling.

### Acceptance

- No temporary/legacy admin auth path remains in production control plane.

---

## Chunk H — Rollout + rollback checklist `[infra]`

### Changes

- Canary deploy 5-10% traffic (if available) or staged environment gate.
- Run smoke scripts:
  - admin login
  - list/edit/delete
  - audit row check
  - DB permission check
- Prepare rollback package:
  - previous image tag
  - DB migration rollback notes

### Tests

- End-to-end smoke on production-like environment.

### Acceptance

- Production rollout completed with clear rollback path and verified boundaries.

---

## Test gate per chunk

- Server: unit + integration suites for changed modules
- Client: `flutter analyze` + focused tests for auth/admin flow
- Manual prod smoke:
  - `200` on authorized admin list
  - `401/403` on invalid token
  - no access to Mahallem domain tables by `recipe_app_service`

---

## Definition of done

- Food app admin is a separate production identity domain.
- Admin operations are token-based, auditable, and role-gated.
- Runtime DB permissions are limited to food-app objects only.
- Mahallem project data is not reachable through food-admin path.
