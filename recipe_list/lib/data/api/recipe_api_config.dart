import 'package:flutter/foundation.dart';

/// Конфигурация бэкенда `RecipeApi`.
///
/// По умолчанию приложение работает с собственным сервером mahallem
/// (`https://mahallem.ist/recipes`), который отдаёт переведённый
/// контент по `?lang=`. Это поведение единое для всех платформ
/// (iOS / Android / desktop) — никакого `--dart-define` для запуска
/// не требуется.
///
/// На web-платформе по умолчанию использует локальный backend
/// (`http://localhost:4000/recipes`) для разработки.
///
/// Переопределить адрес можно через
/// `--dart-define=MAHALLEM_RECIPES_BASE=https://example.com/recipes`.
/// Чтобы вернуться к прямому TheMealDB (только английский, без
/// переводов), запустите с `--dart-define=MAHALLEM_RECIPES_BASE=` —
/// пустая строка форсит fallback на TheMealDB.
class RecipeApiConfig {
  /// База TheMealDB — fallback, если mahallem явно отключён.
  static const String mealDbBaseUrl = 'https://www.themealdb.com/api/json/v1/1';

  /// Локальный backend для web разработки.
  static const String localWebBaseUrl = 'http://localhost:4000/recipes';

  /// Прод-эндпоинт mahallem по умолчанию.
  static const String mahallemDefaultBaseUrl = 'https://mahallem.ist/recipes';

  /// Значение из `--dart-define`. Sentinel `__unset__` означает «define
  /// не передан»; пустая строка — явное отключение mahallem.
  static const String _mahallemBaseFromEnv = String.fromEnvironment(
    'MAHALLEM_RECIPES_BASE',
    defaultValue: '__unset__',
  );

  /// Итоговая база mahallem с учётом dart-define и платформы.
  /// На web использует локальный backend, на других платформах — prod.
  static String get mahallemBaseUrl {
    if (_mahallemBaseFromEnv != '__unset__') {
      return _mahallemBaseFromEnv; // явно переданный через dart-define
    }
    // На web использует локальный backend для разработки
    if (kIsWeb) {
      return localWebBaseUrl;
    }
    return mahallemDefaultBaseUrl;
  }

  /// Активный режим: mahallem по умолчанию; mealDb только если
  /// явно передан пустой `MAHALLEM_RECIPES_BASE=`.
  static RecipeBackend get backend => mahallemBaseUrl.isNotEmpty
      ? RecipeBackend.mahallem
      : RecipeBackend.mealDb;

  /// База, которую нужно подставить в Dio.
  static String get activeBaseUrl =>
      backend == RecipeBackend.mahallem ? mahallemBaseUrl : mealDbBaseUrl;

  const RecipeApiConfig._();
}

enum RecipeBackend {
  /// Прямой `https://www.themealdb.com/api/json/v1/1`. Только английский.
  mealDb,

  /// `https://mahallem.ist/recipes`, прокидываем `lang=ru|en|...`.
  mahallem,
}
