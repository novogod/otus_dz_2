# 13 — Client: optional global `appReloadTicker`

**Refs:** [categories.md §9.3](../docs/categories.md).
**Priority:** P3 (only if product asks).
**Scope:** `[client]`. **Depends on:** 03.

## Goal

If/when product wants a single button to refresh feed + favorites +
source pages, expose a separate `appReloadTicker` and subscribe each
page.

## Changes

* `recipe_list/lib/i18n.dart`:
  ```dart
  final ValueNotifier<int> appReloadTicker = ValueNotifier<int>(0);
  void requestAppReload() => appReloadTicker.value++;
  ```
* `recipe_list/lib/ui/source_page.dart`,
  `recipe_list/lib/ui/favorites_page.dart`: subscribe in
  `initState`/`dispose`, refetch on tick.
* `recipe_list/lib/ui/reload_icon_button.dart`: optional
  `bool global = false` flag. When `global == true`, calls
  `requestAppReload`; otherwise `requestFeedReload` (current behavior).
* No UI change unless a placement opts in.

## Acceptance

* Existing reload button on list page unchanged.
* New button (or long-press) explicitly bound to `global: true` triggers
  refresh on all three pages.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub`:
  * `appReloadTicker triggers source page reload`.
  * `appReloadTicker triggers favorites page reload`.
  * `feed reload does NOT touch source/favorites`.
