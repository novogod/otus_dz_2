# TODO — Auth: 401-on-rating recurrence + biometric wipe (2026-05-08)

Source incident: [docs/auth-session-401-recurrence-2026-05-08.md](../../auth-session-401-recurrence-2026-05-08.md).

This file breaks the incident into independently-deployable
chunks. Each chunk lists scope, files touched, acceptance test,
and "Definition of done". Chunks marked ✅ are already coded
in the working tree but not yet committed/deployed.

Status legend: ⬜ not started · 🟨 in working tree, not committed
· 🟦 committed but not deployed · ✅ deployed and verified.

## Chunk index

1. Backend — re-apply user-token TTL fix [🟨]
2. Backend — fail-fast signing-secret plumbing [🟨]
3. Client — preserve biometric blob on 401 in `PhotoRatingPill` [🟨]
4. Client — delete the `AdminAfterLoginPage` ghost (rejected design) [🟨]
5. Client — auto-pop `AdminAfterLoginPage` when admin context is lost [🟨]
6. Client — admin-session-loss diagnostic event channel + snackbar [🟨]
7. Doc amendments + project log [🟨]
8. Process — respect on-disk drift; never dismiss "file changed
   on disk" warnings [⬜ ongoing]
9. Backend — regression test for `issueRecipesUserToken` TTL [🟨]
10. Commit + push (laptop) [⬜]
11. Deploy backend (`mahallem_ist`) [⬜]
12. Deploy web (`otus_dz_2`) [⬜]
13. Rebuild + install iOS on Novogod / NovogodOne [⬜]
14. Verification matrix on web + iOS [⬜]
15. Follow-up: in-place re-auth on 401 (replaces the kick-out) [⬜ multi-day]
16. Follow-up: WebAuthn / passkey parity for web biometric [⬜ multi-day]
17. Follow-up: write-actions inventory — pipe every 401 through the
    diagnostic channel [⬜]

---

## Chunk 1 — Backend: re-apply user-token TTL fix [🟨]

**Why:** commit `bc13c91f` paste-overwrote `78ee36a4` and
re-introduced a hard-coded 30-day user-token TTL. Mornings ship
expired user tokens and 401s flow back to the client.

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

## Chunk 2 — Backend: fail-fast signing-secret plumbing [🟨]

**Why:** before this fix `RECIPE_ADMIN_TOKEN_SECRET:` defaulted
to empty, falling through to `'change-me'` inside `auth.js`. Any
restart with the host env unset silently rotates the secret and
invalidates every previously-issued bearer token.

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

## Chunk 3 — Client: preserve biometric blob on 401 [🟨]

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

## Chunk 4 — Client: delete the `AdminAfterLoginPage` ghost [🟨]

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

## Chunk 5 — Client: auto-pop `AdminAfterLoginPage` on admin-loss [🟨]

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

## Chunk 6 — Client: admin-session-loss diagnostic channel [🟨]

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

## Chunk 7 — Doc amendments + project log [🟨]

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

## Chunk 9 — Backend: regression test for user-token TTL [⬜]

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

## Chunk 10 — Commit + push (this dev machine, Mac mini) [⬜]

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

## Chunk 11 — Deploy backend (`mahallem_ist`) [⬜]

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

## Chunk 12 — Deploy web (`otus_dz_2`) [⬜]

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

## Chunk 13 — Rebuild + install iOS [⬜]

Devices:
- Novogod `00008140-0014399E0EF3001C`
- NovogodOne `00008120-000E459E2E50A01E`

**Acceptance:** both devices run a build that contains
Chunks 3-6. Manual smoke test: induce 401 → friendly snackbar
→ "Copy details" places the dump on the clipboard.

---

## Chunk 14 — Verification matrix [⬜]

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

## Cross-references

- Predecessor incident (yesterday): [docs/auth-session-401-rating.md](../../auth-session-401-rating.md).
- This incident: [docs/auth-session-401-recurrence-2026-05-08.md](../../auth-session-401-recurrence-2026-05-08.md).
- Project log: [docs/project_log.md](../../project_log.md).
