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

  /// Экран входа в профильной ветке. Открывается с slide-up
  /// анимацией через `CustomTransitionPage`.
  static const String profileLogin = '/profile/login';

  /// Экран админки/«моего профиля» после успешного логина.
  /// Тоже slide-up — переход login → admin воспринимается как
  /// продолжение того же модального флоу.
  static const String profileAdmin = '/profile/admin';

  // ─── Чанк D: вспомогательные подэкраны под Recipes/Favorites ───
  //
  // Add/Edit/Source открываются как nested-routes в обеих ветках
  // (recipes и favorites), чтобы пуш не выкидывал пользователя
  // на чужую вкладку. Какую именно ветку использовать, callsite
  // решает по [currentBranchBase] (см. ниже).

  /// Подмаршрут «Source» (внутристраничный WebView). Параметр
  /// `url` приходит query-строкой, чтобы был валидным URL для
  /// deep-link / share.
  static const String sourceSubpath = 'source';

  /// Подмаршрут «Add recipe». Без path-параметров; полный
  /// `Recipe` для edit-режима не передаём — для этого есть
  /// отдельный [editSubpath].
  static const String addSubpath = 'add';

  /// Подмаршрут «Edit recipe» с обязательным id рецепта.
  /// Полный [Recipe] прилетает через `extra`, по аналогии с
  /// [detailsSubpath]: builder читает `state.extra as Recipe`.
  static const String editSubpath = 'edit/:id';

  /// Полный путь Source для веток recipes/favorites.
  static String sourceUnder(String branchBase, String url) =>
      '$branchBase/source?url=${Uri.encodeQueryComponent(url)}';

  /// Полный путь Add recipe.
  static String addUnder(String branchBase) => '$branchBase/add';

  /// Полный путь Edit recipe.
  static String editUnder(String branchBase, int id) => '$branchBase/edit/$id';

  /// Базовый путь текущей ветки (`/recipes` или `/favorites`)
  /// по location'у [BuildContext]'а. Любой другой префикс
  /// (например, `/profile`) трактуется как «recipes» — там
  /// этих подэкранов всё равно нет.
  static String currentBranchBase(String currentLocation) {
    if (currentLocation.startsWith(favorites)) return favorites;
    return recipes;
  }
}
