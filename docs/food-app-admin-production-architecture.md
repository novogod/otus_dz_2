# Food App Admin on Production — Secure Isolation Architecture

## Status

- **Date:** 2026-05-03
- **Scope:** Otus Food app admin (users list/edit/delete) in production
- **Goal:** Food app admin must be a **separate entity** with permissions only to food-app DB objects; Mahallem project DB objects must stay untouched.

---

## 1) Current integration audit (how API connects to food app)

### Client (Flutter `recipe_list`) connectivity

From `recipe_list/lib/data/api/recipe_api_config.dart` and `recipe_list/lib/auth/admin_session.dart`:

- Recipe feed API base (default): `https://mahallem.ist/recipes`
- Auth/admin base: `https://mahallem.ist`
- Client calls compatibility routes:
  - login: `/users/login` (plus aliases)
  - signup: `/users` (plus aliases)
  - admin list/edit/delete:
    - `GET /api/users/admin/list` or `/users/admin/list`
    - `PATCH /api/users/admin/:id`
    - `DELETE /api/users/admin/:id`
    - `POST /api/users/admin/bulk-delete`

### Backend (`mahallem_ist/local_user_portal/routes/auth.js`) compatibility domain

- Food-auth users are stored in `recipe_app_users` (isolated from Mahallem `users`).
- Admin list/edit/delete endpoints operate on `recipe_app_users`.
- Current admin guard for these endpoints is header-based (`x-recipe-admin-login/password`) with compat credentials (`RECIPE_COMPAT_ADMIN_LOGIN/PASSWORD`, default `admin/admin`).

### Observed production behavior

- `/api/users/admin/list` returns:
  - `200` when compat admin headers match
  - `403 {"error":"admin_required"}` on header mismatch
- Nginx access logs also show occasional `502` for this endpoint (upstream transient).

---

## 2) Security and reliability gaps in current model

1. **Static header admin credential model**
   - Shared static credential is high-risk (rotation, leak blast radius, no per-admin audit).

2. **No dedicated admin identity table for food app**
   - Food admin is not represented as first-class production entity with role/permissions.

3. **No DB least-privilege boundary at runtime for food admin actions**
   - App currently runs with a broad DB role/pool and enforces boundaries mostly in code.

4. **Weak observability for admin endpoint failures**
   - App/container logs do not always provide route-level reason (`403` vs `5xx` context).

5. **Client fallback/compat probing complexity**
   - Multiple path/payload probing and legacy paths increase ambiguity during incidents.

---

## 3) Safest target model (recommended)

## 3.1 Identity model: separate food-admin entity

Create dedicated table in food-app domain:

- `recipe_app_admins`
  - `id (uuid pk)`
  - `email (unique)`
  - `password_hash`
  - `status` (`active|inactive`)
  - `role` (`super_admin|operator|viewer`)
  - `created_at`, `updated_at`, `last_login_at`

Food admin login must use a dedicated endpoint:

- `POST /api/recipe-admin/login`

Issue short-lived signed token (JWT or HMAC token) with explicit claims:

- `sub` (admin id)
- `scope: recipe_admin`
- `role`
- `exp`

Admin CRUD endpoints accept only:

- `Authorization: Bearer <token>`

No static `x-recipe-admin-password` in production flow.

## 3.2 Authorization model

Route middleware `requireRecipeAdminScope`:

- verifies token signature + expiry
- enforces `scope == recipe_admin`
- checks admin status active in `recipe_app_admins`
- enforces role matrix:
  - `viewer`: list only
  - `operator`: list/edit/delete users
  - `super_admin`: operator + admin management

## 3.3 DB least-privilege boundary (critical)

Introduce dedicated Postgres role for food app admin runtime, e.g. `recipe_app_service`.

### Principle

- `recipe_app_service` has grants **only** on food-app objects (`recipe_app_*` tables/schema).
- **No privileges** on Mahallem core objects (`users`, jobs, wallets, chats, etc.).

### Preferred physical boundary

- Move food-app tables to dedicated schema: `recipe_app`.
- Grant role access only to schema `recipe_app`.

### Minimal viable boundary (if schema move delayed)

- Keep `public.recipe_app_*` tables but grant role only on those exact tables/functions.
- Explicitly revoke/default-deny all others.

### Runtime boundary

- Create separate DB pool in `local_user_portal` for recipe-admin routes:
  - `RECIPE_APP_DB_USER=recipe_app_service`
  - `RECIPE_APP_DB_PASSWORD=...`
- Admin routes must use this pool only.

## 3.4 API boundary

Keep endpoint namespace explicit and isolated:

- `/api/recipe-admin/...` for admin auth and operations

Avoid reusing generic `/api/users/...` namespace for food admin internals.

## 3.5 Audit and observability

Add immutable audit log table:

- `recipe_app_admin_audit_log`
  - admin id/email
  - action (`list_users|update_user|delete_user|bulk_delete`)
  - target ids
  - request_id
  - ip/ua
  - status
  - timestamp

Add structured logs with request correlation ID for all `recipe-admin` routes.

---

## 4) Production behavior contract (how it should work)

1. Admin opens Food App Profile → Admin login form.
2. Client authenticates at `POST /api/recipe-admin/login`.
3. Server validates against `recipe_app_admins`, issues short-lived token.
4. Client stores token in memory (optional secure local storage with expiry).
5. Users list request:
   - `GET /api/recipe-admin/users`
   - with `Authorization: Bearer ...`
6. Server route middleware verifies admin token and role.
7. Route uses **recipe-app DB pool** (`recipe_app_service`) and queries only `recipe_app_users`.
8. Edit/delete endpoints follow same model with role checks + audit log write.
9. Any attempt to access Mahallem domain tables through this route path is blocked at DB privilege layer.

---

## 5) Non-goals / hard boundaries

- Food admin must not mutate/read Mahallem project tables.
- No static shared admin password in production request path.
- No temporary header fallbacks in final model.

---

## 6) Migration/rollout strategy (high-level)

1. Add new `recipe_app_admins` + audit schema and dedicated DB role.
2. Introduce new `/api/recipe-admin/*` endpoints behind feature flag.
3. Keep old endpoints read-only during migration window.
4. Cut client to new endpoints and token auth.
5. Remove old compat admin header routes.
6. Verify via integration tests + canary + rollback plan.

---

## 7) Acceptance criteria

- Food admin can list/edit/delete food users in production.
- Food admin credentials are independent entities in `recipe_app_admins`.
- DB role used by food-admin routes cannot access Mahallem domain tables.
- All admin mutations are auditable.
- Legacy static header admin path is removed.
