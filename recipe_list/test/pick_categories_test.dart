import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/ui/recipe_list_loader.dart';

void main() {
  const pool = [
    'Beef',
    'Breakfast',
    'Chicken',
    'Dessert',
    'Goat',
    'Lamb',
    'Miscellaneous',
    'Pasta',
    'Pork',
    'Seafood',
    'Side',
    'Starter',
    'Vegan',
    'Vegetarian',
  ];

  group('RecipeListLoader.pickCategoriesFor', () {
    test('returns exactly count items', () {
      final picked = RecipeListLoader.pickCategoriesFor(
        count: 10,
        pool: pool,
        exclude: const [],
      );
      expect(picked, hasLength(10));
      expect(picked.every(pool.contains), isTrue);
    });

    test('avoids categories from exclude when pool large enough', () {
      final exclude = pool.take(4).toList();
      final picked = RecipeListLoader.pickCategoriesFor(
        count: 10,
        pool: pool,
        exclude: exclude,
      );
      expect(picked, hasLength(10));
      // 14 - 4 = 10 remaining, exact match → no overlap.
      expect(
        picked.toSet().intersection(exclude.toSet()),
        isEmpty,
      );
    });

    test('falls back to full shuffle when remaining pool too small', () {
      final exclude = pool.take(12).toList();
      final picked = RecipeListLoader.pickCategoriesFor(
        count: 10,
        pool: pool,
        exclude: exclude,
      );
      // Only 2 items would be left after exclude → fallback returns
      // 10 from the full pool (overlap allowed).
      expect(picked, hasLength(10));
    });

    test('two consecutive small picks are disjoint', () {
      // 14 categories, picks of 4: after first pick, 10 remain; the
      // second draw can avoid all four entirely.
      final first = RecipeListLoader.pickCategoriesFor(
        count: 4,
        pool: pool,
        exclude: const [],
      );
      final second = RecipeListLoader.pickCategoriesFor(
        count: 4,
        pool: pool,
        exclude: first,
      );
      expect(
        first.toSet().intersection(second.toSet()),
        isEmpty,
      );
    });
  });
}
