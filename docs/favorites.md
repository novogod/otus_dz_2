# Favorites: per-language local persistence

**Status:** spec. **Owners:** otus_dz/recipe_list. **Related:**
[todo/15-favorites.md](../todo/15-favorites.md).

## Goal

Let the user mark a recipe as a favorite from the recipe card or the
details page, and review the marked recipes from the bottom-nav
"Favorites" tab. Favorites survive feed reload (the random-seeded
recipe list is wiped by the reload button — favorites must NOT be).

## UX

### Mark / unmark

* On the recipe card image, top-right corner, render a heart icon
  in the same 40×40 circular badge style and position as the existing
  YouTube `_YoutubeBadge` (translucent black background, white glyph).
* Outlined heart (`Icons.favorite_border`) when not a favorite.
* Tapping toggles state. While favorite: filled green heart
  (`Icons.favorite`, `AppColors.primary`).
* The same badge appears on the recipe details page hero image
  (top-right) with identical behavior.

### Favorites screen

* Bottom-nav "Favorites" tab (already in `AppNavTab.favorites`,
  `Icons.favorite_border`) navigates to a `FavoritesPage`.
* Renders a `RecipeListPage`-shaped grid of the saved recipes in
  reverse-chronological order (most recently added first).
* Empty state: localised "No favorites yet" hint.
* The reload button in the AppBar is **hidden** on this screen
  (`AppPageBar.showReload = false`) — favorites are user-curated,
  not seeded.
* Tapping a card opens the existing `RecipeDetailsPage`. The heart
  badge stays interactive there and round-trips state through the
  same store.

## Persistence model

Favorites are local-only, stored in the on-device sqflite database
shared with the recipe cache. Server has no notion of per-user
favorites at this stage.

### Per-language scope

Favorites are stored **per language** as a deliberate simplification:
each `(recipe_id, lang)` pair is its own row. Reasoning:

* Users tend to stay in their native language. Storing all locales
  for every favorite would 10× the cost in DB and translation calls
  for a feature the user almost never exercises.
* A favorite captures the recipe **as the user saw it** when they
  hearted it. Re-translating on language switch is an explicit
  choice — switch to TR, heart again to "save in Turkish".
* The Favorites screen renders only the rows whose `lang` matches
  the current `appLang`. Switching to a language with no favorites
  shows the empty state.

### Schema

`favorites` table on the existing `recipe_db` (bump
`kRecipeDbSchemaVersion` 5 → 6):

```sql
CREATE TABLE favorites (
  recipe_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  saved_at INTEGER NOT NULL,  -- millis since epoch
  PRIMARY KEY (recipe_id, lang)
);
CREATE INDEX favorites_by_lang_savedAt
  ON favorites (lang, saved_at DESC);
```

The recipe body itself is already cached in `recipe_bodies`
(`recipe_id`, `lang`); the favorites table only stores membership.
On the Favorites screen we `JOIN recipe_bodies USING (recipe_id, lang)`
to render. If the body row was evicted by the cache, we fall back
to a network `lookup` (favorites are rare enough that this is
acceptable).

### Migration

`onUpgrade(5 → 6)`: `CREATE TABLE favorites` + index. No data to
backfill.

## State management

Single `FavoritesStore` (a `ChangeNotifier`-like singleton, mirroring
the existing `appLang` / `reloadingFeed` notifiers):

* `Future<void> add(int recipeId, AppLang lang)`
* `Future<void> remove(int recipeId, AppLang lang)`
* `Future<bool> isFavorite(int recipeId, AppLang lang)`
* `ValueListenable<Set<int>> idsForLang(AppLang lang)` — UI rebinds
  per language switch.
* `Future<List<Recipe>> list(AppLang lang)` — joins `recipe_bodies`
  for the Favorites screen.

The heart badge subscribes to `idsForLang(appLang.value)` and rebuilds
on insert/remove.

## What is NOT in scope

* Cross-device sync. Favorites do not live on the server.
* Migrating favorites between languages (no "show my IT favorites
  while UI is in TR" mode — by design).
* Folders / tags / notes on a favorite.
* Bulk "favorite a category".
* iOS-style swipe-to-delete on the Favorites screen (long-press menu
  is fine for v1).
* Server-side analytics on favorite events.

## Acceptance

* Heart badge renders on every recipe card and details page in the
  exact position and visual weight of the YouTube badge.
* Tapping toggles outlined ↔ filled-green within one frame; state
  persists across app restart.
* `favorites` table created on first launch after upgrade; existing
  caches are NOT cleared.
* Reload button on Recipes tab does NOT touch the `favorites` table
  (only `recipes` / `recipe_bodies` are eligible for reseed eviction).
* Favorites screen renders only rows where `lang == appLang.value`.
  Switching language live updates the screen.
* `flutter analyze` clean. New unit tests for `FavoritesStore` +
  widget test for the heart toggle.
