# Auth: 401-on-rating recurrence + biometric wipe (2026-05-08)

**Date:** 2026-05-08
**Reported by:** project owner, morning of 2026-05-08
**Severity:** P1 — blocks rating, favourites and admin actions for
all logged-in users; rotates the biometric session row on every
hit.
**Predecessor incident:** [auth-session-401-rating.md](auth-session-401-rating.md)
(fixed 2026-05-07; regressed within hours).

## Symptoms reported

1. **Web (admin, `recipies.mahallem.ist`)** — tapping a star pill
   on a recipe shows the raw exception toast:

   ```
   Rating failed: DioException [bad response]: this exception was
   thrown because the response has a status code of 401 …
   ```

2. **Web** — biometric login button never works (expected: web
   does not support biometric; see "Symptom 2 is by design" below).

3. **iOS app (admin, Novogod build)** — tapping rating kicks the
   user out and shows the friendly snackbar
   "this feature requires a registered user". The page that
   then renders is **not** the current `UserCardPage` — it is
   a stale variant of `AdminAfterLoginPage` rendered with
   `isAdmin == false`: the rejected-design "New password"
   `TextField` + standalone "Change password" `FilledButton`
   is back, alongside the non-admin-gated buttons ("Save admin
   login for Face ID / Fingerprint", "Edit cards") and without
   "Edit users" / "Recipes added" (those are gated on `isAdmin`).
   See ["Why the post-kick-out page shows the rejected design"](#why-the-post-kick-out-page-shows-the-rejected-design-ghost-code)
   below.

4. **iOS app** — on next launch, biometric login throws
   "no biometric data for this session".

5. The whole sequence repeats every morning, including the
   morning after [`80e8a32`](https://github.com/…/commit/80e8a32)
   shipped the "365-day session + friendly 401" fix.

## Investigation

### What actually caused this morning's 401 (corrected after triage)

Initial framing in this doc blamed the user-token TTL revert in
`bc13c91f` for the morning's outage. **That framing was wrong on
timing.** The previous day's logins were < 24 h old — well inside
even a 30-day TTL — so a 30-day cap could not have been what
expired them. The TTL revert is a real latent bug (it would have
bitten us on day 30) but it is **not the trigger of today's
incident**.

The actual trigger was the **signing-secret rotation at restart**
(see "Empty signing-secret default in compose" below). The
sequence was:

1. The compose file declared
   `RECIPE_ADMIN_TOKEN_SECRET: ${RECIPE_ADMIN_TOKEN_SECRET:-}`
   with no `RECIPES_API_SECRET` entry at all. The host `.env`
   file on prod had `RECIPE_ADMIN_TOKEN_SECRET` set but **no**
   `RECIPES_API_SECRET` (verified during this incident's
   deploy preflight).
2. Yesterday's hot-fix deploy (or any subsequent
   `docker compose up -d`) restarted the user-portal container.
   Whichever environment variable was empty at that moment fell
   through to the `'change-me'` literal in `auth.js`.
3. From that restart onward, every previously-issued bearer
   token (user, admin, biometric-stored) failed signature
   verification → server returned 401 immediately, regardless
   of the token's claimed `exp`.
4. Next time the user opened the app and tapped a star, the
   401 path fired and produced the symptoms in §1.

The TTL revert is fixed in the same commit because we were
already in the file, but it is logically a **separate latent
bug** — a tripwire that would have caused the same symptoms 30
days from now even if the secret had been stable.

### Regression introduced by the first fix attempt (Chunk 19)

About an hour after deploying the original Chunk 2 fix the web
client surfaced a fresh wave of 401s — this time on
**anonymous read** endpoints (`/recipes/page`,
`/recipes/filter`, `/recipes/visit`, `/recipes/count`). The
client is not even sending an admin/user token to these routes;
they are public.

Root cause: `RECIPES_API_SECRET` is **two unrelated things** in
the user-portal codebase, and the first fix conflated them:

1. It is the env var read by `authMiddleware` in
   `local_user_portal/routes/recipes.js` (lines 121-131), an
   *optional shared-secret gate* that sits in front of every
   `/recipes/*` request:

   ```js
   function authMiddleware(req, res, next) {
     const expected = process.env.RECIPES_API_SECRET;
     if (!expected) return next();           // gating disabled
     const got = req.get('x-recipes-token');
     if (got && got === expected) return next();
     return res.status(401).json({ error: 'unauthorized' });
   }
   ```

   In production it had always been **unset** (gate disabled).
   The Flutter client does not send `x-recipes-token` and
   should not — these endpoints are intentionally public.

2. It was *also* used in `auth.js` and `recipes.js` as a
   *fallback source* for `RECIPES_USER_TOKEN_SECRET` and
   `RECIPE_ADMIN_TOKEN_SECRET` if those weren't set. That is
   what the first-attempt compose change exploited, by making
   `RECIPES_API_SECRET` fail-fast required and using `:-`
   defaults to derive both signing keys from it.

Setting `RECIPES_API_SECRET` to fix (2) **also flipped on (1)**.
Anonymous web traffic immediately started 401-ing.

Fix (commit `bc4163c0`):

* `RECIPES_API_SECRET: ${RECIPES_API_SECRET:-}` — restored to
  optional/empty default, gate stays off in production.
* `RECIPES_USER_TOKEN_SECRET: ${…:?…must be set…}` — fail-fast
  required, **independent** of `RECIPES_API_SECRET`.
* `RECIPE_ADMIN_TOKEN_SECRET: ${…:?…must be set…}` — same.

On prod's `.env` an explicit `RECIPES_USER_TOKEN_SECRET` was
added with the **same value** that was just signing user
tokens (= the seeded `RECIPES_API_SECRET` value, which itself
equalled `RECIPE_ADMIN_TOKEN_SECRET`), so any user token
issued in the gap between the first deploy and the regression
fix continues to verify. The `RECIPES_API_SECRET=…` line in
`.env` was commented out. Smoke test:

```
GET /recipes/page    → 200
GET /recipes/filter  → 200
GET /recipes/count   → 200
```

Lesson: `RECIPES_API_SECRET` is a misleading name. It should
have been `RECIPES_API_GATE_TOKEN` from the start. The signing
keys (`RECIPES_USER_TOKEN_SECRET`, `RECIPE_ADMIN_TOKEN_SECRET`)
were always meant to be independent and they now are.

### How `bc13c91f` happened (separate process bug)

Walking the `mahallem_ist` history of `local_user_portal/routes/auth.js`:

```
git log 78ee36a4..HEAD -- local_user_portal/routes/auth.js
bc13c91f auth: auto-detect resetPasswordScope when session cookie is missing
```

The unrelated reset-password-scope commit `bc13c91f`, made
roughly 40 minutes after the TTL fix `78ee36a4`, **silently
reverted the TTL fix** in the same file:

```diff
-  const RECIPES_USER_TOKEN_TTL_SECONDS = Number(process.env.RECIPES_USER_TOKEN_TTL_SECONDS || 60 * 60 * 24 * 365);
…
-      exp: Math.floor(Date.now() / 1000) + RECIPES_USER_TOKEN_TTL_SECONDS,
+      exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30, // 30 days
```

Cause (owned by the agent): the working tree on this dev
machine (Mac mini) was behind `origin/main` — the TTL fix
`78ee36a4` had landed on the remote but had not been pulled
here. When I edited `auth.js`, VS Code surfaced a "file has
changed on disk; the version in the editor is older —
overwrite?" warning, and the save proceeded anyway, writing
the stale in-editor buffer over the newer on-disk file. That
is what silently re-introduced the hard-coded 30-day `exp`.
The author of `bc13c91f` is `root <root@mahallem.ist>` because
this checkout's git identity is configured that way (it was
bootstrapped from a prod tarball); the commit was not made on
the prod host. The laptop has been offline for ~1 week and is
expected to remain offline another 1–2 weeks, so it played
no part in this incident. The true antipattern was
**dismissing a "file changed on disk" warning instead of
re-reading the file and reapplying the edit on top of current
contents**. Process change in §3 below makes this physically
impossible to repeat.

The admin-token TTL was not reverted in the source (still env-driven
via `RECIPE_ADMIN_TOKEN_TTL_SECONDS`), but two compounding factors
make the admin token expire anyway:

* **Empty signing-secret default in compose.** Before this fix:

  ```yaml
  RECIPE_ADMIN_TOKEN_SECRET: ${RECIPE_ADMIN_TOKEN_SECRET:-}
  ```

  with neither `RECIPES_USER_TOKEN_SECRET` nor `RECIPES_API_SECRET`
  plumbed in. If the host environment did not export the secret
  at the moment a `docker compose up -d` ran, the secret silently
  fell through to `'change-me'` (`auth.js` line 51-54), invalidating
  every previously-signed bearer token. A morning-of redeploy is
  enough to trigger that.

* **No re-login since 2026-05-07.** Tokens issued before the TTL
  fix are still capped at 8 h (admin) or 30 d (user). The doc
  explicitly required one re-login; admins who didn't re-login
  kept rolling expired tokens.

### Why the client surfaced different things on web vs app

Both platforms run the same Dart code in `recipe_card.dart`'s
`PhotoRatingPill`. The web bundle on prod served a build older
than commit [`80e8a32`](../recipe_list/lib/ui/recipe_card.dart),
so the friendly catch was missing → raw `DioException` toast.
The iOS Novogod build (rebuilt 2026-05-07) had the catch, hence
the friendly snackbar.

Confirmed by inspecting the build pipeline: yesterday's deploy
note mentioned the iOS install step but did not log a
`docker compose -f docker-compose.web.yml build flutter-web` for
the web container — the web image was last rebuilt before
`80e8a32`.

### Why biometric stops working after a kick-out

`logoutAdmin()` defaults to `clearSavedSession: true`, which
nulls the `token` column in `auth_credentials`:

```dart
// recipe_list/lib/auth/admin_session.dart line 332
Future<void> logoutAdmin({bool clearSavedSession = true}) async {
  …
  if (clearSavedSession) {
    values['token'] = null;        // ← wipes biometric blob
  }
  …
}
```

The friendly-401 catch added yesterday in `PhotoRatingPill`
called `logoutAdmin()` with the default — every 401 erased the
saved token. `hasSavedBiometricSession()` then returned false,
producing "no biometric data for this session" on the next
app start.

Net effect of yesterday's fix: it converted a one-shot 401 toast
into a permanent biometric break.

### Why the post-kick-out page shows the rejected design (ghost code)

User correction: the page that renders after the 401-induced
logout is **not** the redesigned `UserCardPage` — it is a
stale variant of `AdminAfterLoginPage`:

- A standalone "New password" `TextField`.
- A standalone "Change password" `FilledButton`.
- Non-admin-gated buttons that survive `isAdmin == false`
  ("Save admin login for Face ID / Fingerprint", "Edit cards").
- "Edit users" / "Recipes added" are missing — those *are*
  gated on `isAdmin`.

Both the `if (!isAdmin) { New password TextField; Change
password FilledButton }` block in
[`recipe_list/lib/ui/admin_after_login_page.dart`](../recipe_list/lib/ui/admin_after_login_page.dart)
and its supporting state (`_newPasswordController`,
`_newPasswordObscured`, `_changingPassword`,
`_submitNewPassword`) were the **rejected design** from the
first password-change iteration. Commit `86d49c4`
("profile: gate New password field on edit mode, submit via
Save") moved password change into `UserCardPage`'s edit-mode
Save flow but only edited `user_card_page.dart`. The
`AdminAfterLoginPage` half of the same redesign was never
deleted — it lived on as dead code, gated by `if (!isAdmin)`
which never triggered while the page was on screen for an
admin.

How a non-admin actually reaches this page (the bug):

1. Admin logs in via `LoginPage`.
   `openAdminAfterLoginPage(replaceCurrent: true)` pushes
   `AdminAfterLoginPage` onto the Navigator stack.
2. Admin navigates to the Recipes tab and taps a star pill.
3. Backend returns 401. The pill's catch (commit `80e8a32`)
   calls `logoutAdmin()`, flipping
   `adminLoggedInNotifier=false` and `userLoggedInNotifier=false`.
4. The pushed `AdminAfterLoginPage` is *still on top of the
   Navigator stack* — `_ProfileBranchRoot`'s GoRouter rebuild
   happens underneath it, so the user never sees the
   `LoginPage` it would route to.
5. `AdminAfterLoginPage`'s inner
   `ValueListenableBuilder<bool>(valueListenable: adminLoggedInNotifier)`
   rebuilds with `isAdmin=false` and renders the dead
   `if (!isAdmin) { … }` branch — i.e. the rejected design.

The page was implicitly assuming "I am only ever mounted for
an admin", and the dead branch was a never-reached
`!isAdmin` fallback. Once the rating-pill 401 catch started
flipping the notifier with the page on top of the stack,
the never-reached fallback became user-visible.

### Fix for the ghost

`recipe_list/lib/ui/admin_after_login_page.dart`:

1. Delete the entire `if (!isAdmin) { … }` block (Divider +
   "Change password" header + `TextField` + submit button).
2. Delete the supporting state members
   `_newPasswordController`, `_newPasswordObscured`,
   `_changingPassword` and the `_submitNewPassword()` handler.
3. Add an `adminLoggedInNotifier` listener that
   `popUntil((r) => r.isFirst)` whenever the notifier flips to
   `false` while the page is mounted. The page is admin-only
   by contract; if the contract is violated it should
   disappear, exposing whatever is below (`_ProfileBranchRoot`,
   which then routes to `LoginPage` / `UserCardPage` based on
   the post-logout notifier values).

After this change there is no rejected-design code path left
in the binary; the only password-change UI that survives is
`UserCardPage`'s unified edit-mode flow (commit `86d49c4`).

### Symptom 2 (web biometric) — gap, not "by design"

The web build currently short-circuits both code paths:

```dart
// recipe_list/lib/ui/login_page.dart
'Biometric session save is not supported in web mode.'
'Biometric authentication is not supported in web mode.'
```

This was a shortcut, not a product decision. The product line is
feature parity across web / PWA / iOS / Android. Web has had a
standards-based biometric primitive for years
(WebAuthn / passkeys via the Credential Management API), and on
iOS Safari + macOS Safari + Chrome it ends up using exactly the
same Face ID / Touch ID prompt as the native app.

**Action — tracked as a follow-up below**, not in this incident
patch: wire web biometric login through WebAuthn / passkey:

1. Server: add `POST /recipes/auth/passkey/register-options`,
   `…/register-finish`, `…/sign-options`, `…/sign-finish`
   (libraries: `@simplewebauthn/server`). Store credentials in
   a new `recipe_app_users_passkeys` table keyed on user id +
   credential id.
2. Client (web): use `package:webauthn` (or `dart:js_interop`
   straight to `navigator.credentials.create / get`) when
   `kIsWeb`. Replace the "not supported in web mode" snackbars
   in `login_page.dart` with the same biometric flow we run on
   iOS — different transport (passkey assertion → bearer
   exchange) but same UX.
3. Native (iOS/Android): no change to the existing
   `local_auth` + saved-session flow. Optionally migrate to the
   passkey transport later for cross-device sync.

This is a multi-day feature, not a fix for today's outage. Do
not block the bearer-token deploy on it.

## Fixes (this incident)

### 1. Backend — re-apply TTL fix and pin signing secrets

`mahallem_ist/local_user_portal/routes/auth.js`:

```js
const RECIPES_USER_TOKEN_TTL_SECONDS = Number(
  process.env.RECIPES_USER_TOKEN_TTL_SECONDS || 60 * 60 * 24 * 365,
);
…
exp: Math.floor(Date.now() / 1000) + RECIPES_USER_TOKEN_TTL_SECONDS,
```

`mahallem_ist/local_docker_admin_backend/docker-compose.yml`:

```yaml
# Token signing secrets. MUST be set explicitly in the host
# env (or .env file) so the value survives container rebuilds
# — otherwise every restart silently rotates the secret and
# invalidates every previously-issued bearer token.
RECIPES_API_SECRET: ${RECIPES_API_SECRET:?RECIPES_API_SECRET must be set in host env}
RECIPES_USER_TOKEN_SECRET: ${RECIPES_USER_TOKEN_SECRET:-${RECIPES_API_SECRET}}
RECIPE_ADMIN_TOKEN_SECRET: ${RECIPE_ADMIN_TOKEN_SECRET:-${RECIPES_API_SECRET}}
RECIPE_ADMIN_TOKEN_TTL_SECONDS: ${RECIPE_ADMIN_TOKEN_TTL_SECONDS:-31536000}
RECIPES_USER_TOKEN_TTL_SECONDS: ${RECIPES_USER_TOKEN_TTL_SECONDS:-31536000}
```

The `:?` form makes `docker compose up` **fail loudly** if the
host hasn't exported `RECIPES_API_SECRET`, so a deploy can never
again silently restart the user-portal with `'change-me'` as the
signing secret.

### 2. Client — preserve the biometric blob on 401

`recipe_list/lib/ui/recipe_card.dart`, `PhotoRatingPill.onTap`:

```dart
if (status == 401 || status == 403) {
  // Drop the active session so the next tap routes through
  // the login flow, but keep the saved-session row intact so
  // biometric login still works after the user re-authenticates.
  await logoutAdmin(clearSavedSession: false);
  if (context.mounted) showRegistrationRequiredSnackBar(context);
  return;
}
```

`logoutAdmin(clearSavedSession: false)` flips `active=0` but
preserves the `token` column. `hasSavedBiometricSession()`
continues to return true; on next launch the user gets the
biometric prompt → `loginWithSavedTokenSession()` restores the
token row → if that token is still rejected, the user lands at
the login page with their email pre-filled instead of a blank
"no biometric data" wall.

### 3. Client — delete the rejected-design ghost on `AdminAfterLoginPage`

`recipe_list/lib/ui/admin_after_login_page.dart`:

- Removed the dead `if (!isAdmin) { … }` block (standalone
  "New password" `TextField` + "Change password"
  `FilledButton`) — leftover from the first password-change
  iteration that was superseded by `UserCardPage`'s unified
  Save flow in commit `86d49c4`.
- Removed the supporting state
  (`_newPasswordController`, `_newPasswordObscured`,
  `_changingPassword`) and the `_submitNewPassword` handler.
- Added an `adminLoggedInNotifier` listener that pops the page
  whenever the admin context is lost while the page is mounted
  (`Navigator.popUntil((r) => r.isFirst)`). The page is
  admin-only by contract; on contract violation it disappears
  and `_ProfileBranchRoot` re-routes to `LoginPage` /
  `UserCardPage`.

### 3a. Client — admin-session-loss diagnostic channel + snackbar

Motivation: "admin context is lost" was a silent state flip;
the next time it kicks a user out in the wild we want full
forensic detail without attaching a debugger.

[`recipe_list/lib/auth/admin_session.dart`](../recipe_list/lib/auth/admin_session.dart):

- `class AdminSessionLossEvent { reason, statusCode,
  requestMethod, requestPath, responseBody, errorType,
  errorMessage, stackTrace, at, toDiagnosticString(),
  toShortString() }`.
- `final ValueNotifier<AdminSessionLossEvent?> adminSessionLossNotifier`.
- `_publishAdminSessionLoss(event)` writes the multi-line
  diagnostic dump to `dart:developer` (`name: 'admin_session'`,
  `level: 900`) and updates the notifier.
- `logoutAdmin` gained an optional `AdminSessionLossEvent? lossEvent`
  parameter; publishes after the state flip.

[`recipe_list/lib/ui/recipe_card.dart`](../recipe_list/lib/ui/recipe_card.dart)
— `PhotoRatingPill.onTap` 401/403 catch now builds an
`AdminSessionLossEvent` with `requestMethod` / `requestPath`
from `DioException.requestOptions`, `responseBody` from
`dioErr?.response?.data?.toString()`, plus error type /
message / stack trace, and passes it into `logoutAdmin`.

[`recipe_list/lib/ui/admin_after_login_page.dart`](../recipe_list/lib/ui/admin_after_login_page.dart)
— `_handleAdminLoggedInChanged` reads
`adminSessionLossNotifier.value` *before* popping and calls
`_showSessionLossSnackBar(loss)`:

- Headline: `Admin session ended: <reason> | HTTP <status> |
  <METHOD> <path> | <ErrorType>`.
- Duration: 12 s (long enough to read before the page pops).
- Action: **Copy details** — `Clipboard.setData(...)` with the
  full multi-line dump, then a 2 s confirmation toast.
- Mirror: same dump goes to `dart:developer`
  (`name: 'admin_after_login_page'`, `level: 900`) so it shows
  up in `flutter logs` / Xcode console / browser devtools /
  `adb logcat` even if the user never taps Copy.

All other `logoutAdmin` callers publish a deliberate
`reason: 'User tapped Logout in …'` event so no flip is silent
(`AdminAfterLoginPage._logout`, `LoginPage._logout`,
`UserCardPage._handleLogout`).

### 4. Process — guardrails to stop the next silent revert

The actual mechanism that produced `bc13c91f` was an editor
buffer that predated the on-disk file. The new agent rules:

* **First action of any session in a repo:** `git status &&
  git log --oneline -3 && git fetch && git status -sb`. If
  the working tree is behind `origin`, `git pull --ff-only`
  before any edit. Dev machines are sometimes offline or
  sit unused for days/weeks; never assume the local checkout
  matches origin without checking.
* **Re-read every file immediately before editing it**, even
  if the agent read it earlier in the session. Prefer
  surgical `replace_string_in_file` with ≥ 5 lines of context
  — it fails loudly if the file has drifted, which is the
  signal we want.
* **A "file has changed on disk / newer version in workspace"
  dialog from VS Code is a hard stop.** Never overwrite.
  Discard the buffer, re-read the file, reapply the edit on
  top of current contents.
* **After every edit:** `git diff --stat <file>` and
  `git diff <file> | grep '^-[^-]'`. If deletions are not
  exactly what was intended, revert and redo on top of the
  current file.
* Add a regression test in
  `mahallem_ist/local_user_portal/tests/auth-token-ttl.test.js`
  that asserts `issueRecipesUserToken` honours
  `RECIPES_USER_TOKEN_TTL_SECONDS` and that no hard-coded
  30-day TTL appears in `auth.js`. Source-grep style so it
  runs without the db / redis / http stack. CI on the dev
  machine
  would have caught `bc13c91f` before push.

## Verification checklist

Backend (`mahallem_ist`):

```sh
cd /root/mahallem/mahallem_ist
git pull
cd local_docker_admin_backend
# Required for compose; fail-fast if missing.
export RECIPES_API_SECRET="$(grep ^RECIPES_API_SECRET= .env | cut -d= -f2)"
docker compose build user-portal
docker compose up -d user-portal
docker exec mahallem-user-portal node -e "
  console.log('user TTL', process.env.RECIPES_USER_TOKEN_TTL_SECONDS);
  console.log('admin TTL', process.env.RECIPE_ADMIN_TOKEN_TTL_SECONDS);
  console.log('user secret set:', Boolean(process.env.RECIPES_USER_TOKEN_SECRET || process.env.RECIPES_API_SECRET));
"
# Expect: 31536000  31536000  user secret set: true
```

Web (`otus_dz_2`):

```sh
cd /var/www/recipie/otus_dz_2
git pull
docker compose -f docker-compose.web.yml build flutter-web
docker compose -f docker-compose.web.yml up -d flutter-web
```

Then re-login once on each device and confirm:

- Rating a recipe returns 200 OK and updates the pill.
- iOS biometric still works after a 401 is artificially induced
  (e.g. clearing the row server-side).
- Web no longer surfaces the raw `DioException` toast.

## Defense-in-depth still applicable

The 401 catch in `PhotoRatingPill` remains the primary client
defense: it stops the raw exception text from ever leaking into
a snackbar even if a future migration produces a real auth
failure. The change here only narrows the side-effect (do not
nuke the biometric blob).

## Open follow-ups

- iOS rebuild + re-install on `00008140-0014399E0EF3001C` and
  `00008120-000E459E2E50A01E` after this commit lands.
- **Web biometric parity (WebAuthn / passkey).** Bring web up
  to the same biometric login UX as iOS / Android. Spec'd above
  in "Symptom 2 — gap, not by design". Multi-day chunk; new
  doc when the work starts.
- **In-place re-auth on 401.** When a write-action (rating,
  favourite, owner edit/delete) returns 401, surface an inline
  re-auth bottom sheet, then retry the original action — do not
  unmount admin tiles, do not navigate. This is the right fix
  for symptom 3; today's patch only blunts the side-effect.
- Add a smoke test to `mahallem_ist/tests/auth.test.js` that
  asserts `issueRecipesUserToken` honours `RECIPES_USER_TOKEN_TTL_SECONDS`
  — this would have caught `bc13c91f` in CI.
- Wire `loginWithSavedTokenSession()` to refresh-probe
  `/recipes/users/me` on restore; if the token is rejected,
  route to the password login with the email pre-filled rather
  than silently restoring a dead session.
- Treat "file changed on disk / newer version" dialogs from
  VS Code as a hard stop, on every dev machine. Never
  overwrite. The two paste-overwrite commits that caused this
  incident (`9682d4bf`, `bc13c91f`) both happened that way —
  the dialog appeared and was dismissed.
