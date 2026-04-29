import 'package:dio/dio.dart';

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

  /// mahallem-only: одноразовый bulk-запрос за уже переведённой
  /// страницей рецептов. Заменяет 14-кратный fan-out по категориям
  /// на холодном старте. Если backend != mahallem или сервер вернул
  /// что-то нестандартное — отдаём пустой список (вызывающий код
  /// сам падает на legacy-путь). См. todo/07,08 и
  /// docs/translation-buffer.md §5.2.
  Future<RecipePage> fetchPage({
    AppLang? lang,
    int offset = 0,
    int limit = 200,
  }) async {
    if (_client.backend != RecipeBackend.mahallem) {
      return const RecipePage(recipes: [], nextOffset: null, total: 0);
    }
    final res = await _client.dio.get<Map<String, dynamic>>(
      '/page',
      queryParameters: {
        'offset': offset.toString(),
        'limit': limit.toString(),
        ..._langParams(lang),
      },
    );
    final data = res.data;
    final list = (data?['recipes'] is List)
        ? (data!['recipes'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Recipe.fromMealDb)
              .toList(growable: false)
        : const <Recipe>[];
    final next = data?['nextOffset'];
    return RecipePage(
      recipes: list,
      nextOffset: next is int ? next : null,
      total: data?['total'] is int ? data!['total'] as int : list.length,
    );
  }

  Future<Recipe?> lookup(int id, {AppLang? lang, Duration? timeout}) async {
    final mahallem = _client.backend == RecipeBackend.mahallem;
    final res = await _client.dio.get<Map<String, dynamic>>(
      mahallem ? '/lookup/$id' : '/lookup.php',
      queryParameters: mahallem ? _langParams(lang) : {'i': id.toString()},
      options: timeout == null ? null : Options(receiveTimeout: timeout),
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
    final mahallem = _client.backend == RecipeBackend.mahallem;
    final res = await _client.dio.get<Map<String, dynamic>>(
      _path('/filter.php', '/filter'),
      queryParameters: {
        key: value,
        // mahallem поддерживает full=1 — возвращает уже переведённые
        // полные рецепты (категория/теги/ингредиенты), что нужно для
        // богатой карточки. Без флага — lite-payload, как у TheMealDB.
        if (mahallem) 'full': '1',
        if (mahallem) ..._langParams(null),
      },
    );
    final meals = res.data?['meals'];
    if (meals is! List) return const [];
    // На mahallem с full=1 приходят полные данные; парсим как fromMealDb.
    final parser = mahallem ? Recipe.fromMealDb : Recipe.fromMealDbLite;
    return meals
        .whereType<Map<String, dynamic>>()
        .map(parser)
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

/// Результат `RecipeApi.fetchPage` — страница уже переведённых
/// рецептов плюс курсор для следующей страницы. См. todo/08.
class RecipePage {
  final List<Recipe> recipes;
  final int? nextOffset;
  final int total;
  const RecipePage({
    required this.recipes,
    required this.nextOffset,
    required this.total,
  });
}
