# Food Admin Rollout / Rollback Runbook

## Scope

This runbook applies to the new production model for food-app admin:

- `POST /api/recipe-admin/login`
- `GET /api/recipe-admin/users`
- `PATCH /api/recipe-admin/users/:id`
- `DELETE /api/recipe-admin/users/:id`
- `POST /api/recipe-admin/users/bulk-delete`

Legacy header-based admin routes (`/api/users/admin/*`, `/users/admin/*`) are removed.

---

## Pre-rollout checks

1. DB migrations applied:
   - `20260503_recipe_app_service_isolation.sql`
   - `20260503_recipe_app_admins.sql`
   - `20260503_recipe_app_admin_audit_log.sql`
2. At least one active row exists in `recipe_app_admins`.
3. `RECIPE_ADMIN_TOKEN_SECRET` is configured in production env.
4. `RECIPE_ADMIN_BOOTSTRAP_*` variables are either set for first boot only or left empty after admin is created.

---

## Smoke checks (post-deploy)

Use the helper script in backend infra repo:

- `local_docker_admin_backend/check_recipe_admin_rollout.sh`

The script validates:

1. admin login returns bearer token
2. bearer users-list works
3. legacy `/api/users/admin/list` returns 404
4. audit rows are present for `admin_login` and `list_users`

---

## Rollback steps

If rollout causes issues:

1. Roll back app image to previous stable tag.
2. Restore previous route behavior from git history (if required for emergency only).
3. Keep DB migrations in place (non-destructive).
4. Re-run smoke checks for restored version.

---

## Security checks

1. Repeated invalid admin logins should eventually return HTTP 429 (`admin_login_rate_limited`).
2. `recipe_app_service` role must not access Mahallem `users` table.
3. Admin actions must be present in `recipe_app_admin_audit_log`.

---

## Operational notes

- Use short token TTL in production (`RECIPE_ADMIN_TOKEN_TTL_SECONDS`).
- Keep bootstrap admin password strong (minimum 12 chars with upper/lower/digit).
- Rotate `RECIPE_ADMIN_TOKEN_SECRET` via controlled deployment windows.
