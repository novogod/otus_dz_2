import '../../models/recipe.dart';
import 'meal_db_client.dart';

/// Высокоуровневый API над TheMealDB.
///
/// Полные методы (`/search.php`, `/lookup.php`, `/random.php`) возвращают
/// рецепты, заполненные через [Recipe.fromMealDb]. Lite-методы
/// (`/filter.php?...`) — через [Recipe.fromMealDbLite].
class RecipeApi {
  final MealDbClient _client;

  RecipeApi({MealDbClient? client}) : _client = client ?? MealDbClient();

  Future<List<Recipe>> searchByName({required String query}) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      '/search.php',
      queryParameters: {'s': query},
    );
    return _parseFull(res.data);
  }

  Future<List<Recipe>> filterByCategory(String category) =>
      _filter('c', category);

  Future<List<Recipe>> filterByArea(String area) => _filter('a', area);

  Future<List<Recipe>> filterByIngredient(String ingredient) =>
      _filter('i', ingredient);

  Future<Recipe?> lookup(int id) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      '/lookup.php',
      queryParameters: {'i': id.toString()},
    );
    final list = _parseFull(res.data);
    return list.isEmpty ? null : list.first;
  }

  Future<Recipe?> random() async {
    final res = await _client.dio.get<Map<String, dynamic>>('/random.php');
    final list = _parseFull(res.data);
    return list.isEmpty ? null : list.first;
  }

  Future<List<Recipe>> _filter(String key, String value) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      '/filter.php',
      queryParameters: {key: value},
    );
    final meals = res.data?['meals'];
    if (meals is! List) return const [];
    return meals
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromMealDbLite)
        .toList(growable: false);
  }

  static List<Recipe> _parseFull(Map<String, dynamic>? data) {
    final meals = data?['meals'];
    if (meals is! List) return const [];
    return meals
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromMealDb)
        .toList(growable: false);
  }
}
