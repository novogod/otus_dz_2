import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/data/recipe_manager.dart';
import 'package:recipe_list/models/recipe.dart';

void main() {
  group('RecipeManager', () {
    const manager = RecipeManager();

    test('getRecipes returns Future<List<Recipe>>', () {
      expect(manager.getRecipes(), isA<Future<List<Recipe>>>());
    });

    test('getRecipes returns non-empty list', () async {
      final recipes = await manager.getRecipes();
      expect(recipes, isNotEmpty);
    });

    test('all recipes have non-empty name and positive id', () async {
      final recipes = await manager.getRecipes();
      for (final r in recipes) {
        expect(r.id, greaterThan(0));
        expect(r.name, isNotEmpty);
        expect(r.duration, greaterThan(0));
      }
    });

    test('all recipe ids are unique', () async {
      final recipes = await manager.getRecipes();
      final ids = recipes.map((r) => r.id).toSet();
      expect(ids.length, recipes.length);
    });
  });
}
