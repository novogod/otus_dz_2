// Chunk G of docs/user-card-and-social-signals.md.
//
// Lightweight in-memory store for recipe ratings. Unlike
// [FavoritesStore], we don't cache ratings in sqflite — the
// aggregate (`count`, `sum`, `avg`) is small, lives on the
// server, and changes constantly across users. Caching it
// locally would only add staleness without saving bandwidth.
//
// What we do cache, in memory only:
//   * `RecipeRatingSnapshot` per recipe id, fetched once on first
//     view of a rating row;
//   * the user's own vote (`my`), updated optimistically.
//
// Optimistic-update flow:
//   1. UI calls [setMyRating]: store flips local state to `stars`,
//      bumps `count`/`sum` if this is the first vote, or adjusts
//      `sum` by the delta when re-rating.
//   2. UI rebuilds via the [ValueListenable].
//   3. Network call runs in the background. On 4xx/network error
//      we revert to the previous snapshot and rethrow so the UI
//      can surface a snackbar.
//
// The store is intentionally process-singleton (held by
// [ratingStoreNotifier]) just like favorites — recipe details and
// the list card need to share the same in-memory map so a vote
// cast on the details page is visible on the card without a
// re-fetch.

import 'package:flutter/foundation.dart';

import '../api/recipe_api.dart';

/// Global holder for the active [RatingStore]. Filled by the
/// repository factory after the API client is configured.
/// `null` means "not initialised yet" — UI renders the rating row
/// as read-only with whatever aggregate came back in the recipe
/// payload.
final ValueNotifier<RatingStore?> ratingStoreNotifier =
    ValueNotifier<RatingStore?>(null);

/// In-memory store of recipe ratings. See file header for design
/// rationale.
class RatingStore {
  RatingStore({required RecipeApi api}) : _api = api;

  final RecipeApi _api;
  final Map<int, ValueNotifier<RecipeRatingSnapshot>> _byId = {};

  /// Returns a live listenable for the rating snapshot of a
  /// recipe. Seeds it with the optional [initial] aggregate (the
  /// server already projected `ratingsCount` / `ratingsSum` /
  /// `myRating` into the recipe payload, so we use that as the
  /// initial value to avoid an extra round trip).
  ValueListenable<RecipeRatingSnapshot> watch(
    int recipeId, {
    RecipeRatingSnapshot? initial,
  }) {
    final existing = _byId[recipeId];
    if (existing != null) return existing;
    final seed =
        initial ?? const RecipeRatingSnapshot(count: 0, sum: 0, my: null);
    final notifier = ValueNotifier<RecipeRatingSnapshot>(seed);
    _byId[recipeId] = notifier;
    return notifier;
  }

  /// Latest snapshot in memory, or null if nothing has been
  /// observed yet.
  RecipeRatingSnapshot? snapshot(int recipeId) => _byId[recipeId]?.value;

  /// Refreshes a recipe's rating from the server. Best-effort —
  /// keeps the previous in-memory value if the network is down.
  Future<RecipeRatingSnapshot?> refresh(int recipeId) async {
    final fresh = await _api.fetchRating(recipeId);
    if (fresh == null) return _byId[recipeId]?.value;
    _byId
        .putIfAbsent(
          recipeId,
          () => ValueNotifier<RecipeRatingSnapshot>(fresh),
        )
        .value = fresh;
    return fresh;
  }

  /// Records the caller's rating optimistically. Reverts on any
  /// failure (network, 401, 422) and rethrows so the caller can
  /// show a snackbar.
  Future<void> setMyRating(int recipeId, int stars) async {
    assert(stars >= 1 && stars <= 5, 'stars out of range: $stars');
    final notifier = _byId.putIfAbsent(
      recipeId,
      () => ValueNotifier<RecipeRatingSnapshot>(
        const RecipeRatingSnapshot(count: 0, sum: 0, my: null),
      ),
    );
    final previous = notifier.value;

    // Optimistic update: if no previous vote, count += 1, sum +=
    // stars; otherwise just adjust sum by the delta.
    final newCount = previous.my == null ? previous.count + 1 : previous.count;
    final newSum = previous.my == null
        ? previous.sum + stars
        : previous.sum + (stars - previous.my!);
    notifier.value = RecipeRatingSnapshot(
      count: newCount,
      sum: newSum,
      my: stars,
    );

    try {
      final fresh = await _api.setRating(recipeId, stars);
      notifier.value = fresh;
    } on Object {
      notifier.value = previous;
      rethrow;
    }
  }

  /// Removes the caller's rating. Optimistic + revert on failure.
  Future<void> clearMyRating(int recipeId) async {
    final notifier = _byId[recipeId];
    if (notifier == null) return;
    final previous = notifier.value;
    if (previous.my == null) return;

    final newCount = (previous.count - 1).clamp(0, 1 << 31);
    final newSum = (previous.sum - previous.my!).clamp(0, 1 << 31);
    notifier.value = RecipeRatingSnapshot(
      count: newCount,
      sum: newSum,
      my: null,
    );

    try {
      final fresh = await _api.clearRating(recipeId);
      notifier.value = fresh;
    } on Object {
      notifier.value = previous;
      rethrow;
    }
  }

  /// Test-only: wipe all in-memory state.
  @visibleForTesting
  void debugReset() => _byId.clear();
}
