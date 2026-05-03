# Login, Roles, and Favorites Auth Sync (client + server)

This document reflects the current shipped behavior in `recipe_list` and
its backend contract with `mahallem.ist`.

It covers:

- role-aware login UX (user vs admin)
- client session/auth state and offline mirror
- preferred language selection/persistence across signup/login/app boot
- favorites access policy (registered users only)
- favorites persistence on backend under user credentials

---

## 1) Current UX behavior

### Entry points

- Profile tab opens `LoginPage` via `openLoginPage(...)`.
- Login and signup screens use the same splash-style slide transition.
- Signup screen now includes a dedicated language chooser:
   - text: `signUpChooseLanguage` ("Choose your language"),
   - round current-language flag,
   - round cycle button showing the **next** language label (`next.label`).

Sources:
- `recipe_list/lib/ui/login_page.dart`
- `recipe_list/lib/ui/signup_page.dart`
- `recipe_list/lib/ui/password_recovery_page.dart`
- `recipe_list/lib/ui/lang_icon_button.dart`

### Login states

1. **Logged out**
    - Login/password inputs enabled.
    - Primary button: **Log in**.
    - **Forgot password?** TextButton opens the password recovery flow (validates email field first).
    - `Sign up` opens a real signup screen (`SignUpPage`); on success chains into `LoginPage` with email pre-filled.
    - `openLoginPage` accepts optional `prefillLogin` to pre-fill email (used after signup and after password reset).

2. **Logged in (regular user)**
    - Inputs disabled.
    - Primary button: **Log out**.
    - Success snackbar: `loginSuccessUser`.

3. **Logged in (admin)**
    - Same logged-in UI shell.
    - Success snackbar: `loginSuccessAdmin` (“Admin mode enabled”).
    - Admin-only actions are enabled by role.

Sources:
- `recipe_list/lib/ui/login_page.dart`
- `recipe_list/lib/i18n.dart`

---

## 2) Client auth/session state model

Source: `recipe_list/lib/auth/admin_session.dart`

### Public state

- `userLoggedInNotifier` — any authenticated user session.
- `adminLoggedInNotifier` — admin-mode session only.
- `currentUserLoginNotifier` — active login identifier.
- `currentUserTokenNotifier` — signed backend token (if online login returned it).

### Bootstrap and persistence

- On startup, `bootstrapAdminSession(...)` restores active row from
   `auth_credentials` (`active = 1`) and initializes both user/admin flags.
- During bootstrap, client also reads `preferred_language` and restores app language
  via `cycleAppLangTo(...)` before session UI becomes active.
- Admin mode is explicit: currently based on login metadata (`admin` legacy path
   and/or backend-provided admin role in online response).

### Login order

`loginAsAdmin(...)` still uses compatibility order:

1. online login against mahallem auth aliases;
2. offline login from local mirrored credentials;
3. legacy fallback `admin/admin`.

On success, client updates full session state and mirrors credentials locally.

If online login response includes `preferredLanguage`, client applies it immediately
(`cycleAppLangTo`) and persists it in local mirror (`auth_credentials.preferred_language`).

### Logout

- `logoutAdmin()` clears `active` in `auth_credentials` and resets
   user/admin/token/login notifiers.

---

## 3) Online auth + signup compatibility contract

Client probes these login paths (first 2xx wins):

- configured `MAHALLEM_AUTH_LOGIN_PATH` (default `/users/login`)
- `/users/login`
- `/auth/login`
- `/login`

Payload variants tried for compatibility:

- `{login,password}`
- `{username,password}`
- `{email,password}`
- `{user,password}`

Signup and sender use similar path/payload compatibility probing.

Expected successful login body now includes user token/role hints:

```json
{
   "success": true,
   "userId": "...",
   "email": "...",
   "token": "<signed-recipes-user-token>",
   "isAdmin": false,
   "preferredLanguage": "en"
}
```

Client extracts:

- `token` → `currentUserTokenNotifier`
- `isAdmin` / `is_admin` / `role == 'admin'` → `adminLoggedInNotifier`
- `preferredLanguage` → app locale restore (`appLang`)

Signup now sends selected language in compatibility payloads as `language`.

---

## 4) Offline credential mirror schema

Source: `recipe_list/lib/data/local/recipe_db.dart` (schema v9)

```sql
CREATE TABLE auth_credentials (
   login TEXT PRIMARY KEY,
   password_hash TEXT NOT NULL,
   token TEXT,
   active INTEGER NOT NULL DEFAULT 0,
   updated_at INTEGER NOT NULL,
   preferred_language TEXT
);
```

Mirror stores:

- login
- deterministic password hash (FNV-1a 32-bit; non-plaintext)
- last known token (nullable)
- active flag
- updated timestamp
- preferred language (`AppLang.name`, nullable)

Offline login succeeds only on exact `(login, password_hash)` match.

---

## 5) Favorites access policy and UX gate

### Access rules

- Guests (not logged in): cannot open/use favorites.
- Registered users: can toggle favorites and open favorites tab.
- Admins: same favorites rights as registered users.

### Guest UX

When guest taps heart badge or Favorites tab:

- snackbar text: `favoritesRegistrationRequired`
- action button: `Sign Up`
- action opens signup screen.

Sources:
- `recipe_list/lib/ui/recipe_card.dart`
- `recipe_list/lib/ui/recipe_list_page.dart`

---

## 6) Owner/admin edit-delete policy

- Edit/Delete actions on cards/details are visible only for:
   - recipe owner (`OwnedRecipesStore`), or
   - admin user.
- Server-side delete call remains required for actual deletion.

Source:
- `recipe_list/lib/ui/recipe_card.dart`
- `recipe_list/lib/ui/recipe_list_page.dart`

---

## 7) Favorites backend persistence (under user credentials)

### Client side

`FavoritesStore` supports remote sync when all are true:

- backend = mahallem,
- `userLoggedInNotifier == true`,
- `currentUserTokenNotifier` is non-empty.

Headers:

- `x-recipes-user-token: <token>`

Remote endpoints used by client:

- `GET /recipes/favorites?lang=<lang>` → `{ ids: [...] }`
- `POST /recipes/favorites` with `{ recipeId, lang, favorite }`

Source:
- `recipe_list/lib/auth/admin_session.dart`
- `recipe_list/lib/data/repository/favorites_store.dart`

### Server side (mahallem)

Implemented in `local_user_portal/routes/auth.js` and `routes/recipes.js`:

- login compatibility endpoint issues signed recipes-user token;
- favorites endpoints verify token and persist per-user rows in
   `recipe_user_favorites(user_id, recipe_id, lang, saved_at)`.

---

## 8) Password recovery flow

### UX

- "Forgot password?" `TextButton` is shown under the primary Login/Logout button on `LoginPage`.
- Tapping it validates that the email field is non-empty, then starts recovery.
- On success the user is routed to `PasswordRecoveryPage`.
- On `PasswordRecoveryPage` the user enters the 4-digit code from email and a new password.
- After successful reset a snackbar `passwordRecoverySaved` ("Your new password is saved") is shown and `LoginPage` opens with the email pre-filled.

Sources:
- `recipe_list/lib/ui/login_page.dart`
- `recipe_list/lib/ui/password_recovery_page.dart`

### Client auth methods

Source: `recipe_list/lib/auth/admin_session.dart`

- `requestPasswordRecovery({required String email})` → `POST /forgot-password`
  - Captures `set-cookie` from response; returns `PasswordRecoveryStartResponse` with `sessionCookie`.
- `resetPasswordWithCode({required String email, required String code, required String newPassword, required String sessionCookie})` → `POST /reset-password`
  - Sends `Cookie` header with the session cookie from step 1.

Result enums:
- `PasswordRecoveryStartResult`: `success`, `invalidEmail`, `networkError`, `serverError`
- `PasswordResetResult`: `success`, `invalidCode`, `passwordTooShort`, `sessionExpired`, `serverError`

### Backend contract (already live on production, no deployment needed)

Source: `mahallem_ist/local_user_portal/routes/auth.js`

1. `POST /forgot-password` `{ email }` → sets Express session (`resetPasswordEmail`), dispatches 4-digit code via internal email-verification service (`email-verification-api:3333/send-code`).
2. `POST /reset-password` `{ code, newPassword }` → verifies code via `email-verification-api:3333/verify-code`, updates bcrypt hash in `users` table. Session cookie ties the two requests.

---

## 9) Notes / known trade-offs

1. Compatibility probing for auth/signup/sender is still enabled to tolerate
    route/payload variants.
2. Legacy `admin/admin` fallback is still present for continuity.
3. Offline hash is continuity-oriented, not a strong KDF.
4. Remote favorites sync is best-effort with local fallback if network fails.
5. Language preference restore depends on `preferredLanguage` in online login response;
   if absent, app keeps current language.

---

## 10) Suggested hardening next

1. Remove legacy `admin/admin` once environment parity is guaranteed.
2. Reduce auth probing surface to one canonical login payload/path.
3. Add explicit token expiry/refresh contract for recipe app.
4. Add integration tests: guest gate, regular login messaging,
    favorites GET/POST with token.
