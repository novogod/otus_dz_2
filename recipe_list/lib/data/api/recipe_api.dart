import '../../i18n.dart';
import '../../models/recipe.dart';
import 'meal_db_client.dart';
import 'recipe_api_config.dart';

/// Высокоуровневый API над двумя бэкендами:
///
/// * **TheMealDB** (`backend == RecipeBackend.mealDb`) — прямой
///   доступ, только английский. Параметр [AppLang] игнорируется.
/// * **mahallem** (`backend == RecipeBackend.mahallem`) — собственный
///   сервер, поддерживает `?lang=ru|en|...` и возвращает рецепт уже
///   в нужном языке (см. `docs/i18n_proposal.md` §5.2).
///
/// JSON-форма ответа в обоих случаях — TheMealDB-shape (массив
/// `meals`); mahallem-сервер сам разворачивает `i18n.<lang>` перед
/// отправкой клиенту, поэтому парсер один и тот же.
///
/// Полные методы (`/search.php`, `/lookup.php`, `/random.php` или
/// их mahallem-аналоги) возвращают рецепты через [Recipe.fromMealDb].
/// Lite-методы (`/filter.php?...`) — через [Recipe.fromMealDbLite].
class RecipeApi {
  final MealDbClient _client;

  RecipeApi({MealDbClient? client}) : _client = client ?? MealDbClient();

  RecipeBackend get backend => _client.backend;

  Future<List<Recipe>> searchByName({
    required String query,
    AppLang? lang,
  }) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      _path('/search.php', '/search'),
      queryParameters: _searchParams(query, lang),
    );
    return _parseFull(res.data);
  }

  Future<List<Recipe>> filterByCategory(String category) =>
      _filter('c', category);

  Future<List<Recipe>> filterByArea(String area) => _filter('a', area);

  Future<List<Recipe>> filterByIngredient(String ingredient) =>
      _filter('i', ingredient);

  Future<Recipe?> lookup(int id, {AppLang? lang}) async {
    final mahallem = _client.backend == RecipeBackend.mahallem;
    final res = await _client.dio.get<Map<String, dynamic>>(
      mahallem ? '/$id' : '/lookup.php',
      queryParameters: mahallem ? _langParams(lang) : {'i': id.toString()},
    );
    final list = _parseFull(res.data);
    return list.isEmpty ? null : list.first;
  }

  Future<Recipe?> random({AppLang? lang}) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      _path('/random.php', '/random'),
      queryParameters: _langParams(lang),
    );
    final list = _parseFull(res.data);
    return list.isEmpty ? null : list.first;
  }

  Future<List<Recipe>> _filter(String key, String value) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      _path('/filter.php', '/filter'),
      queryParameters: {key: value},
    );
    final meals = res.data?['meals'];
    if (meals is! List) return const [];
    return meals
        .whereType<Map<String, dynamic>>()
        .map(Recipe.fromMealDbLite)
        .toList(growable: false);
  }

  String _path(String mealDb, String mahallem) =>
      _client.backend == RecipeBackend.mahallem ? mahallem : mealDb;

  Map<String, String> _searchParams(String query, AppLang? lang) {
    if (_client.backend == RecipeBackend.mahallem) {
      return {'q': query, ..._langParams(lang)};
    }
    return {'s': query};
  }

  Map<String, String> _langParams(AppLang? lang) {
    if (_client.backend != RecipeBackend.mahallem) return const {};
    final code = (lang ?? appLang.value).name; // 'ru' | 'en' | …
    return {'lang': code};
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
