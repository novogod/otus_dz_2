# PWA installed-mode bugs — May 2026 round

**Date:** 2026-05-05

**Status:** ✅ Shipped (commits `87040f2`, `ca3dd80`, `68375ac`)

Three bugs surfaced in the installed PWA on `recipies.mahallem.ist`
right after Chunk F (server-side SEO) went out. None of them
reproduced in a regular browser tab — installed PWAs run in a
different `display-mode`, persist IndexedDB across schema migrations
much longer, and keep a single Flutter session alive long enough to
expose seq-guard race conditions. Fixes shipped one by one as the
user reported them.

---

## 1. AppBar action buttons not clickable in installed PWA

**Symptom:** in the installed PWA (`display-mode: standalone`) the
language / share / reload buttons in the top-right corner of the
recipe-list AppBar swallowed taps. The system back button worked.

**Diagnosis:** Flutter web reports `MediaQuery.padding.top == 0` in
standalone mode — it doesn't see the iOS status bar / Android
window-chrome that's overlaid on top of the canvas. The upper half of
the AppBar buttons sits *under* that overlay, which silently eats the
hit-test before Flutter sees it. The back button worked only because
its visible footprint was further from the top edge.

**Fix (`87040f2`)** — pure CSS in [recipe_list/web/index.html](../recipe_list/web/index.html):

```css
@media (display-mode: standalone),
       (display-mode: window-controls-overlay),
       (display-mode: minimal-ui) {
  flutter-view, flt-glass-pane {
    top: env(safe-area-inset-top, 0px) !important;
    height: calc(100% - env(safe-area-inset-top, 0px)) !important;
  }
}
```

Same rules also apply via an `html.pwa-standalone` class set by the
existing `window.isPwaStandalone()` JS check, as a fallback for iOS
< 16 where the `display-mode` media query may not fire reliably. The
freed strip is filled by `body { background: #2ECC71 }` (theme
colour) so it doesn't read as a white gap.

**Verification:** user confirmed "All works now" on the installed PWA.

---

## 2. Reload spinner stuck forever after language switch / details

**Symptom:** in the installed PWA, after switching language or
returning from the details page, tapping the reload action in the
AppBar started the spinner and it never stopped, even though the feed
itself had refreshed.

**Diagnosis:** in [recipe_list/lib/ui/recipe_list_loader.dart](../recipe_list/lib/ui/recipe_list_loader.dart)
both `_onReloadRequested` and `_onLangChanged` increment
`_translateSeq`. The reload's `whenComplete` reset
`reloadingFeed.value = false` *inside* an `if (seq == _translateSeq)`
guard. The guard exists to drop stale data-side results when a newer
load supersedes them — but it has no business gating a UI flag
(`reloadingFeed`) whose only consumer is the spinner that the user
just initiated. Any concurrent activity (a queued language switch,
the details page returning) bumped the seq and the spinner reset was
silently skipped.

**Fix (`ca3dd80`)** — move the spinner reset out of the seq guard:

```dart
.whenComplete(() {
  if (mounted) reloadingFeed.value = false; // unconditional
});
```

The seq guard remains correctly applied to `.then` / `.catchError`
branches that mutate the feed state.

---

## 3. `SQLITE_CORRUPT (code 11)` — "database disk image is malformed"

**Symptom:** installed PWA showed full-screen
`Ошибка загрузки: SqfliteFfiException(sqlite_error: 11, …,
database disk image is malformed (code 11) Causing statement:
SELECT * FROM recipes WHERE lang = ? ORDER BY last_used_at DESC
LIMIT 200, parameters: ru)`. The Retry button just re-armed the same
broken DB. Only a "Clear site data" / reinstall would unblock the
user.

**Diagnosis:** the recipe DB on web is an IndexedDB-persisted
sqlite3.wasm file (`recipes.db`, schema v11). After enough months of
use, browser quota eviction, an aborted transaction, or a worker-mode
→ no-worker-mode migration can leave a half-written page. The DB
header opens fine, so `openDatabase` succeeds, but a later `SELECT *`
trips over the corrupt page and throws.

**Fix (`68375ac`)** — two recovery layers, sharing one error
classifier:

* New helper in [recipe_list/lib/data/local/recipe_db.dart](../recipe_list/lib/data/local/recipe_db.dart):

  ```dart
  bool isCorruptDbError(Object error) {
    final m = error.toString().toLowerCase();
    return m.contains('malformed')
        || m.contains('sqlite_error: 11')
        || m.contains('sqliteexception(11)')
        || m.contains('not a database');
  }

  Future<void> deleteRecipeDatabaseWebOnly() async { … }
  ```

* **Open-time recovery** — `openRecipeDatabase()` catches the open
  failing with a corrupt-error, deletes the IndexedDB snapshot, and
  re-creates the schema.

* **Runtime recovery** — `_runLoad` in [recipe_list/lib/ui/recipe_list_loader.dart](../recipe_list/lib/ui/recipe_list_loader.dart)
  wraps `_runLoadImpl` in a classify-and-retry shell. If a corrupt
  error escapes from a later query (the screenshot's case — `DB
  opens, then SELECT explodes`), the cache is wiped, the global
  `favoritesStoreNotifier` and `ownedRecipesStoreNotifier` are
  nulled out (they hold the now-invalid `Database` instance), and
  the load is retried once. The retry rebuilds the repo via
  `_defaultRepoBuilder`, opens a clean DB, and falls through to a
  fresh network seed.

Cache loss is acceptable here — the favourites table is
re-populated from the server on the next `ensureLoaded`, and recipes
are re-fetched from the listing endpoints.

**Verification path:** close all PWA windows, reopen — feed loads
fresh from network, no error screen.

---

## Lessons

* Installed-PWA mode is a different runtime profile from the browser
  tab and needs its own smoke-test: safe-area inset, long-lived
  session, IndexedDB persistence across schema versions.
* UI flags (`reloadingFeed`) and data-side state are different
  concerns; do not gate UI resets behind seq counters intended for
  data-side staleness.
* Anything stored in IndexedDB will eventually return malformed data
  to a long-running install. Plan a wipe-and-retry recovery from day
  one rather than crashing into a dead-end error screen.
