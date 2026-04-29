# 08 — Client: `_seedFromBulkPage` cold-start path

**Refs:** [categories.md §9.1 (b)](../docs/categories.md),
[translation-buffer.md §5.4](../docs/translation-buffer.md).
**Priority:** P1. **Scope:** `[client]`. **Depends on:** 07.

## Goal

On cold start (or when the cache for current `lang` is empty), fetch
recipes via `/recipes/page` instead of fanning out to 14 categories.

## Changes

* `recipe_list/lib/data/api/recipe_api.dart`: new `Future<RecipePage>
  fetchPage({required String lang, int offset, int limit})`.
* `recipe_list/lib/ui/recipe_list_loader.dart`:
  * Add `_seedFromBulkPage(...)` mirror of `_seedFromCategories`.
  * Decision in `_runLoad`:
    ```dart
    if (forceReseed) return _seedFromCategories(...); // keeps random shuffle UX
    if (cacheEmpty)   return _seedFromBulkPage(...);  // cold start fast path
    return _seedFromCategories(...);                  // legacy partial-fill
    ```
  * Behind a feature flag `--dart-define=USE_BULK_PAGE=1` (default off
    until smoke-tested in prod).

## Acceptance

* Cold start with empty sqflite + warm server cache → first batch in
  ≤ 2 s vs ≤ 60 s today.
* `forceReseed: true` (Reload button) still uses random categories.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub`:
  * `cold start uses bulk page when flag enabled` — mock API, assert
    `fetchPage` called once, `filterByCategory` not called.
  * `reload button still uses categories` — assert `filterByCategory`
    called even when bulk-page flag is on.
