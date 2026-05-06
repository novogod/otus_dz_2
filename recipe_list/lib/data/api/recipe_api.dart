import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../auth/admin_session.dart';
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

  /// mahallem-only: создать новый рецепт. Сервер выделит id из
  /// диапазона ≥ 1_000_000 (см. `routes/recipes.js: createUserMeal`),
  /// положит payload в `i18n.en` и вернёт сохранённый объект с
  /// присвоенным id. Перевод на остальные локали подтянется лениво
  /// через стандартный cascade на следующем `/recipes/lookup/:id?lang=…`.
  ///
  /// Бросает [StateError], если backend != mahallem (TheMealDB не
  /// предоставляет публичного POST, см.
  /// `docs/themealdb-add-recipe-investigation.md`).
  Future<Recipe> createRecipe(Recipe draft) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('createRecipe requires the mahallem backend');
    }
    final res = await _client.dio.post<Map<String, dynamic>>(
      '',
      data: {'meal': _mealToJson(draft)},
      options: _authOptions(),
    );
    final data = res.data;
    final stored = data?['meal'];
    if (stored is! Map<String, dynamic>) {
      throw StateError('createRecipe: malformed response');
    }
    return Recipe.fromMealDb(stored);
  }

  /// mahallem-only: создать рецепт + загрузить фото единым multipart
  /// запросом. Используется когда пользователь выбрал файл через
  /// `image_picker` (см. `add_recipe_page.dart`). Сервер вставляет
  /// рецепт с placeholder-thumb, заливает фото в bucket
  /// `recipe-photos`, патчит `i18n.en.strMealThumb` и возвращает
  /// рецепт с публичным URL картинки.
  ///
  /// Бросает [StateError] если backend != mahallem.
  Future<Recipe> createRecipeWithPhoto(
    Recipe draft,
    Uint8List photoBytes,
    String photoFilename,
  ) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('createRecipeWithPhoto requires the mahallem backend');
    }
    final form = FormData.fromMap({
      'meal': jsonEncode(_mealToJson(draft)),
      'photo': MultipartFile.fromBytes(photoBytes, filename: photoFilename),
    });
    final res = await _client.dio.post<Map<String, dynamic>>(
      '',
      data: form,
      options: _authOptions(contentType: 'multipart/form-data'),
    );
    final data = res.data;
    final stored = data?['meal'];
    if (stored is! Map<String, dynamic>) {
      throw StateError('createRecipeWithPhoto: malformed response');
    }
    return Recipe.fromMealDb(stored);
  }

  /// Returns Dio [Options] carrying the active auth token for
  /// write operations (create / update / delete). Prefers the
  /// admin recipe-admin bearer token; falls back to the regular
  /// user token header used by the mahallem favorites API.
  Options _authOptions({String? contentType}) {
    final adminToken = currentRecipeAdminTokenNotifier.value;
    final userToken = currentUserTokenNotifier.value;
    final headers = <String, dynamic>{};
    if (adminToken != null && adminToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $adminToken';
    } else if (userToken != null && userToken.isNotEmpty) {
      headers['x-recipes-user-token'] = userToken;
    }
    return Options(headers: headers, contentType: contentType);
  }

  /// Сериализация черновика в TheMealDB-shape JSON, общая для
  /// JSON- и multipart-вариантов `POST /recipes`.
  Map<String, dynamic> _mealToJson(Recipe draft) => <String, dynamic>{
    'strMeal': draft.name,
    'strMealThumb': draft.photo,
    if (draft.category != null) 'strCategory': draft.category,
    if (draft.area != null) 'strArea': draft.area,
    if (draft.tags.isNotEmpty) 'strTags': draft.tags.join(','),
    if (draft.instructions != null) 'strInstructions': draft.instructions,
    if (draft.youtubeUrl != null) 'strYoutube': draft.youtubeUrl,
    if (draft.sourceUrl != null) 'strSource': draft.sourceUrl,
    for (var i = 0; i < draft.ingredients.length && i < 20; i++) ...{
      'strIngredient${i + 1}': draft.ingredients[i].name,
      'strMeasure${i + 1}': draft.ingredients[i].measure,
    },
  };

  /// mahallem-only: PUT /recipes/:id. Заменяет `i18n.en` — сервер
  /// чистит остальные локали, чтобы cascade перевёл заново при
  /// следующем `/lookup`. Owner-flow, см. docs/owner-edit-delete.md.
  Future<Recipe> updateRecipe(Recipe draft) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('updateRecipe requires the mahallem backend');
    }
    final res = await _client.dio.put<Map<String, dynamic>>(
      '/${draft.id}',
      data: {'meal': _mealToJson(draft)},
      options: _authOptions(),
    );
    final stored = res.data?['meal'];
    if (stored is! Map<String, dynamic>) {
      throw StateError('updateRecipe: malformed response');
    }
    return Recipe.fromMealDb(stored);
  }

  /// mahallem-only: PUT /recipes/:id с новой фотографией.
  /// Если `photo == null` — серверная картинка остаётся прежней
  /// (отправляется обычный JSON-PUT).
  Future<Recipe> updateRecipeWithPhoto(
    Recipe draft,
    Uint8List? photoBytes,
    String? photoFilename,
  ) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('updateRecipeWithPhoto requires the mahallem backend');
    }
    if (photoBytes == null) return updateRecipe(draft);
    final form = FormData.fromMap({
      'meal': jsonEncode(_mealToJson(draft)),
      'photo': MultipartFile.fromBytes(
        photoBytes,
        filename: photoFilename ?? 'photo.jpg',
      ),
    });
    final res = await _client.dio.put<Map<String, dynamic>>(
      '/${draft.id}',
      data: form,
      options: _authOptions(contentType: 'multipart/form-data'),
    );
    final stored = res.data?['meal'];
    if (stored is! Map<String, dynamic>) {
      throw StateError('updateRecipeWithPhoto: malformed response');
    }
    return Recipe.fromMealDb(stored);
  }

  /// mahallem-only: DELETE /recipes/:id. Сервер допускает удаление
  /// только пользовательских записей (id ≥ USER_MEAL_ID_FLOOR).
  Future<void> deleteRecipe(int id) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('deleteRecipe requires the mahallem backend');
    }
    await _client.dio.delete<void>('/$id', options: _authOptions());
  }

  /// mahallem-only: GET /recipes/:id/rating. Anonymous-friendly —
  /// returns aggregate `{count, sum, avg}` plus `my` (1..5) when
  /// the caller has a valid user token. Returns null on transport
  /// failure so the rating row can fall back to its initial state
  /// without crashing the details page.
  ///
  /// See chunk G of docs/user-card-and-social-signals.md.
  Future<RecipeRatingSnapshot?> fetchRating(int recipeId) async {
    if (_client.backend != RecipeBackend.mahallem) return null;
    try {
      final res = await _client.dio.get<Map<String, dynamic>>(
        '/$recipeId/rating',
        options: _authOptions(),
      );
      final data = res.data;
      if (data == null) return null;
      return RecipeRatingSnapshot(
        count: (data['count'] as num?)?.toInt() ?? 0,
        sum: (data['sum'] as num?)?.toInt() ?? 0,
        my: (data['my'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// mahallem-only: POST /recipes/:id/rating with `{stars}`. Caller
  /// must be authenticated; throws on missing token or invalid
  /// stars (server returns 422). Returns the fresh aggregate.
  Future<RecipeRatingSnapshot> setRating(int recipeId, int stars) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('setRating requires the mahallem backend');
    }
    final res = await _client.dio.post<Map<String, dynamic>>(
      '/$recipeId/rating',
      data: {'stars': stars},
      options: _authOptions(),
    );
    final data = res.data ?? const {};
    return RecipeRatingSnapshot(
      count: (data['count'] as num?)?.toInt() ?? 0,
      sum: (data['sum'] as num?)?.toInt() ?? 0,
      my: (data['my'] as num?)?.toInt() ?? stars,
    );
  }

  /// mahallem-only: DELETE /recipes/:id/rating. Removes the
  /// caller's vote. Returns the fresh aggregate (without `my`).
  Future<RecipeRatingSnapshot> clearRating(int recipeId) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('clearRating requires the mahallem backend');
    }
    final res = await _client.dio.delete<Map<String, dynamic>>(
      '/$recipeId/rating',
      options: _authOptions(),
    );
    final data = res.data ?? const {};
    return RecipeRatingSnapshot(
      count: (data['count'] as num?)?.toInt() ?? 0,
      sum: (data['sum'] as num?)?.toInt() ?? 0,
      my: null,
    );
  }

  /// mahallem-only: GET /recipes/users/me. Returns the current
  /// user's profile (display name, language, member-since,
  /// recipes_added counter). Auth-required; 401 → returns null
  /// rather than throwing so the User Card screen can fall back
  /// to local cache.
  Future<UserProfileSnapshot?> fetchMyProfile() async {
    if (_client.backend != RecipeBackend.mahallem) return null;
    try {
      final res = await _client.dio.get<Map<String, dynamic>>(
        '/users/me',
        options: _authOptions(),
      );
      final data = res.data;
      if (data == null) return null;
      return UserProfileSnapshot.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// mahallem-only: PUT /recipes/users/me. Updates display name
  /// and/or preferred language. Either field may be omitted;
  /// the server keeps untouched fields as-is. Returns the fresh
  /// projection on success; throws on validation / network
  /// errors so the caller surfaces them as snackbars.
  Future<UserProfileSnapshot> updateMyProfile({
    String? displayName,
    String? language,
  }) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('updateMyProfile requires the mahallem backend');
    }
    final body = <String, Object?>{};
    if (displayName != null) body['displayName'] = displayName;
    if (language != null) body['language'] = language;
    final res = await _client.dio.put<Map<String, dynamic>>(
      '/users/me',
      data: body,
      options: _authOptions(),
    );
    final data = res.data ?? const <String, dynamic>{};
    return UserProfileSnapshot.fromJson(data);
  }

  /// mahallem-only: атомарно увеличивает счётчик визитов и
  /// возвращает новое значение. Используется на splash-экране
  /// (`SplashPage`), который мигает белым числом под лого. Если
  /// backend != mahallem или сервер недоступен — возвращает null,
  /// чтобы splash остался без числа без падения UI.
  Future<int?> incrementVisitorCount() async {
    if (_client.backend != RecipeBackend.mahallem) return null;
    try {
      final res = await _client.dio.post<Map<String, dynamic>>('/visit');
      final count = res.data?['count'];
      if (count is int) return count;
      if (count is num) return count.toInt();
      return null;
    } catch (_) {
      return null;
    }
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

/// Snapshot of `/recipes/:id/rating`. Carries the aggregate
/// (`count`, `sum`) plus the caller's own vote (`my`) when the
/// request was authenticated. `avg` is computed for convenience —
/// the server doesn't return it as a separate field beyond
/// rounding, so callers are free to compute it themselves.
///
/// See chunk G of docs/user-card-and-social-signals.md.
class RecipeRatingSnapshot {
  const RecipeRatingSnapshot({
    required this.count,
    required this.sum,
    required this.my,
  });

  final int count;
  final int sum;
  final int? my;

  /// Average rating in 0..5, or 0 when no votes are recorded.
  double get avg => count > 0 ? sum / count : 0.0;
}

/// Snapshot of `/recipes/users/me` (chunk C). Carries the fields
/// the User Card page needs to render — display name, language,
/// avatar path/URL (always null until the `food-avatars` bucket
/// ships), member-since, and the user's live recipes-added count.
class UserProfileSnapshot {
  const UserProfileSnapshot({
    required this.id,
    required this.email,
    required this.displayName,
    required this.language,
    required this.avatarPath,
    required this.avatarUrl,
    required this.recipesAdded,
    required this.memberSince,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? language;
  final String? avatarPath;
  final String? avatarUrl;
  final int recipesAdded;
  final DateTime? memberSince;

  factory UserProfileSnapshot.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? raw) {
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
      return null;
    }

    return UserProfileSnapshot(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      displayName: (json['displayName'] as String?)?.trim().isEmpty == true
          ? null
          : json['displayName'] as String?,
      language: (json['language'] as String?)?.trim().isEmpty == true
          ? null
          : json['language'] as String?,
      avatarPath: json['avatarPath'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      recipesAdded: (json['recipesAdded'] as num?)?.toInt() ?? 0,
      memberSince: parseDate(json['memberSince']),
    );
  }
}
