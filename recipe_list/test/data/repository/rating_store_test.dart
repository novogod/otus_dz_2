import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/data/api/recipe_api.dart';
import 'package:recipe_list/data/repository/rating_store.dart';

class _FakeRecipeApi implements RecipeApi {
  _FakeRecipeApi(this._snapshot);

  RecipeRatingSnapshot _snapshot;
  bool fail = false;
  int setCalls = 0;
  int clearCalls = 0;
  int? lastStars;

  @override
  Future<RecipeRatingSnapshot?> fetchRating(int recipeId) async => _snapshot;

  @override
  Future<RecipeRatingSnapshot> setRating(int recipeId, int stars) async {
    setCalls++;
    lastStars = stars;
    if (fail) throw StateError('boom');
    _snapshot = RecipeRatingSnapshot(
      count: _snapshot.my == null ? _snapshot.count + 1 : _snapshot.count,
      sum: _snapshot.my == null
          ? _snapshot.sum + stars
          : _snapshot.sum + (stars - _snapshot.my!),
      my: stars,
    );
    return _snapshot;
  }

  @override
  Future<RecipeRatingSnapshot> clearRating(int recipeId) async {
    clearCalls++;
    if (fail) throw StateError('boom');
    _snapshot = RecipeRatingSnapshot(
      count: (_snapshot.count - 1).clamp(0, 1 << 31),
      sum: (_snapshot.sum - (_snapshot.my ?? 0)).clamp(0, 1 << 31),
      my: null,
    );
    return _snapshot;
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('RatingStore', () {
    test('watch seeds with initial snapshot', () {
      final api = _FakeRecipeApi(
        const RecipeRatingSnapshot(count: 0, sum: 0, my: null),
      );
      final store = RatingStore(api: api);
      final l = store.watch(
        42,
        initial: const RecipeRatingSnapshot(count: 5, sum: 20, my: 4),
      );
      expect(l.value.count, 5);
      expect(l.value.sum, 20);
      expect(l.value.my, 4);
    });

    test('setMyRating optimistic — first vote bumps count and sum', () async {
      final api = _FakeRecipeApi(
        const RecipeRatingSnapshot(count: 10, sum: 30, my: null),
      );
      final store = RatingStore(api: api);
      store.watch(
        1,
        initial: const RecipeRatingSnapshot(count: 10, sum: 30, my: null),
      );
      await store.setMyRating(1, 5);
      final s = store.snapshot(1)!;
      expect(s.count, 11);
      expect(s.sum, 35);
      expect(s.my, 5);
      expect(api.setCalls, 1);
      expect(api.lastStars, 5);
    });

    test('setMyRating re-rate adjusts sum by delta', () async {
      final api = _FakeRecipeApi(
        const RecipeRatingSnapshot(count: 5, sum: 15, my: 3),
      );
      final store = RatingStore(api: api);
      store.watch(
        1,
        initial: const RecipeRatingSnapshot(count: 5, sum: 15, my: 3),
      );
      await store.setMyRating(1, 5);
      final s = store.snapshot(1)!;
      expect(s.count, 5);
      expect(s.sum, 17);
      expect(s.my, 5);
    });

    test('setMyRating reverts on failure', () async {
      final api = _FakeRecipeApi(
        const RecipeRatingSnapshot(count: 0, sum: 0, my: null),
      )..fail = true;
      final store = RatingStore(api: api);
      store.watch(
        1,
        initial: const RecipeRatingSnapshot(count: 0, sum: 0, my: null),
      );
      await expectLater(store.setMyRating(1, 4), throwsStateError);
      final s = store.snapshot(1)!;
      expect(s.count, 0);
      expect(s.sum, 0);
      expect(s.my, isNull);
    });

    test('clearMyRating removes vote and decrements count/sum', () async {
      final api = _FakeRecipeApi(
        const RecipeRatingSnapshot(count: 5, sum: 15, my: 3),
      );
      final store = RatingStore(api: api);
      store.watch(
        1,
        initial: const RecipeRatingSnapshot(count: 5, sum: 15, my: 3),
      );
      await store.clearMyRating(1);
      final s = store.snapshot(1)!;
      expect(s.count, 4);
      expect(s.sum, 12);
      expect(s.my, isNull);
      expect(api.clearCalls, 1);
    });

    test('clearMyRating no-op when no prior vote', () async {
      final api = _FakeRecipeApi(
        const RecipeRatingSnapshot(count: 5, sum: 15, my: null),
      );
      final store = RatingStore(api: api);
      store.watch(
        1,
        initial: const RecipeRatingSnapshot(count: 5, sum: 15, my: null),
      );
      await store.clearMyRating(1);
      expect(api.clearCalls, 0);
    });
  });
}
