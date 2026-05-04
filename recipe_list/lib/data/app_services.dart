import 'package:flutter/foundation.dart';

import '../data/api/recipe_api.dart';
import '../data/repository/recipe_repository.dart';

/// Лёгкий контейнер с зависимостями уровня приложения,
/// который раньше раздавался конструкторами через
/// `RecipeListPage`/`FavoritesPage`/`RecipeDetailsPage`.
///
/// После рефакторинга на `go_router` (см.
/// `docs/go-router-shell-refactor.md`, чанк B) шелл-роуты
/// строятся вне обычного Navigator-стека, поэтому пробрасывать
/// `api`/`repository` через конструкторы стало неудобно.
/// [appServicesNotifier] заполняется единственный раз —
/// `RecipeListLoader` публикует туда [AppServices], как только
/// `RecipeRepository` поднялся, и далее любые экраны (включая
/// табовые ветки шелла) могут забрать ссылку напрямую.
///
/// Тесты, в которых нет реального бэкенда, оставляют
/// `appServicesNotifier.value == null` — экраны умеют работать
/// в этом режиме (FAB добавления просто не рендерится).
class AppServices {
  final RecipeApi api;
  final RecipeRepository? repository;

  const AppServices({required this.api, required this.repository});
}

/// Глобальный publisher [AppServices]. Меняется не больше одного
/// раза за процесс (при первой успешной загрузке `RecipeListLoader`)
/// и далее живёт до завершения приложения.
final ValueNotifier<AppServices?> appServicesNotifier =
    ValueNotifier<AppServices?>(null);
