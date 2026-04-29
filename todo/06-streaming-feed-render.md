# 06 — Client: streaming feed render

**Refs:** [categories.md §9.1 (d)](../docs/categories.md).
**Priority:** P1. **Scope:** `[client]`. **Depends on:** 02, 03.

## Goal

Show the first batch of recipes as soon as the *first* category arrives
from `mahallem-user-portal`, instead of waiting until
`accumulator.length >= _seedTarget`.

## Changes

* `recipe_list/lib/ui/recipe_list_loader.dart`:
  * Convert `_seedFromCategories` to emit a `Stream<List<Recipe>>`
    (or push partial results via `setState` after each `filterByCategory`).
  * After the first non-empty batch is persisted via `repo.upsertAll`,
    set `_recipes = batch` and clear `_translating`. The
    `LinearProgressIndicator` (chunk 03) keeps spinning until the
    accumulator hits `_seedTarget` or runs out of categories.
  * Subsequent batches dedupe by `recipe.id` and append.

## Acceptance

* On a fresh language with empty cache, first cards appear within
  ~200 ms of the first HTTP response, regardless of how slow the rest of
  the cascade is.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub`:
  * Widget test `streaming render shows first batch before completion`
    — mock API yielding 3 staggered batches, assert `find.byType(RecipeCard)`
    after first batch.
  * Add: `dedupes recipe ids across categories` — two batches share
    one `id`, assert only one card present.
