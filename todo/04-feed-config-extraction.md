# 04 — Client: extract feed magic constants

**Refs:** [categories.md §9.4](../docs/categories.md).
**Priority:** P2. **Scope:** `[client]`.

## Goal

Move `_seedTarget`, `_seedPickCount`, `_categoryCacheThreshold`,
`_translateConcurrency` out of `recipe_list_loader.dart` so they can be
tuned without recompiling logic.

## Changes

* New file `recipe_list/lib/config/feed_config.dart`:
  ```dart
  class FeedConfig {
    final int seedTarget;
    final int seedPickCount;
    final int categoryCacheThreshold;
    final int translateConcurrency;
    const FeedConfig({
      this.seedTarget = 200,
      this.seedPickCount = 10,
      this.categoryCacheThreshold = 10,
      this.translateConcurrency = 8,
    });
    factory FeedConfig.fromDartDefine() => const FeedConfig(
      seedTarget: int.fromEnvironment('FEED_SEED_TARGET', defaultValue: 200),
      // …
    );
  }
  ```
* `recipe_list/lib/ui/recipe_list_loader.dart`: take `FeedConfig` via
  constructor (default `FeedConfig.fromDartDefine()`); replace `static
  const` references with instance fields.

## Acceptance

* `flutter run --dart-define=FEED_SEED_TARGET=50` produces a feed
  capped at 50 recipes.
* Defaults unchanged for normal builds.

## Tests

* `flutter analyze` clean.
* `flutter test --no-pub`:
  * Existing loader tests pass after constructor injection.
  * Add: `loader respects FeedConfig.seedTarget` — pass `seedTarget:
    20`, mock API, assert accumulator stops at 20.
