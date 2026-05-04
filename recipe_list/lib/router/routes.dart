/// Константы маршрутов приложения. Единая точка истины
/// для путей `go_router` — снижает риск опечаток и упрощает
/// рефакторинги. Подробнее см. `docs/go-router-shell-refactor.md`
/// и `todo/19-go-router-shell.md`.
abstract final class Routes {
  /// Корневой путь — редиректит на [recipes].
  static const String root = '/';

  /// Главная вкладка: лента рецептов + splash.
  static const String recipes = '/recipes';

  /// Подмаршрут (без префикса `/`) деталей рецепта внутри ветки.
  /// Используется как `path` у `GoRoute` в обеих ветках
  /// (recipes / favorites).
  static const String detailsSubpath = 'details/:id';

  /// Детали рецепта по id (вкладка Recipes). Параметр пути `:id`.
  static String recipeDetails(int id) => '/recipes/details/$id';

  /// Вкладка «Избранное».
  static const String favorites = '/favorites';

  /// Детали рецепта по id (вкладка Favorites). Тот же экран,
  /// что и [recipeDetails], но навбар подсвечивает Favorites,
  /// а возврат идёт в стек этой ветки. Так уходит leaky-abstraction
  /// `originTab`.
  static String favoritesDetails(int id) => '/favorites/details/$id';

  /// Вкладка «Профиль» (чанк C).
  static const String profile = '/profile';
}
