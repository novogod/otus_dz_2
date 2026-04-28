import 'package:dio/dio.dart';

import 'recipe_api_config.dart';

/// Базовый HTTP-клиент рецептов.
///
/// База берётся из [RecipeApiConfig.activeBaseUrl]:
/// * по умолчанию — `https://www.themealdb.com/api/json/v1/1`;
/// * под `--dart-define=MAHALLEM_RECIPES_BASE=...` — собственный
///   сервер mahallem (см. `docs/i18n_proposal.md` §5).
///
/// Сам клиент знает только про базу и таймауты. О формате путей
/// (`/search.php?s=` vs `/recipes/search?q=`) знает [RecipeApi]
/// через текущий [RecipeApiConfig.backend].
class MealDbClient {
  /// Старая константа сохранена для совместимости с тестами,
  /// которые держат на неё ссылку. Не использовать в новом коде —
  /// читать [RecipeApiConfig.activeBaseUrl].
  static const String baseUrl = RecipeApiConfig.mealDbBaseUrl;

  final Dio dio;
  final RecipeBackend backend;

  MealDbClient({Dio? dio, RecipeBackend? backend})
    : backend = backend ?? RecipeApiConfig.backend,
      dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: RecipeApiConfig.activeBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              // mahallem cold-cache lookup translates ~25 fields
              // through LibreTranslate and can take 10–25s. TheMealDB
              // is fast but a generous ceiling does no harm.
              receiveTimeout: const Duration(seconds: 30),
              responseType: ResponseType.json,
            ),
          );
}
