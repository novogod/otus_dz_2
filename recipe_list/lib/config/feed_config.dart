/// Tunables for the recipe-feed loader. Extracted from
/// `recipe_list_loader.dart` so they can be overridden via
/// `--dart-define` at build time without recompiling logic.
///
/// See docs/categories.md §9.4 and todo/04-feed-config-extraction.md.
class FeedConfig {
  /// Target number of recipes to assemble in a single feed pass.
  final int seedTarget;

  /// How many random categories to pick per pass.
  final int seedPickCount;

  /// If a category already has >= this many cached rows, skip
  /// re-fetching and serve from sqflite.
  final int categoryCacheThreshold;

  /// Max concurrent `/lookup` requests during retranslate.
  final int translateConcurrency;

  const FeedConfig({
    this.seedTarget = 200,
    this.seedPickCount = 10,
    this.categoryCacheThreshold = 10,
    this.translateConcurrency = 8,
  });

  /// Reads overrides from `--dart-define` flags. Names are stable
  /// and documented in todo/04-feed-config-extraction.md.
  factory FeedConfig.fromDartDefine() => const FeedConfig(
        seedTarget: int.fromEnvironment(
          'FEED_SEED_TARGET',
          defaultValue: 200,
        ),
        seedPickCount: int.fromEnvironment(
          'FEED_SEED_PICK_COUNT',
          defaultValue: 10,
        ),
        categoryCacheThreshold: int.fromEnvironment(
          'FEED_CATEGORY_CACHE_THRESHOLD',
          defaultValue: 10,
        ),
        translateConcurrency: int.fromEnvironment(
          'FEED_TRANSLATE_CONCURRENCY',
          defaultValue: 8,
        ),
      );
}
