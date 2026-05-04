# Project Recent Changes

_Last updated: 2026-05-04_

## Password recovery session fix (web platform)

- **Issue**: Web clients received "session expired" error when submitting password recovery code, even though `/forgot-password` succeeded
- **Root Cause**: Backend `/reset-password` endpoint relied on Express HTTP-only session cookies to validate recovery context
  - Flutter web cannot reliably maintain HTTP-only cookies across requests (different request lifecycle than browsers)
  - Backend expected email in `req.session.resetPasswordEmail` from `/forgot-password`
- **Solution**:
  - Modified backend `/reset-password` to accept `email` in request body as fallback: `const email = req.session.resetPasswordEmail || bodyEmail`
  - Simplified Flutter app signature: `resetPasswordWithCode({code, newPassword, recoveryEmail})` (removed sessionCookie param)
  - Now sends email explicitly in JSON request body
- **Result**: Password recovery flow works across all platforms (web, mobile, desktop)
- **Files Modified**:
  - `local_docker_admin_backend/frontend-admin/server.js` (line 3817-3819)
  - `recipe_list/lib/auth/admin_session.dart` (resetPasswordWithCode function)
  - `recipe_list/lib/ui/password_recovery_page.dart` (removed sessionCookie parameter)
  - `recipe_list/lib/ui/login_page.dart` (caller updated)

## Admin auth/session flow

- Migrated recipe admin flow to bearer-token authentication (`/api/recipe-admin/login`, `/api/recipe-admin/users`).
- Persisted recipe-admin token in local `auth_credentials` storage to survive app restart/splash until explicit logout.
- Restored admin token on bootstrap and separated admin token channel from regular user token channel.
- Ensured logout clears active auth state and admin token.

## Profile routing and login UI behavior

- Fixed profile-tab routing to prioritize admin panel opening when valid admin session context is present.
- Removed recurring password re-auth modal flow.
- Kept only login / signup / password-recovery interfaces for re-authentication.
- Disabled inline logout-only mode in login screen; logout should be triggered from explicit logout action.

## Local DB/auth schema reliability

- Updated auth credentials schema handling to include and tolerate `is_admin` in all upgrade paths.
- Added idempotent migration safety for existing databases missing `is_admin`.

## Admin users list stability

- Fixed admin users list parsing path to use typed JSON response handling.
- Added better error surfacing in users page loading path for easier diagnostics.

## Feed loading reliability (web and mobile)

- Switched feed config to prefer bulk page loading by default (`/recipes/page`).
- Replaced fragile one-character search seed fallback with multi-character fallback (`"chicken"`) to avoid `prefix_too_short` empty results.

## Infra/runtime notes applied during debugging

- Added/verified CORS headers on `mahallem.ist` for browser clients (Flutter web dev origins and production origins).
- Set production recipe-admin token TTL to `31536000` seconds (365 days).

## Files touched in this update window

- `recipe_list/lib/auth/admin_session.dart`
- `recipe_list/lib/ui/login_page.dart`
- `recipe_list/lib/ui/admin_users_page.dart`
- `recipe_list/lib/data/local/recipe_db.dart`
- `recipe_list/lib/config/feed_config.dart`
- `recipe_list/lib/ui/recipe_list_loader.dart`
- `project_docs.md`
