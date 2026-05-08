# Auth: 365-day session + friendly 401 on rating

**Date:** 2026-05-07

**Commits**

- `otus_dz_2` `80e8a32` — auth: 365-day session + friendly 401 handling on rating
- `mahallem_ist` `78ee36a4` — auth: 365-day token TTLs for recipes user + admin

## Symptoms

Two production users reported the same toast on the recipe-list view
when tapping the star pill on a card:

```
Rating failed: DioException [bad response]: this exception was
thrown because the response has a status code of 401 …
```

- A regular logged-in user on the web (`recipies.mahallem.ist`).
- The admin account on the iOS Novogod release build (Flutter app).

Rating, favorites and other write actions had worked the previous
day. Both users were still rendered as logged-in by the UI.

## Root causes

Two independent defects compounded:

1. **Backend issued short-lived tokens.** In `local_user_portal/routes/auth.js`
   (the user-portal Express app):

   - `issueRecipesUserToken()` hard-coded `exp` to 30 days.
   - `RECIPE_ADMIN_TOKEN_TTL_SECONDS` defaulted to 8 hours
     (`28800`), and the prod compose file used the default.

   The admin's iPhone token therefore expired every overnight cycle;
   any regular user older than 30 days hit the same path. The
   middleware in `local_user_portal/routes/recipes.js`
   (`recipesUserAuthMiddleware` / `recipesWriteAuthMiddleware`)
   correctly returned `401 {"error":"unauthorized"}` once `exp` had
   passed.

2. **Client treated a stale login row as "logged in".** In
   `recipe_list/lib/auth/admin_session.dart`, `_setSessionState`
   flipped `userLoggedInNotifier` purely on the persisted `login`
   string:

   ```dart
   userLoggedInNotifier.value = login != null && login.isNotEmpty;
   ```

   When the token had expired or been cleared while the `login`
   row was still present, the rating widget's pre-flight guard

   ```dart
   if (!loggedIn) showRegistrationRequiredSnackBar(context);
   ```

   in `PhotoRatingPill` (`recipe_list/lib/ui/recipe_card.dart`)
   passed, the POST went out without an auth header, the backend
   returned 401, and the widget's catch leaked the raw
   `DioException` into a snackbar via
   `Text('Rating failed: $e')`.

Reproduction against prod confirmed the 401:

```sh
curl -i -X POST https://recipies.mahallem.ist/recipes/52772/rating \
     -H 'Content-Type: application/json' \
     -d '{"stars":5}'
# HTTP/2 401 ; {"error":"unauthorized"}
```

## Fixes

### Backend — `mahallem_ist`

`local_user_portal/routes/auth.js` (commit `78ee36a4`):

- Introduce `RECIPES_USER_TOKEN_TTL_SECONDS`
  (default `60 * 60 * 24 * 365` = 31_536_000).
- `issueRecipesUserToken()` uses the new env-driven TTL.
- `RECIPE_ADMIN_TOKEN_TTL_SECONDS` continues to drive the admin
  token; default bumped at the compose layer.

`local_docker_admin_backend/docker-compose.yml`:

```yaml
RECIPE_ADMIN_TOKEN_TTL_SECONDS: ${RECIPE_ADMIN_TOKEN_TTL_SECONDS:-31536000}
RECIPES_USER_TOKEN_TTL_SECONDS: ${RECIPES_USER_TOKEN_TTL_SECONDS:-31536000}
```

Container rebuilt and restarted; `process.env` confirmed
`31536000 31536000` live.

Both env vars remain overridable for shorter sessions in non-prod
environments (CI/staging/test).

### Client — `otus_dz_2`

[`recipe_list/lib/auth/admin_session.dart`](../recipe_list/lib/auth/admin_session.dart) — `_setSessionState`:

```dart
userLoggedInNotifier.value =
    login != null &&
    login.isNotEmpty &&
    (isAdmin || (token != null && token.isNotEmpty));
```

A session is "logged in" only when there are credentials backing
it: a user token (regular users), or the admin path (which carries
its own bearer in `currentRecipeAdminTokenNotifier`).

[`recipe_list/lib/ui/recipe_card.dart`](../recipe_list/lib/ui/recipe_card.dart) — `PhotoRatingPill.onTap`:

```dart
final status = e is DioException ? e.response?.statusCode : null;
if (status == 401 || status == 403) {
  await logoutAdmin();
  if (context.mounted) showRegistrationRequiredSnackBar(context);
  return;
}
```

401/403 drops the stale session via `logoutAdmin()` and shows
the localized "please register / log in" snackbar instead of the
raw exception. Non-auth failures keep the existing diagnostic
toast.

## Migration

Existing sessions whose 30-day / 8-hour tokens had already expired
must log in once more. Every login from now on is good for
**365 days** on the device (web localStorage / iOS app sqlite
mirror), with all logged-in features (favorites, ratings, owner
edit/delete) working uninterrupted within that window.

## Defense in depth

The client guard remains useful even with 365-day TTLs:

- Clock skew on the device.
- Server-side revocation (e.g. password reset).
- Future signing-secret rotation.
- Admin token (still tied to its own TTL knob) being rotated by
  the operator.

## Verification

- Web: `cd /var/www/recipie/otus_dz_2 && git pull && docker compose -f docker-compose.web.yml build flutter-web && up -d` — `Container recipe_list_web Started`.
- iOS Novogod (`00008140-0014399E0EF3001C`): `flutter build ios --release` + `xcrun devicectl device install app` — installed bundle `com.otus.recipeList`.
- Backend: `docker exec mahallem-user-portal node -e "console.log(process.env.RECIPES_USER_TOKEN_TTL_SECONDS, process.env.RECIPE_ADMIN_TOKEN_TTL_SECONDS)"` → `31536000 31536000`.
