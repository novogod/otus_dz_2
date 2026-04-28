/// Конфигурация бэкенда `RecipeApi`.
///
/// Поведение зависит от dart-define:
///
/// * `--dart-define=MAHALLEM_RECIPES_BASE=https://mahallem.ist/recipes`
///   — используется собственный сервер mahallem (двуязычные рецепты,
///   языковая выдача через `?lang=`, см. `docs/i18n_proposal.md` §5).
/// * без define — TheMealDB напрямую (`https://www.themealdb.com/api/json/v1/1`),
///   `lang` игнорируется (только английский).
///
/// Это единственная точка переключения между провайдерами; всё
/// остальное (`RecipeApi`, `RecipeRepository`, UI) работает одинаково.
class RecipeApiConfig {
  /// База TheMealDB, используется по умолчанию.
  static const String mealDbBaseUrl =
      'https://www.themealdb.com/api/json/v1/1';

  /// Прод-эндпоинт mahallem; задаётся через `--dart-define`.
  static const String mahallemBaseFromEnv = String.fromEnvironment(
    'MAHALLEM_RECIPES_BASE',
  );

  /// Активный режим: mahallem, если задан env, иначе themealdb.
  static RecipeBackend get backend =>
      mahallemBaseFromEnv.isNotEmpty ? RecipeBackend.mahallem : RecipeBackend.mealDb;

  /// База, которую нужно подставить в Dio.
  static String get activeBaseUrl =>
      backend == RecipeBackend.mahallem ? mahallemBaseFromEnv : mealDbBaseUrl;

  const RecipeApiConfig._();
}

enum RecipeBackend {
  /// Прямой `https://www.themealdb.com/api/json/v1/1`. Только английский.
  mealDb,

  /// `https://mahallem.ist/recipes`, прокидываем `lang=ru|en|...`.
  mahallem,
}
