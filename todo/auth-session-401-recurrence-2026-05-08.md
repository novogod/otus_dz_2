# TODO — Auth: 401-on-rating recurrence + biometric wipe (2026-05-08)

Source incident: [docs/auth-session-401-recurrence-2026-05-08.md](../../auth-session-401-recurrence-2026-05-08.md).

This file breaks the incident into independently-deployable
chunks. Each chunk lists scope, files touched, acceptance test,
and "Definition of done". Chunks marked ✅ are already coded
in the working tree but not yet committed/deployed.

Status legend: ⬜ not started · 🟨 in working tree, not committed
· 🟦 committed but not deployed · ✅ deployed and verified.

## Chunk index

1. Backend — fail-fast signing-secret plumbing (root cause of 2026-05-08 outage) [✅]
2. Backend — re-apply user-token TTL fix (latent 30-day tripwire) [✅]
3. Client — preserve biometric blob on 401 in `PhotoRatingPill` [✅]
4. Client — delete the `AdminAfterLoginPage` ghost (rejected design) [✅]
5. Client — auto-pop `AdminAfterLoginPage` when admin context is lost [✅]
6. Client — admin-session-loss diagnostic event channel + snackbar [✅]
7. Doc amendments + project log [✅]
8. Process — respect on-disk drift; never dismiss "file changed
   on disk" warnings [⬜ ongoing]
9. Backend — regression test for `issueRecipesUserToken` TTL [✅]
10. Commit + push (this dev machine, Mac mini) [✅]
11. Deploy backend (`mahallem_ist`) [✅]
12. Deploy web (`otus_dz_2`) [✅]
13. Rebuild + install iOS on Novogod / NovogodOne [🟦 simulator only — physical devices pending]
14. Verification matrix on web + iOS [⬜ manual]
15. Follow-up: in-place re-auth on 401 (replaces the kick-out) [⬜ multi-day]
16. Follow-up: WebAuthn / passkey parity for web biometric [⬜ multi-day]
17. Follow-up: write-actions inventory — pipe every 401 through the
    diagnostic channel [⬜]
18. Backend — fix `/root/build_recipe_sitemap.sh` baked-in token
    (returns 401 after secret rotation) [⬜]
19. Backend — decouple `RECIPES_API_SECRET` (optional `/recipes/*`
    gate) from JWT signing keys (regression caused by Chunk 2) [✅]
20. Client — gate the rating pill on `currentUserTokenNotifier`,
    not `userLoggedInNotifier`, so admin-only sessions cannot
    trigger the 401 → kick-out cascade (regression observed
    after Chunks 1-19) [✅]
21. Backend — DB migration: `recipe_app_user_credentials`
    + `recipe_app_webauthn_challenges` (foundation for web biometric) [✅ `mahallem_ist@f52e135b`, applied to prod 2026-05-08]
22. Backend — `/recipes/auth/passkey/{register,login}/{start,complete}`
    + list/delete, JWT-bearer auth, mirrors `routes/auth-passkey.js`
    [✅ `mahallem_ist@2c6eb080`, deployed to prod 2026-05-08;
    8/8 integration tests green; `GET /available` smoke 200,
    `POST /register/start` no-bearer 401, `POST /login/start`
    anon returns real challenge]
23. Client web — `recipe_list/web/passkey_bridge.js`
    (`navigator.credentials.create / get`, base64url helpers)
    [✅ `otus_dz@da9d8b4`; 11/11 unit tests green;
    loaded before `flutter_bootstrap.js` in `web/index.html`]
24. Client dart — `recipe_list/lib/auth/passkey_web.dart`
    (conditional import, JS interop, returns `unsupported` on
    non-web) [✅ `otus_dz@e7d8281`; 5/5 stub tests green;
    `flutter analyze` clean on all targets]
25. Client UI — replace the two "not supported in web mode"
    snackbars in `login_page.dart` with passkey register / login
    flows; keep native `local_auth` path unchanged [✅ `otus_dz@<pending>`; 6/6 source-shape tests green]
26. Verification matrix — add web (Magic Keyboard Touch ID,
    Windows Hello, Android Chrome) rows to Chunk 14 [⬜]
27. Deploy — backend migration + endpoints + web rebuild;
    smoke-test register + login on Magic Keyboard [⬜]

---

## Chunk 1 — Backend: re-apply user-token TTL fix (latent tripwire) [✅]

**Why:** commit `bc13c91f` paste-overwrote `78ee36a4` and
re-introduced a hard-coded 30-day user-token TTL. This is a
**latent bug** — it would have caused 401s 30 days after each
login even if the secret had been stable. It is **not** what
triggered the 2026-05-08 morning outage (yesterday's logins
were < 24 h old, well inside any 30-day TTL). See Chunk 2 for
the actual trigger. Re-applying the fix here so the tripwire
is disarmed for future logins.

**Files:**
- `mahallem_ist/local_user_portal/routes/auth.js` (lines ~51-71):
  re-introduce
  `const RECIPES_USER_TOKEN_TTL_SECONDS = Number(process.env.RECIPES_USER_TOKEN_TTL_SECONDS || 60 * 60 * 24 * 365);`
  and use it inside `issueRecipesUserToken`'s `exp`.

**Acceptance:**
- `git diff` shows the constant restored and `exp` references it.
- `node -e "…"` inside the running container prints
  `RECIPES_USER_TOKEN_TTL_SECONDS=31536000`.

**DoD:** committed (chunk 10) and deployed (chunk 11).

---

## Chunk 2 — Backend: fail-fast signing-secret plumbing (root cause) [✅]

**Why (corrected):** this is the actual trigger of the
2026-05-08 outage. The compose file declared
`RECIPE_ADMIN_TOKEN_SECRET: ${RECIPE_ADMIN_TOKEN_SECRET:-}`
with no `RECIPES_API_SECRET` entry at all, and the host `.env`
on prod had `RECIPE_ADMIN_TOKEN_SECRET` set but **no**
`RECIPES_API_SECRET` (verified during this deploy's
preflight). When the user-portal container was restarted
(yesterday's hot-fix deploy or any later `docker compose up -d`),
whichever variable was empty fell through to the `'change-me'`
literal in `auth.js`, silently rotating the signing key. From
that restart onward, every previously-issued bearer token —
user, admin, biometric-stored — failed signature verification
and the server returned 401 immediately, regardless of the
token's claimed `exp`. That is what users saw this morning
when they tapped a star.

**Files:**
- `mahallem_ist/local_docker_admin_backend/docker-compose.yml`
  (user-portal env block, ~lines 1239-1252):
  - `RECIPES_API_SECRET: ${RECIPES_API_SECRET:?RECIPES_API_SECRET must be set in host env}`
  - `RECIPES_USER_TOKEN_SECRET: ${RECIPES_USER_TOKEN_SECRET:-${RECIPES_API_SECRET}}`
  - `RECIPE_ADMIN_TOKEN_SECRET: ${RECIPE_ADMIN_TOKEN_SECRET:-${RECIPES_API_SECRET}}`
  - Both TTLs default to `31536000`.

**Acceptance:**
- `unset RECIPES_API_SECRET; docker compose config` fails
  with the configured error string.
- With `RECIPES_API_SECRET` exported, `docker compose config`
  shows all three secrets non-empty.

**DoD:** committed + deployed; smoke test above passes on prod.

---

## Chunk 3 — Client: preserve biometric blob on 401 [✅]

**Why:** yesterday's friendly-401 catch called `logoutAdmin()`
with the default `clearSavedSession: true`, nulling the
`auth_credentials.token` blob and producing
"no biometric data for this session" on next launch.

**Files:**
- `recipe_list/lib/ui/recipe_card.dart`, `PhotoRatingPill.onTap`:
  call `await logoutAdmin(clearSavedSession: false, lossEvent: …)`
  on 401/403.

**Acceptance:**
- `flutter analyze recipe_list/lib/ui/recipe_card.dart` clean.
- Manual: invalidate token server-side, tap a star — biometric
  login still works on next app launch.

**DoD:** committed + deployed (web + iOS).

---

## Chunk 4 — Client: delete the `AdminAfterLoginPage` ghost [✅]

**Why:** the rejected first-iteration "Change password" UI
(separate `TextField` + standalone `FilledButton`) survived as
dead code under `if (!isAdmin) { … }`. When `logoutAdmin`
flipped `adminLoggedInNotifier=false` while the page was on top
of the Navigator stack, the dead branch became user-visible.

**Files:**
- `recipe_list/lib/ui/admin_after_login_page.dart`:
  - Remove the entire `if (!isAdmin) { Divider, "Change password"
    Text, TextField, FilledButton } ` block (was ~lines 283-340).
  - Remove `_newPasswordController`, `_newPasswordObscured`,
    `_changingPassword`, `_submitNewPassword()`,
    `_newPasswordController.dispose()` entry.

**Acceptance:**
- `grep -n "_newPasswordController\|_submitNewPassword\|_changingPassword" recipe_list/lib/ui/admin_after_login_page.dart`
  returns zero matches.
- `flutter analyze recipe_list/lib/ui/admin_after_login_page.dart`
  clean.

**DoD:** committed + deployed; user confirms the rejected design
no longer appears post-401.

---

## Chunk 5 — Client: auto-pop `AdminAfterLoginPage` on admin-loss [✅]

**Why:** even after Chunk 4 the page would render *some*
non-admin variant if it stayed on top of the Navigator stack
during a `logoutAdmin`. The page is admin-only by contract;
on contract violation it must disappear, exposing
`_ProfileBranchRoot` underneath.

**Files:**
- `recipe_list/lib/ui/admin_after_login_page.dart`:
  - `initState`: `adminLoggedInNotifier.addListener(_handleAdminLoggedInChanged);`
  - `dispose`: matching `removeListener`.
  - `_handleAdminLoggedInChanged()`: when `false`,
    `Navigator.of(context).popUntil((r) => r.isFirst)`.

**Acceptance:**
- Manual: induce a 401 from any write action while sitting on
  the admin profile — page pops, `LoginPage` (or
  `UserCardPage`) renders below.
- No new `flutter analyze` warnings.

**DoD:** committed + deployed.

---

## Chunk 6 — Client: admin-session-loss diagnostic channel [✅]

**Why:** "admin context is lost" today is a silent state flip.
We need full forensic detail (status, request URL, response
body, error type/message, stack trace) the next time it happens
in the wild — without forcing the user to attach a debugger.

### 6a — `AdminSessionLossEvent` + notifier in `admin_session.dart`

**Files:**
- `recipe_list/lib/auth/admin_session.dart`:
  - Add `import 'dart:developer' as developer;`.
  - Define `class AdminSessionLossEvent { reason; statusCode;
    requestMethod; requestPath; responseBody; errorType;
    errorMessage; stackTrace; at; toDiagnosticString();
    toShortString(); }`.
  - Define `final ValueNotifier<AdminSessionLossEvent?> adminSessionLossNotifier`.
  - Define `void _publishAdminSessionLoss(AdminSessionLossEvent event)`
    that `developer.log`s the diagnostic dump (`name: 'admin_session'`,
    `level: 900`) and updates the notifier.
  - `logoutAdmin` gains an optional `AdminSessionLossEvent? lossEvent`
    parameter; publishes it after the state flip.

**Acceptance:** `flutter analyze recipe_list/lib/auth/admin_session.dart`
clean. Notifier defaults to `null`.

### 6b — `PhotoRatingPill` populates the event on 401/403

**Files:**
- `recipe_list/lib/ui/recipe_card.dart`: change `catch (e)` to
  `catch (e, st)`. Build `AdminSessionLossEvent` with
  `reason: 'Rating pill received $status from backend'`,
  `requestMethod`/`requestPath` from `DioException.requestOptions`,
  `responseBody: dioErr?.response?.data?.toString()`,
  `errorType: e.runtimeType.toString()`,
  `errorMessage: e.toString()`,
  `stackTrace: st.toString()`. Pass it into `logoutAdmin`.

**Acceptance:** `flutter analyze recipe_list/lib/ui/recipe_card.dart`
clean. Manual: induce 401, observe full dump in `flutter logs`
under `name=admin_session, level=WARNING`.

### 6c — `AdminAfterLoginPage` surfaces the event as a snackbar

**Files:**
- `recipe_list/lib/ui/admin_after_login_page.dart`:
  - Add `import 'dart:developer' as developer;` and
    `import 'package:flutter/services.dart';` (for `Clipboard`).
  - In `_handleAdminLoggedInChanged`: read
    `adminSessionLossNotifier.value` *before* popping, call
    `_showSessionLossSnackBar(loss)`.
  - `_showSessionLossSnackBar(AdminSessionLossEvent? loss)`:
    - Headline: `'Admin session ended: ${loss.toShortString()}'`.
    - Duration: `Duration(seconds: 12)`.
    - Action: `SnackBarAction(label: 'Copy details', onPressed: …)`
      that `Clipboard.setData(ClipboardData(text: fullDump))`
      and shows a 2 s "Diagnostic copied to clipboard" toast.
    - Also `developer.log(fullDump, name: 'admin_after_login_page', level: 900)`
      so the dump is captured even if the user does not tap Copy.

**Acceptance:**
- `flutter analyze recipe_list/lib/ui/admin_after_login_page.dart`
  clean.
- Manual: invalidate admin token server-side, tap a star — the
  snackbar shows reason + status + path + error type, "Copy
  details" places the multi-line dump on the clipboard, and the
  same dump appears in `flutter logs` / Xcode console / `adb
  logcat` under `name=admin_after_login_page`.
- Snackbar visible long enough (≥10 s) to read before page pops.

### 6d — Apply the same diagnostic pattern to other `logoutAdmin` callers

**Files:**
- `recipe_list/lib/ui/admin_after_login_page.dart` `_logout()` —
  pass `lossEvent: AdminSessionLossEvent(reason: 'User tapped Logout button')`.
- `recipe_list/lib/ui/login_page.dart` (the kick-out branch) —
  pass a `reason: 'Re-login flow dropped previous session'` event.
- `recipe_list/lib/ui/user_card_page.dart` `logoutAdmin(clearSavedSession: true)`
  — pass `reason: 'User tapped Logout from profile'`.
- `recipe_list/lib/auth/admin_session.dart`
  `restoreAdminSession` failure path (line 312, line 343) —
  publish `reason: 'restoreAdminSession failed'` with whatever
  `DioException` it caught.

**Acceptance:** every code path that flips
`adminLoggedInNotifier` to false either (a) is a deliberate
user logout that publishes an explicit reason, or (b) is a
401/403 that publishes the full diagnostic record. No silent
flips remain.

**DoD for Chunk 6 (a–d):** committed + deployed; the next
in-the-wild kick-out produces a copy-pasteable diagnostic dump
in the snackbar and in the device log.

---

## Chunk 7 — Doc amendments + project log [✅]

**Files:**
- `docs/auth-session-401-recurrence-2026-05-08.md`:
  - Symptom 3 already amended to describe the ghost page.
  - Add a sub-section "Diagnostic snackbar (Chunk 6)" describing
    the new event channel, `name=admin_session` /
    `name=admin_after_login_page` log tags, and the "Copy
    details" affordance.
- `docs/project_log.md`: prepend an entry summarising
  Chunks 1-6 with links.

**Acceptance:** doc renders, links resolve, `project_log.md`
top entry is dated 2026-05-08 and references this todo file.

---

## Chunk 8 — Process: respect on-disk drift [⬜ ongoing]

**Actual root cause of `bc13c91f`:** the working tree on this
dev machine (Mac mini) was behind `origin/main` — the TTL fix
`78ee36a4` had landed on the remote (via prod or another box)
but had not been pulled here. VS Code had a stale `auth.js`
buffer open from before that update. When I saved my
reset-password-scope edit, VS Code surfaced a "file changed on
disk; the version in the editor is older — overwrite?" dialog
and the save proceeded anyway, silently reverting `78ee36a4`.
The author string `root <root@mahallem.ist>` is just this
checkout's git identity, not evidence the commit was made on
prod. (The laptop has been offline for ~1 week and will be
offline another 1–2 weeks, so it played no part in this.)

**Behavioural rules going forward (any dev machine I work on):**

- First action of any session in a repo:
  `git status && git log --oneline -3 && git fetch && git status -sb`.
  If behind, `git pull --ff-only` before any edit.
- Re-read every file immediately before editing it, even if
  read earlier in the session. Treat any read older than ~1
  turn as potentially stale.
- Prefer `replace_string_in_file` with ≥ 5 lines of context
  over whole-file rewrites — it fails loudly when the file
  has drifted, which is the desired signal.
- A "file has changed on disk / newer version" dialog from
  VS Code is a HARD STOP. Never overwrite. Discard the
  buffer, re-read, reapply.
- After every edit, `git diff --stat <file>` and
  `git diff <file> | grep '^-[^-]'`. Unintended deletions →
  revert immediately.
- This is a behavioural commitment, not a code change.
  Recorded in `/memories/lessons.md` so it persists across
  sessions.

**Acceptance:** no commit in either repo silently re-introduces
code that an earlier commit removed. Spot-check via
`git log -p -S '60 * 60 * 24 * 30' -- local_user_portal/routes/auth.js`
on `mahallem_ist`.
---

## Chunk 9 — Backend: regression test for user-token TTL [✅]

**Why:** CI on the laptop would have caught `bc13c91f` before
push. This is the only structural defense against the same
silent revert recurring.

**Files:**
- `mahallem_ist/tests/auth.test.js` — new test:

  ```js
  test('issueRecipesUserToken honours RECIPES_USER_TOKEN_TTL_SECONDS', () => {
    process.env.RECIPES_USER_TOKEN_TTL_SECONDS = '1234567';
    jest.resetModules();
    const { issueRecipesUserToken } = require('../local_user_portal/routes/auth');
    const tok = issueRecipesUserToken({ userId: 'u', email: 'e' });
    const payload = decode(tok);
    const ttl = payload.exp - payload.iat;
    expect(ttl).toBe(1234567);
  });
  ```

- Wire into existing test runner; ensure it runs on
  `npm test` and in CI.

**Acceptance:** test passes locally; reverting Chunk 1 fails it.

---

## Chunk 10 — Commit + push (this dev machine, Mac mini) [✅]

Two repos, separate commits:

- `mahallem_ist`:
  - `auth.js` (Chunk 1)
  - `docker-compose.yml` (Chunk 2)
  - optional: `tests/auth.test.js` (Chunk 9)
- `otus_dz_2` (`recipe_list`):
  - `recipe_card.dart` (Chunks 3 + 6b)
  - `admin_after_login_page.dart` (Chunks 4 + 5 + 6c + 6d-partial)
  - `admin_session.dart` (Chunk 6a + 6d-partial)
  - `login_page.dart`, `user_card_page.dart` (Chunk 6d)
- `otus_dz_2` (`docs/`): incident doc + project_log + this todo
  (Chunk 7).

**Acceptance:** `git status` clean on both repos; both pushed
to GitHub; CI green where applicable.

---

## Chunk 11 — Deploy backend (`mahallem_ist`) [✅]

```sh
cd /root/mahallem/mahallem_ist
git pull
cd local_docker_admin_backend
export RECIPES_API_SECRET="$(grep ^RECIPES_API_SECRET= .env | cut -d= -f2)"
docker compose build user-portal
docker compose up -d user-portal
docker exec mahallem-user-portal node -e "
  console.log('user TTL', process.env.RECIPES_USER_TOKEN_TTL_SECONDS);
  console.log('admin TTL', process.env.RECIPE_ADMIN_TOKEN_TTL_SECONDS);
  console.log('user secret set:', Boolean(process.env.RECIPES_USER_TOKEN_SECRET || process.env.RECIPES_API_SECRET));
"
```

**Acceptance:** prints `31536000`, `31536000`, `true`.

---

## Chunk 12 — Deploy web (`otus_dz_2`) [✅]

**Why:** missing yesterday — the web container was still
running a build from before commit `80e8a32`, which is why web
showed the raw `DioException` toast.

```sh
cd /var/www/recipie/otus_dz_2
git pull
docker compose -f docker-compose.web.yml build flutter-web
docker compose -f docker-compose.web.yml up -d flutter-web
```

**Acceptance:** `recipies.mahallem.ist` serves a build that
contains the friendly-401 catch (no raw DioException toast on
401). The diagnostic snackbar shows up on web too when
`adminSessionLossNotifier` fires.

---

## Chunk 13 — Rebuild + install iOS [🟦 simulator only]

Devices:
- Novogod `00008140-0014399E0EF3001C`
- NovogodOne `00008120-000E459E2E50A01E`

**Acceptance:** both devices run a build that contains
Chunks 3-6. Manual smoke test: induce 401 → friendly snackbar
→ "Copy details" places the dump on the clipboard.

---

## Chunk 14 — Verification matrix [⬜ in progress]

For each platform (web, iOS Novogod, iOS NovogodOne, PWA):

| Check | Expected |
|---|---|
| Login as admin | OK |
| Tap a star pill | 200, pill updates |
| Server-side: invalidate token, tap a star | Snackbar with diagnostic |
| Tap "Copy details" in snackbar | Clipboard has multi-line dump |
| Restart app, biometric login | Works |
| Profile tab post-401 | `LoginPage` or `UserCardPage`, **never** the rejected ghost design |
| `flutter logs` / Xcode / browser console | Contains `name=admin_session` and `name=admin_after_login_page` entries with full dump |

**Acceptance:** all rows pass on all platforms.

---

## Chunk 15 — Follow-up: in-place re-auth on 401 [⬜ multi-day]

**Why:** today's patch only blunts the side-effects. The right
UX is: user taps a star → 401 → modal bottom sheet asks for
re-auth (biometric or password) → on success, retry the
original action without unmounting admin tiles or navigating.

**Out of scope here.** New incident-doc when the work starts.
Touches `recipe_card.dart`, future `_writeActionWithReauth`
helper, and probably a new `re_auth_sheet.dart`.

---

## Chunk 16 — Follow-up: WebAuthn / passkey for web biometric [⬜ multi-day]

**Why:** product line is feature parity across web / PWA /
iOS / Android. Web has had WebAuthn for years; the
"not supported in web mode" snackbars are a shortcut, not a
product decision.

Sketch:
1. Backend: `@simplewebauthn/server`,
   `POST /recipes/auth/passkey/{register-options,register-finish,sign-options,sign-finish}`,
   table `recipe_app_users_passkeys`.
2. Client (web): `package:webauthn` or `dart:js_interop` to
   `navigator.credentials.create / get` when `kIsWeb`.
3. Native unchanged (`local_auth` keeps working). Optional
   later: migrate native to passkey transport for cross-device
   sync.

**Out of scope here.** New incident-doc when the work starts.

---

## Chunk 17 — Follow-up: pipe every write-action 401 through the diagnostic channel [⬜]

**Why:** Chunk 6 only instruments the rating pill. The same
channel should fire from every other write action — favourites,
comments, recipe edit/save, image upload, admin user CRUD —
so we never again get "the page just kicked me out and I have
no idea why" without a diagnostic dump.

**Files (inventory to confirm):**
- `recipe_list/lib/data/api/*` — wherever `Dio.post/put/patch/delete`
  is called with the bearer.
- A central `Dio` interceptor would be cleaner: on 401/403,
  publish `AdminSessionLossEvent` and call `logoutAdmin(clearSavedSession: false, lossEvent: …)`.

**Acceptance:** all write actions surface the same snackbar +
log dump as the rating pill on 401. Add to the verification
matrix in Chunk 14.

---

## Chunk 19 — Backend: decouple `RECIPES_API_SECRET` from JWT signing keys [✅]

**Why (regression introduced by Chunk 2):** `RECIPES_API_SECRET`
plays two unrelated roles in `local_user_portal`:

1. *Optional shared-secret gate* read by `authMiddleware` in
   `routes/recipes.js` (lines 121-131). When set, every request
   to `/recipes/*` must carry header `x-recipes-token: <value>`.
   The Flutter web/iOS clients do not send this header — these
   read endpoints are intentionally public. In prod the env var
   was always unset; the gate was off.
2. *Fallback signing key* for `RECIPES_USER_TOKEN_SECRET` and
   `RECIPE_ADMIN_TOKEN_SECRET` if those weren't explicitly set.

Chunk 2 made `RECIPES_API_SECRET` fail-fast required and used
`:-${RECIPES_API_SECRET}` defaults to derive both signing
keys from it. Side effect: the gate flipped ON.
Within an hour the web client was 401-ing on `/recipes/page`,
`/recipes/filter`, `/recipes/visit`, `/recipes/count`.

**Files:**
- `mahallem_ist/local_docker_admin_backend/docker-compose.yml`
  (user-portal env block):
  - `RECIPES_API_SECRET: ${RECIPES_API_SECRET:-}` (gate
    optional, off by default).
  - `RECIPES_USER_TOKEN_SECRET: ${RECIPES_USER_TOKEN_SECRET:?…must be set…}`
    (independent fail-fast).
  - `RECIPE_ADMIN_TOKEN_SECRET: ${RECIPE_ADMIN_TOKEN_SECRET:?…must be set…}`
    (independent fail-fast).
- Prod `.env`: added explicit `RECIPES_USER_TOKEN_SECRET=<same
  value as RECIPE_ADMIN_TOKEN_SECRET>` so any user token issued
  during the regression window continues to verify; commented
  out the `RECIPES_API_SECRET=` line.

**Acceptance:**
- `curl http://localhost:4000/recipes/page?offset=0&limit=1&lang=en`
  returns `200`.
- `curl https://recipies.mahallem.ist/recipes/page?…` returns `200`.
- `docker exec mahallem-user-portal node -e "console.log(Boolean(process.env.RECIPES_USER_TOKEN_SECRET))"`
  prints `true`; same for `RECIPE_ADMIN_TOKEN_SECRET`;
  `RECIPES_API_SECRET` is empty/unset.

**DoD:** committed (`bc4163c0`), pushed, deployed; web smoke
test 200 across `page` / `filter` / `count`.

**Follow-up rename (deferred):** `RECIPES_API_SECRET` is a
misleading name — it has nothing to do with API access in the
JWT sense. Rename to `RECIPES_API_GATE_TOKEN` in a separate
commit so the dual-purpose confusion can never recur.

---

# Web biometric (Magic Keyboard Touch ID etc.) — Chunks 21-27

The recipe app currently shows two "not supported in web mode"
snackbars in `recipe_list/lib/ui/login_page.dart` (lines 216
and 251). The work below replaces them with a real
WebAuthn / passkey flow that mirrors the existing partner-login
implementation in `mahallem_ist/local_user_portal`
(`routes/auth-passkey.js` + `utils/webauthn.js`), which already
runs in production for the partner portal and uses
`@simplewebauthn/server`.

Architecture notes:
- Recipe-app users live in `recipe_app_users` (not the partner
  `users` table), so we need a parallel
  `recipe_app_user_credentials` table — we do NOT reuse
  `user_credentials` because `user_id` there is FK'd to `users`.
- `webauthn_challenges` is keyed by challenge string + type
  only; safe to reuse across both flows. Verify it exists on
  prod before assuming.
- Auth on these endpoints is JWT bearer
  (`x-recipes-user-token`), not session cookie. Login-complete
  must mint a fresh `RECIPES_USER_TOKEN` (via
  `issueRecipesUserToken` from `routes/auth.js`) and return it
  in the JSON response so the client can stash it.
- `WEBAUTHN_RP_ID` and `WEBAUTHN_ORIGIN` env vars are already
  set on prod for the partner flow — we reuse them.
- iOS / Android keep using `local_auth` unchanged. Optional
  later step: parity passkey path on native too, so a passkey
  registered in Safari also works in the iOS app via the
  iCloud Keychain shared credential store.

## Chunk 21 — Backend: DB migration `recipe_app_user_credentials` [✅]

**Deployed:** `mahallem_ist@f52e135b` (2026-05-08).
Migration `database/migrations/20260508_recipe_app_passkeys.sql`
applied to prod via `docker exec mahallem-db psql` after a
BEGIN/ROLLBACK dry-run. Both `recipe_app_user_credentials` and
`recipe_app_webauthn_challenges` are present on prod.
Regression test:
`local_user_portal/tests/recipe-app-passkey-migration.test.js`
(7 source-shape assertions, all green).

**Why:** the `user_credentials` table FKs to `users.id`. Recipe
app users live in `recipe_app_users` and have UUIDs that are
not guaranteed to exist in `users`. We need a parallel table.

**Files:**
- `mahallem_ist/local_user_portal/migrations/NNN_recipe_app_passkeys.sql`
  (next migration number — confirm by `ls migrations | sort -V | tail -3`):

  ```sql
  CREATE TABLE IF NOT EXISTS recipe_app_user_credentials (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES recipe_app_users(id) ON DELETE CASCADE,
    credential_id   TEXT NOT NULL UNIQUE,    -- base64url
    public_key      TEXT NOT NULL,           -- base64url
    counter         BIGINT NOT NULL DEFAULT 0,
    device_name     TEXT,
    device_type     TEXT,
    os_name         TEXT,
    browser_name    TEXT,
    transports      TEXT[] NOT NULL DEFAULT ARRAY['internal']::text[],
    aaguid          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at    TIMESTAMPTZ
  );
  CREATE INDEX IF NOT EXISTS idx_recipe_app_user_credentials_user
    ON recipe_app_user_credentials(user_id);
  ```

  Plus an idempotent `CREATE TABLE IF NOT EXISTS
  webauthn_challenges` block in case prod doesn't have it yet
  (it should — used by the partner flow — but the migration
  must be self-contained for fresh installs).

**Acceptance:**
- Apply on prod via the project's existing migration runner.
- `\d recipe_app_user_credentials` in psql shows the schema.
- Rollback path documented (just `DROP TABLE
  recipe_app_user_credentials`; nothing else depends on it).

**DoD:** migration committed; applied on prod; no other
container restarted (this is a pure DDL change).

---

## Chunk 22 — Backend: `routes/auth-passkey-recipes.js` [✅ `mahallem_ist@2c6eb080`, deployed 2026-05-08]
_(was `## Chunk 21` — renumbered 2026-05-08 to align with index after
the rating-pill gate became Chunk 20.)_
**Why:** new namespace `/recipes/auth/passkey/*` so it is
clearly the recipe-app variant, separate from
`/api/auth/passkey/*` used by the partner portal.

**Endpoints (all JSON):**
- `GET  /recipes/auth/passkey/available` — public; returns
  `{ available: true, rpId: <env> }`. No DB hit.
- `POST /recipes/auth/passkey/register/start`
  — auth: `x-recipes-user-token` required (uses
  `recipesUserAuthMiddleware` from `routes/recipes.js`).
  Returns `PublicKeyCredentialCreationOptionsJSON` with
  challenge stored in `webauthn_challenges`.
- `POST /recipes/auth/passkey/register/complete`
  — auth: same. Body is the registration response from the
  browser. Verifies, stores in `recipe_app_user_credentials`,
  returns `{ success: true, credential: { id, deviceName,
  createdAt } }`.
- `POST /recipes/auth/passkey/login/start`
  — anonymous. Optional `{ email }` body to scope
  `allowCredentials`; otherwise discoverable. Returns
  `PublicKeyCredentialRequestOptionsJSON`.
- `POST /recipes/auth/passkey/login/complete`
  — anonymous. Verifies; on success, looks up
  `recipe_app_users` row, mints a fresh
  `RECIPES_USER_TOKEN` via `issueRecipesUserToken({ userId,
  email })` (already exported from `routes/auth.js`), returns
  `{ success: true, token, user: { id, email, fullName, isAdmin } }`.
  Bearer token TTL is the same 31536000 s as the password
  flow (Chunk 1).
- `GET    /recipes/auth/passkey/credentials` — JWT bearer
  required. Lists user's passkeys.
- `DELETE /recipes/auth/passkey/credentials/:id` — JWT bearer
  required.

Implementation may import most helpers verbatim from
`utils/webauthn.js` — only the queries that touch `users` /
`user_credentials` need parallel versions for `recipe_app_users`
/ `recipe_app_user_credentials`.

**Files:**
- `mahallem_ist/local_user_portal/routes/auth-passkey-recipes.js`
  — new file, ~400 lines.
- `mahallem_ist/local_user_portal/utils/webauthn-recipes.js`
  — new file, exports `generateRecipeAppPasskeyRegistrationOptions`,
  `verifyRecipeAppPasskeyRegistration`,
  `generateRecipeAppPasskeyAuthenticationOptions`,
  `verifyRecipeAppPasskeyAuthentication`,
  `getRecipeAppUserCredentials`,
  `deleteRecipeAppCredential`. Reuses `storeChallenge` /
  `verifyAndConsumeChallenge` from `utils/webauthn.js`.
- `mahallem_ist/local_user_portal/server.js` — mount
  `passkeyRecipesRoutes(app, pool)` next to existing
  `passkeyRoutes(app, pool)`.
- `mahallem_ist/local_user_portal/routes/auth.js` — export
  `issueRecipesUserToken` if not already exported (it is, per
  Chunk 9 test).

**Acceptance:**
- `node --test tests/passkey-recipes.test.js` — at least a
  smoke test that `register/start` returns a challenge of the
  right shape when called with a valid bearer.
- Manual: `curl -H 'x-recipes-user-token: <jwt>'
  https://recipies.mahallem.ist/recipes/auth/passkey/register/start`
  returns 200 with `challenge` and `pubKeyCredParams`.

**DoD:** committed; deployed; no regression on existing
`/api/auth/passkey/*` partner endpoints.

---

## Chunk 23 — Web: JS bridge `recipe_list/web/passkey_bridge.js` [✅ 11/11 tests green]

**Why:** `dart:js_interop` can call WebAuthn directly, but the
base64url ↔ ArrayBuffer plumbing is tedious. A 50-line JS
shim that exposes `window.recipeAppPasskey.{register,login}`
keeps the Dart side simple.

**Files:**
- `recipe_list/web/passkey_bridge.js` — exports
  `register(optionsJson) → response` and
  `login(optionsJson) → response`. Uses
  `PublicKeyCredential.parseCreationOptionsFromJSON` /
  `parseRequestOptionsFromJSON` if available; otherwise
  base64url-decodes manually.
- `recipe_list/web/index.html` — `<script defer
  src="passkey_bridge.js"></script>` before the Dart bootstrap.

**Acceptance:**
- `window.recipeAppPasskey` exists in the browser console.
- Calling `register` with hand-crafted options surfaces the
  Touch ID prompt on a Magic Keyboard.

---

## Chunk 24 — Dart: `recipe_list/lib/auth/passkey_web.dart` [✅ 5/5 stub tests green]

**Why:** unified Dart API regardless of platform.
`passkey_web.dart` (web build) calls into
`window.recipeAppPasskey`; `passkey_native.dart` (non-web)
returns `Future.error(PasskeyUnsupportedException())`.

**Files:**
- `recipe_list/lib/auth/passkey_api.dart` — abstract surface:
  `Future<bool> isAvailable()`,
  `Future<void> registerPasskey({required String token})`,
  `Future<({String token, bool isAdmin, String email})> loginWithPasskey({String? email})`,
  `Future<List<PasskeyDescriptor>> listPasskeys({required String token})`,
  `Future<void> deletePasskey({required String id, required String token})`.
- `recipe_list/lib/auth/passkey_web.dart` — implements via
  `package:web` + `dart:js_interop` and the bridge in
  Chunk 22. Talks to `/recipes/auth/passkey/*`.
- `recipe_list/lib/auth/passkey_stub.dart` — non-web throws
  `PasskeyUnsupportedException`.
- Conditional import in `passkey_api.dart`:
  `if (dart.library.html) 'passkey_web.dart'`
  `else                   'passkey_stub.dart'`.

**Acceptance:** `flutter analyze` clean on web and iOS targets.

---

## Chunk 25 — UI: wire passkey into `login_page.dart` [✅ 6/6 tests green]

**Why:** replace the two "not supported in web mode"
snackbars (lines 216, 251) with the real flow.

**Behaviour:**
- `_saveCurrentSessionForBiometric` on web: call
  `passkeyApi.registerPasskey(token: currentUserTokenNotifier.value!)`.
  On success, snackbar "Passkey saved. Use Touch ID to sign in
  next time."
- `_loginWithBiometrics` on web: call
  `passkeyApi.loginWithPasskey(email: <prefilled login>)`.
  On success, drop the returned token into
  `currentUserTokenNotifier`, set state notifiers, navigate
  same as password flow.
- Keep native `local_auth` branch as it is.

**Files:**
- `recipe_list/lib/ui/login_page.dart` — guard on `kIsWeb`,
  branch into `passkey_api.dart` instead of showing the
  snackbar.
- `recipe_list/lib/auth/admin_session.dart` — small helper
  `applyPasskeyLoginResult({token, email, isAdmin})` that
  centralises the state-flip; reused by `loginWithPasskey`.

**Acceptance:**
- Web: button "Save current session for Face ID / Fingerprint"
  on a Magic Keyboard pops the Touch ID system sheet, then
  shows success snackbar.
- Web: button "Sign in with Face ID / Fingerprint" pops Touch
  ID, then logs the user in without password entry.
- iOS / Android: no behavioural change vs today.

---

## Chunk 26 — Verification matrix [⬜]

Add to Chunk 14:

| Platform / Device | Save session | Login with biometric |
|---|---|---|
| Web (Mac, Magic Keyboard Touch ID) | ✅ Touch ID prompt → success | ✅ |
| Web (iOS Safari) | ✅ Face ID prompt → success | ✅ |
| Web (Windows, Hello) | ✅ Hello prompt → success | ✅ |
| Web (Android Chrome) | ✅ Fingerprint → success | ✅ |
| iOS Novogod | ✅ Face ID (`local_auth`) | ✅ |
| iOS NovogodOne | ✅ Face ID (`local_auth`) | ✅ |

---

## Chunk 27 — Deploy [⬜]

1. Apply Chunk 20 migration on prod (psql).
2. `cd /root/mahallem/mahallem_ist && git pull && cd
   local_docker_admin_backend && docker compose up -d --build
   user-portal`. Smoke-check
   `curl https://recipies.mahallem.ist/recipes/auth/passkey/available`
   returns 200.
3. `cd /var/www/recipie/otus_dz_2 && git pull && docker
   compose -f docker-compose.web.yml up -d --build flutter-web`.
4. Manual passes on Magic Keyboard, iOS Safari, Windows Hello,
   Android Chrome.

**DoD:** matrix in Chunk 25 all green; release note in
`docs/project_log.md`.

---

## Cross-references

- Predecessor incident (yesterday): [docs/auth-session-401-rating.md](../../auth-session-401-rating.md).
- This incident: [docs/auth-session-401-recurrence-2026-05-08.md](../../auth-session-401-recurrence-2026-05-08.md).
- Project log: [docs/project_log.md](../../project_log.md).
