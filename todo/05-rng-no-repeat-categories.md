# 05 — Client: avoid repeating last picked categories

**Refs:** [categories.md §9.5](../docs/categories.md).
**Priority:** P2. **Scope:** `[client]`.

## Goal

Two consecutive Reload taps must show *different* categories, not the
same RNG draw.

## Changes

* `recipe_list/lib/ui/recipe_list_loader.dart`:
  * Add `List<String> _lastPickedCategories = const [];`.
  * Refactor `_pickCategories()` → method on the State (not static):
    ```dart
    List<String> _pickCategories() {
      final pool = _allCategories
          .where((c) => !_lastPickedCategories.contains(c))
          .toList()..shuffle();
      // If pool depleted (we just used >=4 distinct draws), fall back
      // to full shuffle so we never starve.
      final base = pool.length >= _seedPickCount
          ? pool
          : ([..._allCategories]..shuffle());
      final picked = base.take(_seedPickCount).toList(growable: false);
      _lastPickedCategories = picked;
      return picked;
    }
    ```

## Acceptance

* Sequence of three reloads → no recipe-category repeats between
  consecutive draws.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub`:
  * Add: `consecutive reloads pick disjoint categories until pool
    exhausted` — call `_pickCategories()` twice, assert
    `Set.intersection` empty.
  * Add: `falls back to full shuffle when pool too small` — seed
    `_lastPickedCategories` with 12 of 14 categories, assert returned
    list still has 10 items (pool refilled).
