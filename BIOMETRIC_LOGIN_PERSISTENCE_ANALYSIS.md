# Biometric Login Persistence Analysis

**Status:** Complete investigation  
**Date:** 2026-05-09  
**Issue:** Biometric data saves (shows snackbar success) but disappears on next app launch (affects iOS/Android identically)

---

## 1. Database Initialization & Schema

### Location: `lib/data/local/recipe_db.dart`

**Schema Version:** v16 (current)  
**Relevant Migrations:**
- v8: Initial `auth_credentials` table created
- v9: Added `preferred_language` column
- v10-v11: Added `is_admin` column (v10 fresh-install was missing it, v11 re-applied idempotently)

**CREATE TABLE Statement:**
```sql
CREATE TABLE auth_credentials (
  login TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  token TEXT,
  active INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  preferred_language TEXT,
  is_admin INTEGER NOT NULL DEFAULT 0
);
```

**Key Points:**
- Table persists across app restarts via SQLite (file-based on iOS/Android, IndexedDB on web)
- `active` column marks the currently logged-in session (0 = inactive, 1 = active)
- `token` column stores the session token for offline login
- `password_hash` stores hash for offline authentication

---

## 2. Logout Logic

### Location: `lib/auth/admin_session.dart` @ line 488

```dart
Future<void> logoutAdmin({
  bool clearSavedSession = true,
  AdminSessionLossEvent? lossEvent,
}) async {
  final db = _db;
  if (db != null) {
    await db.transaction((txn) async {
      if (clearSavedSession) {
        // Explicit logout must destroy all persisted token sessions so
        // no biometric/trusted auto-resume survives it.
        await txn.update('auth_credentials', {'active': 0, 'token': null});
      } else {
        await txn.update('auth_credentials', {
          'active': 0,
        }, where: 'active = 1');
      }
    });
  }
  _setSessionState(login: null, token: null, isAdmin: false);
  currentRecipeAdminTokenNotifier.value = null;
  _sessionAdminPassword = null;
  if (lossEvent != null) {
    _publishAdminSessionLoss(lossEvent);
  }
}
```

**Behavior:**
- **With `clearSavedSession=true`** (default, called from UserCardPage): Sets `active=0, token=null` on ALL rows → **destroys biometric data**
- **With `clearSavedSession=false`**: Only deactivates the currently active row; preserves other token sessions
- **Used in UserCardPage._handleLogout()** @ line 300 with `clearSavedSession: true`

---

## 3. Database Schema Migrations

### Location: `lib/data/local/recipe_db.dart` @ line 428-549

**All migrations are idempotent** (safe to re-run):

| Migration | Change | Destructive? |
|-----------|--------|-------------|
| v7 → v8   | Create `auth_credentials` table | No (additive) |
| v8 → v9   | Add `preferred_language` column | No (idempotent ALTER) |
| v9 → v10  | Add `is_admin` column | No (idempotent ALTER) |
| v10 → v11 | Re-apply `is_admin` (v10 fresh-install bug) | No (idempotent) |
| v11 → v12 | Add user profile & creator cache tables | No (additive) |

**No data is dropped or cleared during migrations.** The `_onRecipeDbUpgrade` callback applies version checks and only upgrades if needed.

---

## 4. Save-to-Restore Flow: Complete Path

### **Phase 1: Save Biometric Data**

**File:** `lib/ui/user_card_page.dart` @ line 237-305

```dart
Future<void> _addPasskey() async {
  if (_busy || _passkeyBusy) return;
  // ... web branch (passkey_api) ...
  
  // Native (iOS / Android): save current session for biometric login.
  setState(() => _passkeyBusy = true);
  bool ok = false;
  try {
    ok = await saveCurrentSessionForBiometricLogin();  // ← KEY CALL
  } catch (e) {
    debugPrint('[UserCardPage] saveCurrentSessionForBiometricLogin failed: $e');
    ok = false;
  }
  if (!mounted) return;
  setState(() => _passkeyBusy = false);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          ok ? s.profileBiometricSaved : s.profileBiometricSaveFailed,
        ),
      ),
    );
}
```

**Location of saveCurrentSessionForBiometricLogin():** `lib/auth/admin_session.dart` @ line 660

```dart
Future<bool> saveCurrentSessionForBiometricLogin() async {
  final db = _db;                    // ← Uses global _db reference
  if (db == null) return false;

  final login = currentUserLoginNotifier.value?.trim();
  if (login == null || login.isEmpty) return false;

  final isAdmin = adminLoggedInNotifier.value;
  final token = isAdmin
      ? currentRecipeAdminTokenNotifier.value
      : currentUserTokenNotifier.value;
  if (token == null || token.isEmpty) return false;

  await _persistTrustedSession(
    db: db,
    login: login,
    token: token,
    preferredLang: appLang.value.name,
    isAdmin: isAdmin,
  );
  return true;
}
```

**Location of _persistTrustedSession():** `lib/auth/admin_session.dart` @ line 1623

```dart
Future<void> _persistTrustedSession({
  required Database db,
  required String login,
  required String? token,
  String? preferredLang,
  String? passwordHash,
  bool isAdmin = false,
}) async {
  final existing = await db.query(
    'auth_credentials',
    columns: ['password_hash', 'preferred_language'],
    where: 'login = ?',
    whereArgs: [login],
    limit: 1,
  );
  final existingHash = existing.isEmpty
      ? null
      : existing.first['password_hash'] as String?;
  final existingLang = existing.isEmpty
      ? null
      : existing.first['preferred_language'] as String?;
  final ts = DateTime.now().millisecondsSinceEpoch;
  
  // ← INSERT OR REPLACE into auth_credentials
  await db.insert('auth_credentials', {
    'login': login,
    'password_hash': passwordHash ?? existingHash ?? _kPasskeyOnlyPasswordHash,
    'token': token,                    // ← TOKEN IS SAVED HERE
    'active': 1,                       // ← MARKED ACTIVE
    'updated_at': ts,
    'preferred_language': preferredLang ?? existingLang ?? appLang.value.name,
    'is_admin': isAdmin ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  
  // ← DEACTIVATE OTHER ROWS
  await db.update(
    'auth_credentials',
    {'active': 0},
    where: 'login <> ?',
    whereArgs: [login],
  );
}
```

**✅ Save Flow Summary:**
1. Button tap → `_addPasskey()` (for native platforms)
2. Calls `saveCurrentSessionForBiometricLogin()`
3. Fetches current `login`, `token`, `isAdmin` from notifiers
4. Calls `_persistTrustedSession()` which:
   - INSERTs into `auth_credentials` with `token` and `active=1` (ConflictAlgorithm.replace)
   - DEC ACTIVATES other rows (`active=0`)
5. **Returns `true` → Snackbar shows "Biometric Saved"**

---

### **Phase 2: Restore on App Restart**

**File:** `lib/main.dart` @ line 47-55

```dart
try {
  final db = await openRecipeDatabase();
  await bootstrapAdminSession(db: db);  // ← BOOTSTRAP SESSION ON APP STARTUP
  await reconcilePreferredLanguageFromServer();
} catch (e) {
  print('[main] auth bootstrap failed: $e');
}
```

**Location of bootstrapAdminSession():** `lib/auth/admin_session.dart` @ line 284

```dart
Future<void> bootstrapAdminSession({required Database db}) async {
  print('[admin_session] bootstrapAdminSession: starting');
  _db = db;  // ← ASSIGNS GLOBAL DB REFERENCE HERE
  _sessionAdminPassword = null;
  
  final rows = await db.query(
    'auth_credentials',
    columns: ['login', 'token', 'preferred_language', 'is_admin'],
    where: 'active = 1',  // ← READS ACTIVE=1 ROWS ONLY
    limit: 1,
  );
  print(
    '[admin_session] bootstrapAdminSession: found ${rows.length} active rows',
  );
  
  if (rows.isEmpty) {
    print(
      '[admin_session] bootstrapAdminSession: no active rows, clearing session',
    );
    _setSessionState(login: null, token: null, isAdmin: false);
    return;
  }
  
  final login = rows.first['login'] as String?;
  final token = rows.first['token'] as String?;
  final storedLang = rows.first['preferred_language'] as String?;
  final storedIsAdmin = (rows.first['is_admin'] as int? ?? 0) == 1;
  
  print(
    '[admin_session] bootstrapAdminSession: login=$login, token=${token?.isNotEmpty}, storedIsAdmin=$storedIsAdmin',
  );
  
  final isAdmin = storedIsAdmin || isLegacyAdminSession;
  _setSessionState(
    login: login,
    token: isAdmin ? null : token,
    isAdmin: isAdmin,
  );
  // ... restore language preference ...
  if (isLegacyAdminSession) {
    _sessionAdminPassword = _legacyAdminPassword;
  }
}
```

**✅ Restore Flow Summary:**
1. App starts → `main()` calls `openRecipeDatabase()`
2. Calls `bootstrapAdminSession(db)` which:
   - Queries `auth_credentials` WHERE `active = 1`
   - If found: Restores `login`, `token`, `preferred_language`, `is_admin`
   - If empty: Clears session state
3. Session is restored from database

---

## 5. Database Connection Lifecycle

### Initialization: `lib/auth/admin_session.dart` @ line 284-286

```dart
Future<void> bootstrapAdminSession({required Database db}) async {
  print('[admin_session] bootstrapAdminSession: starting');
  _db = db;  // ← ASSIGNED AT BOOTSTRAP
  // ...
}
```

**Key Points:**
- `_db` is a **global variable** (`Database? _db;`) assigned during `bootstrapAdminSession()`
- Called from `main.dart` BEFORE first frame
- Also called from `recipe_list_loader.dart` as fallback if no live session exists
- **Database is never closed** (intentionally persisted for lifetime of app)
- The same `_db` reference is used throughout the app lifecycle

### Database Caching: `lib/data/local/recipe_db.dart` @ line 362-370

```dart
Future<Database>? _openRecipeDatabaseFuture;

Future<Database> openRecipeDatabase() {
  return _openRecipeDatabaseFuture ??= _openRecipeDatabaseImpl();
}

Future<Database> _openRecipeDatabaseImpl() async {
  // ... opens database and applies schema/migrations ...
}
```

**Key Points:**
- Database future is cached to prevent multiple simultaneous opens
- Same database instance is reused throughout app lifetime

---

## 6. Conditional Checks & Potential Issues

### **CRITICAL FINDING: Database Assignment After Bootstrap**

**File:** `lib/ui/recipe_list_loader.dart` @ line 930-980

```dart
static Future<RecipeRepository?> _defaultRepoBuilder(RecipeApi api) async {
  try {
    final db = await openRecipeDatabase();
    favoritesStoreNotifier.value ??= FavoritesStore(db: db);
    ratingStoreNotifier.value ??= RatingStore(api: api);
    
    final hasLiveSession =
        userLoggedInNotifier.value ||
        adminLoggedInNotifier.value ||
        (currentUserLoginNotifier.value?.trim().isNotEmpty ?? false) ||
        (currentUserTokenNotifier.value?.isNotEmpty ?? false) ||
        (currentRecipeAdminTokenNotifier.value?.isNotEmpty ?? false);
    print(
      '[RecipeListLoader] _defaultRepoBuilder: userLoggedInNotifier=${userLoggedInNotifier.value}, ...',
    );
    
    if (!hasLiveSession) {
      print('[RecipeListLoader] Calling bootstrapAdminSession (no live session)');
      await bootstrapAdminSession(db: db);  // ← RE-BOOTSTRAP HERE
    } else {
      print('[RecipeListLoader] Skipping bootstrapAdminSession (live session exists)');
    }
    
    // ... warmup favorites, owned recipes, etc. ...
    return RecipeRepository(db: db, api: api);
  } on Object catch (e) {
    print('[repo] local db bootstrap failed: $e');
    return null;
  }
}
```

**Bootstrap Sequence:**
1. `main()` → calls `bootstrapAdminSession(db)` (assigns `_db`)
2. SplashAndRecipes mounts → RecipeListLoader mounts → `_defaultRepoBuilder` runs
3. `_defaultRepoBuilder` checks if there's a live session
4. If NO live session → **Re-calls `bootstrapAdminSession(db)`** (re-assigns `_db`)

**⚠️ POTENTIAL ISSUE:** If `_db` is reassigned during app lifetime but the old reference was being used somewhere, it could cause issues. However, this should not affect the biometric save/restore flow.

---

## 7. Root Cause Analysis: Why Biometric Data Disappears

### **Hypothesis 1: `logoutAdmin(clearSavedSession: true)` is called somewhere**

**CHECKED:** `_handleLogout()` in `user_card_page.dart` calls:
```dart
await logoutAdmin(
  clearSavedSession: true,  // ← CLEARS TOKEN!
  lossEvent: AdminSessionLossEvent(
    reason: 'User tapped Logout in profile (UserCardPage)',
  ),
);
```

This would DELETE the token by setting `token=null` and `active=0` on ALL rows.

**But this is only called when user explicitly taps "Logout" button, not on app restart.**

---

### **Hypothesis 2: Database is corrupted or not being persisted**

**CHECKED:** 
- Database is file-based (iOS/Android) or IndexedDB (web) → should persist
- No code closes or deletes the database
- Migrations are idempotent, don't drop `auth_credentials`

---

### **Hypothesis 3: `active=1` flag is not being set correctly**

**ANALYSIS:**
In `_persistTrustedSession()` at line 1633:
```dart
await db.insert('auth_credentials', {
  // ...
  'active': 1,  // ← SET TO 1
  // ...
}, conflictAlgorithm: ConflictAlgorithm.replace);

await db.update(
  'auth_credentials',
  {'active': 0},
  where: 'login <> ?',  // ← DEACTIVATE OTHER LOGINS
  whereArgs: [login],
);
```

The INSERT uses `ConflictAlgorithm.replace`, which means:
- If row with same `login` exists → REPLACE it with new values (`token`, `active=1`)
- Then deactivate other logins

**This should work correctly.**

---

### **Hypothesis 4: Token is being cleared on another code path**

**SEARCHED:** All places that update `auth_credentials`:
1. `_persistTrustedSession()` → Sets `token`, `active=1`
2. `logoutAdmin()` → Clears `token`, `active=0` (explicit logout only)
3. `_setActiveLogin()` → Only updates `active` flag, not `token`
4. `_persistActivePreferredLanguage()` → Only updates language, not `token`
5. `_clearPersistedSession()` → Deletes the row entirely (used in `loginAsAdmin` with `trustDevice=false`)

**No other code paths clear the token.**

---

### **Hypothesis 5: Bootstrap is finding rows with `active=0` instead of `active=1`**

**CRITICAL CODE PATH:**

In `bootstrapAdminSession()`:
```dart
final rows = await db.query(
  'auth_credentials',
  columns: ['login', 'token', 'preferred_language', 'is_admin'],
  where: 'active = 1',  // ← REQUIRES active=1
  limit: 1,
);

if (rows.isEmpty) {
  print('[admin_session] bootstrapAdminSession: no active rows, clearing session');
  _setSessionState(login: null, token: null, isAdmin: false);
  return;  // ← SESSION IS CLEARED IF NO ACTIVE=1 ROWS
}
```

**Potential Issue:** If `_persistTrustedSession()` is **not setting `active=1` correctly**, then:
- Save shows snackbar (thinks it succeeded)
- But database row has `active=0` or `active` is NULL
- Next app restart → `bootstrapAdminSession()` finds no `active=1` rows
- Session is cleared

---

## 8. Missing Password Hash Issue

**In `saveCurrentSessionForBiometricLogin()` @ line 660-679:**

```dart
Future<bool> saveCurrentSessionForBiometricLogin() async {
  final db = _db;
  if (db == null) return false;

  final login = currentUserLoginNotifier.value?.trim();
  if (login == null || login.isEmpty) return false;

  final isAdmin = adminLoggedInNotifier.value;
  final token = isAdmin
      ? currentRecipeAdminTokenNotifier.value
      : currentUserTokenNotifier.value;
  if (token == null || token.isEmpty) return false;

  await _persistTrustedSession(
    db: db,
    login: login,
    token: token,
    preferredLang: appLang.value.name,
    isAdmin: isAdmin,
    // ← NO passwordHash PASSED
  );
  return true;
}
```

**In `_persistTrustedSession()` @ line 1623-1652:**

```dart
Future<void> _persistTrustedSession({
  required Database db,
  required String login,
  required String? token,
  String? preferredLang,
  String? passwordHash,  // ← CAN BE NULL
  bool isAdmin = false,
}) async {
  // ...
  await db.insert('auth_credentials', {
    'login': login,
    'password_hash': passwordHash ?? existingHash ?? _kPasskeyOnlyPasswordHash,
    'token': token,
    'active': 1,
    'updated_at': ts,
    'preferred_language': preferredLang ?? existingLang ?? appLang.value.name,
    'is_admin': isAdmin ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  // ...
}
```

**Analysis:**
- `saveCurrentSessionForBiometricLogin()` does NOT pass `passwordHash`
- `_persistTrustedSession()` falls back to: `existing_hash → _kPasskeyOnlyPasswordHash`
- If this is the first time saving for biometric, `password_hash` will be set to `__passkey_only__`

**This is intentional and correct** for passkey-only flows, but let me verify the constant:

```dart
const String _kPasskeyOnlyPasswordHash = '__passkey_only__';
```

**Status:** ✅ Correctly set for passkey flows.

---

## 9. Summary of Findings

### ✅ What Works Correctly:
1. **Database initialization:** Proper schema with `auth_credentials` table
2. **Save flow:** `saveCurrentSessionForBiometricLogin()` correctly calls `_persistTrustedSession()` with `active=1` and token
3. **Restore flow:** `bootstrapAdminSession()` on app startup queries `WHERE active=1` and restores session
4. **Migrations:** All idempotent, no data loss
5. **Database persistence:** Properly cached and never closed
6. **INSERT OR REPLACE:** Uses correct conflict resolution strategy

### ⚠️ Potential Issues Found:

#### **Issue 1: Missing Error Handling in Save Flow**

`saveCurrentSessionForBiometricLogin()` has try-catch at the UI level (`user_card_page.dart`), but the database transaction in `_persistTrustedSession()` has no explicit error handling. If SQLite fails silently or partially, the snackbar might still show success.

#### **Issue 2: No Explicit Transaction in Dual-Update**

In `_persistTrustedSession()`, the INSERT and subsequent UPDATE are NOT in a transaction:
```dart
await db.insert('auth_credentials', { ... });  // ← Not in txn
await db.update(
  'auth_credentials',
  {'active': 0},
  where: 'login <> ?',
  whereArgs: [login],
);  // ← Not in txn
```

If the INSERT succeeds but the UPDATE fails, you'd have multiple rows with `active=1`.

#### **Issue 3: ConflictAlgorithm.replace Behavior**

When a row with the same `login` already exists, `ConflictAlgorithm.replace` does a DELETE then INSERT. If the old row had `active=1`, after replacement the new row should have `active=1`, but this depends on all columns being provided in the insert map.

**Verify:** The insert map includes `'active': 1`, so this should be safe.

#### **Issue 4: Race Condition: DB Reassignment**

`bootstrapAdminSession()` is called twice:
1. From `main()` at app startup
2. From `recipe_list_loader._defaultRepoBuilder()` as fallback

If a user saves biometric login in the middle of these two calls, there could be a race where `_db` is reassigned to a different database instance. However, both should open the same database file, so this is unlikely.

---

## 10. Recommended Investigation Steps

1. **Add detailed logging** to `_persistTrustedSession()`:
   - Log before INSERT
   - Log the map being inserted (including `active` value)
   - Log the result of INSERT
   - Log after UPDATE

2. **Add explicit transaction** in `_persistTrustedSession()`:
   ```dart
   await db.transaction((txn) async {
     await txn.insert(...);
     await txn.update(...);
   });
   ```

3. **Verify `active` column value** after save:
   - Query the database immediately after `saveCurrentSessionForBiometricLogin()` returns `true`
   - Check if the row exists with `active=1` and `token` is not null

4. **Check for soft deletes or filtering:**
   - Search for any code that reads from `auth_credentials` without `WHERE active=1`
   - Verify that no UI code is caching the row before it's updated

5. **Test on native platform**:
   - Log to file during biometric save
   - Restart app and check logs
   - Query database directly using sqlite3 CLI or Xcode debugger to inspect `auth_credentials` table

6. **Check if `_persistTrustedSession` is called at all:**
   - Add logging with a unique marker that includes timestamp
   - On next app launch, check if that marker appears in logs

---

## 11. Critical Code to Verify

### Check if password hash matters:

In `loginWithSavedTokenSession()` @ line 520-570:
```dart
Future<bool> loginWithSavedTokenSession() async {
  final db = _db;
  if (db == null) return false;

  final rows = await db.query(
    'auth_credentials',
    columns: ['login', 'token', 'preferred_language', 'is_admin'],
    where: "token IS NOT NULL AND token <> ''",  // ← CHECKS TOKEN, NOT HASH
    orderBy: 'updated_at DESC',
    limit: 1,
  );
  if (rows.isEmpty) return false;
  
  final row = rows.first;
  final login = row['login'] as String?;
  final token = row['token'] as String?;
  // ...
}
```

**This is for manual token restoration, not automatic bootstrap.**

The automatic bootstrap uses:
```dart
where: 'active = 1',  // ← NOT checking token value
```

**So the token can be null/empty and the row would still be marked active.**

---

## Conclusion

**Most likely root cause:** The `active` column is not being set to `1` correctly in the database, OR the row is being deactivated by another code path after save.

**Recommended immediate action:** Wrap `_persistTrustedSession()` in an explicit database transaction and add comprehensive logging to trace the exact state of the row before, during, and after the save operation.
