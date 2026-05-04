/// Константы маршрутов приложения. Единая точка истины
/// для путей `go_router` — снижает риск опечаток и упрощает
/// рефакторинги. Подробнее см. `docs/go-router-shell-refactor.md`
/// и `todo/19-go-router-shell.md`.
abstract final class Routes {
  /// Корневой путь — редиректит на [recipes].
  static const String root = '/';

  /// Главная вкладка: лента рецептов + splash.
  static const String recipes = '/recipes';

  /// Детали рецепта по id (вкладка Recipes). Параметр пути `:id`.
  static String recipeDetails(int id) => '/recipes/details/$id';

  // Ниже — заглушки на чанки B/C/D. Пока используются как
  // placeholder-ссылки в комментариях; конкретные ветки
  // подключаются позже.

  /// Вкладка «Избранное» (чанк B).
  static const String favorites = '/favorites';

  /// Вкладка «Профиль» (чанк C).
  static const String profile = '/profile';
}
