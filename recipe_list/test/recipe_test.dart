import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/models/recipe.dart';

/// Сокращённая фикстура `lookup.php?i=52772` (Teriyaki Chicken Casserole)
/// — содержит все интересные поля.
const _full = <String, dynamic>{
  'idMeal': '52772',
  'strMeal': 'Teriyaki Chicken Casserole',
  'strCategory': 'Chicken',
  'strArea': 'Japanese',
  'strInstructions': 'Preheat oven to 350...',
  'strMealThumb':
      'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg',
  'strTags': 'Meat,Casserole',
  'strYoutube': 'https://www.youtube.com/watch?v=4aZr5hZXP_s',
  'strSource': 'https://example.com/recipe',
  'strIngredient1': 'soy sauce',
  'strIngredient2': 'water',
  'strIngredient3': 'brown sugar',
  'strIngredient4': '',
  'strIngredient5': null,
  'strMeasure1': '3/4 cup',
  'strMeasure2': '1/2 cup',
  'strMeasure3': '1/4 cup ',
  'strMeasure4': '',
  'strMeasure5': null,
};

const _lite = <String, dynamic>{
  'idMeal': '52959',
  'strMeal': 'Baked salmon with fennel & tomatoes',
  'strMealThumb':
      'https://www.themealdb.com/images/media/meals/1548772327.jpg',
};

void main() {
  group('Recipe.fromMealDb', () {
    test('parses full meal payload', () {
      final r = Recipe.fromMealDb(_full);
      expect(r.id, 52772);
      expect(r.name, 'Teriyaki Chicken Casserole');
      expect(r.category, 'Chicken');
      expect(r.area, 'Japanese');
      expect(r.youtubeUrl, 'https://www.youtube.com/watch?v=4aZr5hZXP_s');
      expect(r.sourceUrl, 'https://example.com/recipe');
    });

    test('skips empty/null ingredients', () {
      final r = Recipe.fromMealDb(_full);
      expect(r.ingredients.length, 3);
      expect(r.ingredients.first.name, 'soy sauce');
      expect(r.ingredients.first.measure, '3/4 cup');
      expect(r.ingredients.last.measure, '1/4 cup'); // trimmed
    });

    test('parses tags csv and trims whitespace', () {
      final r = Recipe.fromMealDb(_full);
      expect(r.tags, ['Meat', 'Casserole']);
    });

    test('handles empty strTags as empty list', () {
      final r = Recipe.fromMealDb({..._full, 'strTags': ''});
      expect(r.tags, isEmpty);
    });

    test('marks recipe as not lite when category present', () {
      final r = Recipe.fromMealDb(_full);
      expect(r.isLite, isFalse);
    });
  });

  group('Recipe.fromMealDbLite', () {
    test('fills only id/name/photo', () {
      final r = Recipe.fromMealDbLite(_lite);
      expect(r.id, 52959);
      expect(r.name, 'Baked salmon with fennel & tomatoes');
      expect(r.photo, _lite['strMealThumb']);
      expect(r.category, isNull);
      expect(r.area, isNull);
      expect(r.tags, isEmpty);
      expect(r.ingredients, isEmpty);
      expect(r.instructions, isNull);
      expect(r.isLite, isTrue);
    });
  });
}
