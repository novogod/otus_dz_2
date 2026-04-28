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
              // mahallem cold-cache /filter?full=1 fans out ~30 lookups
              // in parallel; each LibreTranslate round-trip is ~5–10s,
              // so the slowest can take ~20s. Keep a generous ceiling.
              receiveTimeout: const Duration(seconds: 60),
              responseType: ResponseType.json,
            ),
          );
}
