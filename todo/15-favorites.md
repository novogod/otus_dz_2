# 15 — Favorites: per-language local persistence

**Refs:** [docs/favorites.md](../docs/favorites.md). **Priority:** P1.
**Scope:** `[client]` only — no server changes.

Goal: persist user-marked favorite recipes per language in sqflite,
expose via heart badge on the card / details, and the bottom-nav
"Favorites" tab.

Implementation is split into **5 chunks**. Each chunk lands as its
own commit, with tests that pass before moving on.

---

## Chunk A — DB schema + store (no UI)

### Changes
* `recipe_list/lib/data/local/recipe_db.dart`:
  * Bump `kRecipeDbSchemaVersion` 5 → 6.
  * Append to `applyRecipeSchema`: `CREATE TABLE favorites (...)`,
    `CREATE INDEX favorites_by_lang_savedAt`.
  * `onUpgrade(5 → 6)`: same `CREATE TABLE` / index, idempotent.
* `recipe_list/lib/data/repository/favorites_store.dart` (new):
  * `class FavoritesStore` with the API in
    [docs/favorites.md](../docs/favorites.md) §"State management".
  * Internal `Map<AppLang, ValueNotifier<Set<int>>>` + sqflite
    backing.

### Tests
* `recipe_list/test/data/favorites_store_test.dart`:
  * `add` → `isFavorite` → `remove` round-trip.
  * Per-lang isolation: `add(id, en)` does not surface in `idsForLang(tr)`.
  * `list(lang)` returns rows in `saved_at DESC` order.
* `recipe_list/test/data/recipe_db_migration_test.dart`:
  * Open with schema 5 fixture, expect upgrade to 6, `favorites`
    table present and empty.

### Acceptance
* `flutter test test/data/` green.

---

## Chunk B — Heart badge on recipe card

### Changes
* `recipe_list/lib/ui/recipe_card.dart`:
  * Add `_FavoriteBadge` mirror of `_YoutubeBadge`: same size /
    position (top-right of image), translucent black background.
  * Outlined heart (`Icons.favorite_border`, white) when not fav;
    filled (`Icons.favorite`, `AppColors.primary`) when fav.
  * Subscribes to `FavoritesStore.idsForLang(appLang.value)`.
  * `onTap`: toggle via store; `HapticFeedback.lightImpact()`.
* If both YouTube and Favorite badges exist on the same card, stack
  them vertically with `AppSpacing.xs` gap. Favorite goes ABOVE
  YouTube (top-right outermost).

### Tests
* `recipe_list/test/ui/recipe_card_favorite_test.dart`:
  * Pump card with no favorite → outlined heart visible.
  * Tap → store contains id; widget rebuilds with filled heart.
  * Tap again → store empty; widget back to outlined.

### Acceptance
* `flutter analyze` clean. Widget test green.

---

## Chunk C — Heart badge on details page

### Changes
* `recipe_list/lib/ui/recipe_details_page.dart`:
  * Same `_FavoriteBadge` overlaid top-right of the hero image.
  * Toggling on details reflects on the underlying card when the
    user pops back.

### Tests
* `recipe_list/test/ui/recipe_details_favorite_test.dart`:
  * Mark on details → pop → card shows filled heart.

### Acceptance
* Manual: mark/unmark on details, hot-restart, state preserved.

---

## Chunk D — Favorites tab + screen

### Changes
* `recipe_list/lib/ui/favorites_page.dart` (new):
  * `RecipeListPage`-shaped grid backed by
    `FavoritesStore.list(appLang.value)`.
  * Empty state: localised hint via `s.favoritesEmpty`.
  * Reuses `RecipeCard`.
  * AppBar: `AppPageBar(title: s.tabFavorites, showReload: false)`.
* `recipe_list/lib/main.dart` (or wherever the bottom-nav router
  lives): wire `AppNavTab.favorites` → `FavoritesPage`.
* `recipe_list/lib/i18n/strings_*.g.dart`: add `favoritesEmpty`
  string in 10 locales (run `slang build` after editing the
  source `strings.i18n.yaml`).

### Tests
* `recipe_list/test/ui/favorites_page_test.dart`:
  * Empty store → empty-state hint visible.
  * Two saved → grid renders 2 cards in `saved_at DESC` order.
  * Switching `appLang` mid-test refreshes content.

### Acceptance
* Tapping nav heart navigates to the screen; reload button absent.

---

## Chunk E — Polish + project_log

### Changes
* `docs/project_log.md`: 2026-04-30+ entry summarising chunks A-D.
* Verify reload button on Recipes tab does NOT touch `favorites`
  table — add a regression test that reload-flow preserves a
  favorite record.
* Hot-restart manual sweep across iOS / Android / web.

### Tests
* `recipe_list/test/data/favorites_survives_reload_test.dart`:
  * Add favorite → trigger feed reload (`requestFeedReload`) →
    favorite still present.

### Acceptance
* `flutter analyze` clean. All new test files green.
* `flutter test` baseline preserved (existing tests untouched).

---

## Out of scope (do NOT do here)

* Server-side favorite endpoint or sync.
* Cross-language favorite migration UI.
* Sharing / exporting favorites.
* Folders / collections.
