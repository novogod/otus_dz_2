# 11 — Client: per-language LRU partitioning

**Refs:** [categories.md §9.2 (b)](../docs/categories.md).
**Priority:** P2. **Scope:** `[client]`. **Depends on:** 01.

## Goal

Switching language must not evict the user's primary language cache.
Give the active language a dedicated budget; treat others as a
soft-budget shared pool.

## Changes

* `recipe_list/lib/data/repository/recipe_repository.dart`:
  * Replace single `_evict()` with `_evict({required String activeLang})`:
    * Compute `activeBytes`, `othersBytes`.
    * Active budget: 60 % of `byteCap` (≈ 38 MB at 64 MB).
    * Others budget: 40 %.
    * Evict from `others` first (LRU within non-active rows). Only fall
      through to active rows if they alone exceed their own budget.
* `RecipeRepository.upsertAll(...)` already knows the lang being
  written — pass it as `activeLang`.

## Acceptance

* Scenario: load 1000 RU recipes (heavy) → switch to TR (200 recipes).
  After switch, `repo.byteSize(lang: 'ru')` is unchanged.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub`:
  * `eviction prefers non-active lang first` — seed 70 MB across 5
    langs, write to active lang, assert active lang row count
    unchanged.
  * `falls through to active lang when only it overflows` — fill only
    active lang past its 60 % budget, assert oldest active rows
    evicted.
