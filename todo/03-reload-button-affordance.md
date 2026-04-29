# 03 — Client: lightweight Reload affordance

**Refs:** [categories.md §9.7](../docs/categories.md).
**Priority:** P2. **Scope:** `[client]`.

## Goal

Replace the heavy full-screen `_LoadingScreen` overlay during Reload
with: spinning refresh icon + slim `LinearProgressIndicator` in the
AppBar bottom strip.

## Changes

* `recipe_list/lib/ui/reload_icon_button.dart`:
  * Accept `bool spinning` (or read a `ValueListenable<bool>`).
  * Wrap `Icon(Icons.refresh)` in `AnimatedRotation` driven by a
    `Tween<double>(0, 1)` looping while `spinning == true`.
* `recipe_list/lib/ui/app_page_bar.dart`:
  * Add `PreferredSize` bottom of height 2 — `LinearProgressIndicator`
    when `showReload && reloading`.
  * Pipe `reloading` through new `ValueNotifier<bool> reloadingFeed` in
    `i18n.dart` (set in `RecipeListLoader._onReloadRequested`).
* `recipe_list/lib/ui/recipe_list_loader.dart`:
  * Do **not** flip the global `_translating` (which gates
    `_LoadingScreen`) when triggered by reload — set `reloadingFeed`
    instead. `_LoadingScreen` only on cold start / language switch.
* Tokens to use: `AppColors.primary`, `motion.medium` (use
  `kThemeAnimationDuration`).

## Acceptance

* Tap Reload → icon spins, thin bar under AppBar, recipe list still
  visible and scrollable.
* Cold start unchanged: full `_LoadingScreen` shown.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub`:
  * Widget test `reload spins icon and shows linear progress` —
    pump-find `LinearProgressIndicator` after triggering `requestFeedReload`.
  * Widget test `cold start shows _LoadingScreen` — sanity guard.
* Manual: visual smoke on iOS sim.
