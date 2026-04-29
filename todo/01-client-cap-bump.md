# 01 — Client: bump sqflite cache cap

**Refs:** [categories.md §9.2 (a)](../docs/categories.md),
[translation-buffer.md §5.3](../docs/translation-buffer.md).
**Priority:** P0. **Scope:** `[client]`. **Owner:** TBD.

## Goal

Stop the LRU evictor from churning when the user has visited 4+ languages.

## Changes

* `recipe_list/lib/data/repository/recipe_repository.dart`:
  * `static const int _kCap = 8000;` (was `2000`).
  * `static const int _kByteCap = 64 * 1024 * 1024;` (was `5 * 1024 * 1024`).
* `recipe_list/lib/data/repository/recipe_repository.dart`: keep the
  constructor overrides; only defaults change.

## Acceptance

* No eviction during a scripted scenario "load EN → switch to RU → ES →
  FR → DE" with 200 recipes/lang on simulator.
* `repo.byteSize()` reports < 64 MB after the scenario.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub test/data/recipe_repository_test.dart`:
  * Existing tests pass with new caps.
  * Add: `evicts only when byteCap exceeded` — insert ~70 MB worth of
    fixture rows, assert oldest LRU rows removed in batches of 32 and
    `byteSize() <= byteCap`.
  * Add: `cap=8000 honored` — insert 8001 rows, assert 8000 retained.
* Manual: launch on iOS sim `8BD26741-3207-42F9-A0D4-55D0CC63AED0`,
  switch through 5 languages, no `evicted N rows` lines after the
  4th switch in `flutter logs`.
