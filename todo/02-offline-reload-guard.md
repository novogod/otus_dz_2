# 02 — Client: offline-safe Reload

**Refs:** [categories.md §9.6](../docs/categories.md).
**Priority:** P1. **Scope:** `[client]`.

## Goal

Tapping Reload while offline must keep the current feed and surface a
SnackBar instead of clearing to a blank/error state.

## Changes

* `recipe_list/lib/ui/recipe_list_loader.dart`:
  * In `_onReloadRequested`: probe connectivity (use existing
    `connectivity_plus` provider if present; else attempt a HEAD on
    `${api.base}/health` with 3 s timeout).
  * If offline → call `ScaffoldMessenger.of(ctx).showSnackBar(...)` with
    `s.offlineReloadUnavailable`, do **not** flip `_translating=true`,
    do not call `_runLoad`.
  * If online but `_runLoad` throws `DioException.connectionError` → same
    SnackBar, restore previous `_recipes` (snapshot before call).
* `recipe_list/lib/i18n.dart` + 10 `*.i18n.json`: new key
  `a11y.offlineReloadUnavailable`.
* `dart run slang` to regenerate `strings*.g.dart`.

## Acceptance

* Toggle airplane mode → tap Reload → SnackBar visible, feed unchanged.
* Server returns 502 mid-reload → feed unchanged, SnackBar visible.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub test/ui/recipe_list_loader_test.dart`:
  * `reload while offline keeps feed and shows snackbar` (mock
    `Connectivity` + `RecipeApi`).
  * `reload network error restores previous feed`.
* Manual on iOS sim: airplane mode → Reload → SnackBar; back online →
  Reload → fresh feed.
