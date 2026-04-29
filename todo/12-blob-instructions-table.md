# 12 — Client: lazy-load recipe instructions

**Refs:** [categories.md §9.2 (c)](../docs/categories.md).
**Priority:** P2. **Scope:** `[client]`. **Depends on:** 01.

## Goal

Stop carrying the full HTML `instructions` blob inline in every list-row.
On the list screen we only need name/category/thumb; the heavy field
(usually 60–80 % of row bytes) should load on demand in the details
screen.

## Changes

* `recipe_list/lib/data/local/recipe_db.dart`:
  * Migration v3: split `recipes.instructions` into a sibling table
    `recipe_bodies(id INTEGER, lang TEXT, instructions TEXT, PRIMARY
    KEY(id, lang))`.
  * `recipes.instructions` column dropped (or kept NULLable; preferred:
    drop with a one-shot copy migration).
* `recipe_list/lib/data/repository/recipe_repository.dart`:
  * `upsertAll` writes both tables in a transaction.
  * New `Future<String?> getInstructions(int id, String lang)`.
  * Eviction: when the row in `recipes` is evicted, cascade-delete the
    corresponding `recipe_bodies` row (FK + ON DELETE CASCADE if
    sqflite supports; otherwise manual delete in `_evict`).
* `recipe_list/lib/ui/recipe_details_page.dart`:
  * `FutureBuilder` over `repo.getInstructions(...)`; show shimmer while
    loading.

## Acceptance

* `repo.byteSize()` for 200 recipes drops by ≥ 50 % vs previous schema.
* Details page renders within 200 ms on warm DB; ≤ 800 ms on cold disk.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub`:
  * `migration v2→v3 copies instructions then drops column` (in-memory
    sqflite).
  * `getInstructions returns null after eviction`.
  * `details page shows shimmer until instructions load`.
