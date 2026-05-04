# 19 — Рефакторинг навигации на `go_router` + `StatefulShellRoute`

> **Статус:** 📋 не начат.
> **См.:** [docs/go-router-shell-refactor.md](../docs/go-router-shell-refactor.md).
> **Приоритет:** P2 (улучшение архитектуры).
> **Scope:** только `[client]`, серверных правок нет.

Цель: убрать дублирование `AppBottomNavBar` (4 копии),
устранить `RecipeDetailsPage.originTab` как leaky abstraction,
сохранить состояние вкладок между переходами и получить
deep-link URLs для Flutter web.

Реализация делится на **5 чанков**. Каждый чанк ложится отдельным
коммитом, тесты проходят перед переходом к следующему.

---

## Чанк A — Каркас: `go_router` + `AppShell` для вкладки Recipes

Цель: ввести `GoRouter` с одной веткой (Recipes), вынести
`AppBottomNavBar` в общий `AppShell`. Остальные вкладки временно
открываются старым способом (через `Navigator.push`), чтобы чанк
оставался маленьким и тестируемым.

### Изменения
* `recipe_list/pubspec.yaml`:
  * Добавить `go_router: ^14.0.0` в `dependencies`.
  * `flutter pub get`.
* `recipe_list/lib/router/routes.dart` (новый):
  * Константы путей: `Routes.recipes = '/recipes'`,
    `Routes.recipeDetails(int id) => '/recipes/details/$id'`.
* `recipe_list/lib/router/app_router.dart` (новый):
  * `GoRouter appRouter` с одним `StatefulShellRoute.indexedStack`,
    у которого пока **одна** ветка `recipes` (остальные ветки
    добавим в чанках B–C).
  * `redirect: '/' → '/recipes'`.
  * `errorBuilder` → существующий `_AppRoot` со splash.
* `recipe_list/lib/ui/app_shell.dart` (новый):
  * `class AppShell extends StatelessWidget` принимает
    `StatefulNavigationShell navShell`.
  * `Scaffold(body: navShell, bottomNavigationBar: AppBottomNavBar(
    current: AppNavTab.values[navShell.currentIndex],
    onTap: (tab) => navShell.goBranch(tab.index),
  ))`.
* `recipe_list/lib/main.dart`:
  * `MaterialApp.router(routerConfig: appRouter, ...)` вместо
    `MaterialApp(home: ...)`.
  * Splash через `_AppRoot` встраивается в первый `pageBuilder`
    ветки `recipes` (показываем splash, потом редирект на
    `/recipes`).
* `recipe_list/lib/ui/recipe_list_page.dart`:
  * Убрать `bottomNavigationBar: AppBottomNavBar(...)`.
  * Убрать метод `_onNavTap` (на этом чанке навигация остальных
    вкладок временно идёт через `Navigator.push`, но NavBar
    нарисован в `AppShell` — onTap уже работает через `navShell`).

### Тесты
* `recipe_list/test/router/router_smoke_test.dart` (новый):
  * При старте → видим splash → через 1.5 с видим `RecipeListPage`.
  * `context.go('/recipes')` → текущий путь `/recipes`.
  * `BottomNavigationBar` отображается ровно один раз в дереве
    виджетов (`find.byType(AppBottomNavBar)` → один результат).

### Приёмка
* `flutter test test/router/` зелёный.
* `flutter analyze` без новых warnings.
* Ручной smoke на web: открывается лента рецептов, нижний навбар
  виден, клик по «Profile» открывает `LoginPage` старым способом
  (через `openProfilePage`).

---

## Чанк B — Ветка Favorites + удаление `originTab`

Цель: добавить вторую ветку (Favorites) в `StatefulShellRoute`,
переместить `RecipeDetailsPage` под path-параметр `:id`, **полностью
удалить поле `originTab`**.

### Изменения
* `recipe_list/lib/router/routes.dart`:
  * `Routes.favorites = '/favorites'`.
  * `Routes.favoritesDetails(int id) => '/favorites/details/$id'`.
* `recipe_list/lib/router/app_router.dart`:
  * Добавить `StatefulShellBranch` для `favorites`.
  * Внутри ветки `recipes`: вложенный `GoRoute('details/:id')` →
    `RecipeDetailsPage`.
  * Внутри ветки `favorites`: `GoRoute('details/:id')` → тот же
    `RecipeDetailsPage`.
  * `RecipeDetailsPage` теперь принимает `recipeId` через
    `state.pathParameters['id']`, recipe резолвит через
    `RecipeServices.of(context).repository.byId(id)`.
* `recipe_list/lib/ui/app_shell.dart`:
  * Внедрить `RecipeServices` (InheritedWidget) с
    `api`/`repository`, чтобы страницы под GoRouter могли их
    получить из контекста (а не через конструктор).
* `recipe_list/lib/ui/recipe_details_page.dart`:
  * **Удалить** поле `final AppNavTab originTab`.
  * **Удалить** параметр `originTab` из конструктора.
  * Убрать `bottomNavigationBar` (теперь рисует `AppShell`).
  * `Navigator.of(context).pop()` → `context.pop()`.
  * Поле `Recipe recipe` заменить на `int recipeId` + резолв
    через `RecipeRepository`. Шиммер на время загрузки
    (`recipe_bodies` уже умеет lazy-load инструкций).
* `recipe_list/lib/ui/recipe_list_page.dart`:
  * Открытие деталей: `context.push(Routes.recipeDetails(recipe.id))`.
* `recipe_list/lib/ui/favorites_page.dart`:
  * Открытие деталей:
    `context.push(Routes.favoritesDetails(recipe.id))`.
  * Убрать `bottomNavigationBar`, `_onNavTap`.

### Тесты
* `recipe_list/test/router/branches_test.dart` (новый):
  * Переход Recipes → детали → Back: возвращается на Recipes,
    позиция скролла сохранена.
  * Переход Favorites → детали → Back: возвращается на Favorites,
    NavBar остаётся подсвеченным на Favorites **на протяжении
    всего перехода** (golden + finder).
  * Переключение между вкладками сохраняет состояние списка
    (поисковый ввод не сбрасывается).
* `recipe_list/test/ui/recipe_details_page_test.dart`:
  * Обновить тесты — убрать `originTab` из всех конструкторов
    `RecipeDetailsPage`.

### Приёмка
* `grep -r "originTab" recipe_list/lib` → 0 результатов.
* `flutter test` зелёный.
* Ручной тест: открыть рецепт из «Избранное», нажать «Назад» →
  возвращаемся на Favorites без перепрыгивания подсветки NavBar.

---

## Чанк C — Ветка Profile (login/signup/recovery)

Цель: перевести профильный поток (логин, регистрация, восстановление
пароля) под `StatefulShellBranch`, сохранить slide-up анимацию.

### Изменения
* `recipe_list/lib/router/routes.dart`:
  * `Routes.profile = '/profile'`.
  * `Routes.profileLogin = '/profile/login'`.
  * `Routes.profileSignup = '/profile/signup'`.
  * `Routes.profileRecover = '/profile/recover'`.
  * `Routes.adminAfterLogin = '/profile/admin'`.
* `recipe_list/lib/router/app_router.dart`:
  * Третья ветка `profile` со вложенными маршрутами.
  * Для login/signup/recovery — `pageBuilder` с
    `CustomTransitionPage` и существующим `SlideTransition`
    (`Tween<Offset>(begin: Offset(0,1), end: Offset.zero)` +
    `Curves.easeInOut`, `AppDurations.splashTransition`).
* `recipe_list/lib/ui/login_page.dart`:
  * `Navigator.of(context).pop(true)` → `context.pop(true)`.
  * `openProfilePage(context)` переписать через
    `context.go(Routes.profile)`.
  * Внутренний переход на `AdminAfterLoginPage` →
    `context.go(Routes.adminAfterLogin)`.
* `recipe_list/lib/ui/signup_page.dart`:
  * Аналогично: открытие через `context.push(Routes.profileSignup)`,
    `pop` → `context.pop`.
* `recipe_list/lib/ui/password_recovery_page.dart`:
  * Открытие через `context.push(Routes.profileRecover, extra: email)`.
  * `Navigator.of(context).pop<String>(...)` → `context.pop<String>(...)`.
* `recipe_list/lib/ui/admin_after_login_page.dart`:
  * Если есть `bottomNavigationBar` — убрать (рисует `AppShell`).

### Тесты
* `recipe_list/test/ui/login_flow_test.dart`:
  * Заменить все `Navigator.of(...)` на `context`-aware версии.
  * Smoke: успешный логин → находимся на `Routes.adminAfterLogin`
    (через `appRouter.routerDelegate.currentConfiguration`).
* `recipe_list/test/router/profile_branch_test.dart` (новый):
  * Slide-up анимация присутствует (нет внезапных скачков
    позиции, проверка через `find.byType(SlideTransition)`).

### Приёмка
* Ручной тест: клик на вкладку Profile → если не залогинен,
  открывается LoginPage с slide-up анимацией. Логин → перекидывает
  на AdminAfterLoginPage. Кнопка «назад» возвращает на
  предыдущую вкладку.
* Восстановление пароля: открыть форму, ввести email, ввести код,
  ввести новый пароль → snackbar «Пароль обновлён», возврат на
  LoginPage с пред-заполненным email.

---

## Чанк D — Вспомогательные экраны (`SourcePage`, `AddRecipePage`)

Цель: перевести оставшиеся подэкраны под GoRouter без отдельных
веток (они открываются `push`-ом внутри текущей ветки).

### Изменения
* `recipe_list/lib/router/routes.dart`:
  * `Routes.recipeSource(String url) => '/recipes/source?url=${Uri.encodeQueryComponent(url)}'`.
  * `Routes.recipeAdd = '/recipes/add'`,
    `Routes.recipeEdit(int id) => '/recipes/edit/$id'`.
  * Аналогичные пути под веткой `favorites`, если эти экраны
    открываются и оттуда.
* `recipe_list/lib/router/app_router.dart`:
  * Вложенные `GoRoute` под обеими ветками (recipes/favorites)
    для `details/source`, `add`, `edit/:id`.
* `recipe_list/lib/ui/source_page.dart`:
  * Убрать `bottomNavigationBar` (рисует `AppShell`).
  * Возврат через `context.pop()`.
* `recipe_list/lib/ui/add_recipe_page.dart`:
  * Открытие через `context.push(Routes.recipeAdd)` или
    `Routes.recipeEdit(id)`.
  * Возврат с результатом → `context.pop(updatedRecipe)`.
* `recipe_list/lib/ui/recipe_details_page.dart`:
  * `_openSource` → `context.push(Routes.recipeSource(url))`.
  * `_openEdit` → `context.push(Routes.recipeEdit(recipe.id))`.

### Тесты
* `recipe_list/test/router/source_page_test.dart` (новый):
  * `context.push(Routes.recipeSource('https://example.com'))`
    → видим `SourcePage` с правильным URL.
* `recipe_list/test/ui/add_recipe_flow_test.dart`:
  * Owner-actions → `_openEdit` → видим `AddRecipePage` в edit-режиме
    с заполненными полями.

### Приёмка
* Owner edit/delete рецепта работает (см.
  [docs/owner-edit-delete.md](../docs/owner-edit-delete.md))
  без регрессий.
* `flutter test` зелёный.

---

## Чанк E — Cleanup и документация

Цель: убрать остатки старого кода, обновить документацию.

### Изменения
* Удалить из всех страниц устаревшие `_onNavTap` методы.
* Удалить вспомогательные функции, которые превратились в
  `context.go(...)` one-liner-ы.
* Удалить из `RecipeListPage`/`FavoritesPage`/`SourcePage`/
  `RecipeDetailsPage` поле `bottomNavigationBar` (если ещё
  где-то осталось).
* `docs/project_log.md`: добавить запись о рефакторинге со ссылкой
  на коммиты A–E.
* `docs/go-router-shell-refactor.md`: пометить статус «✅ выполнено
  YYYY-MM-DD».
* `todo/19-go-router-shell.md` (этот файл): пометить статус
  «✅ выполнено».
* `recipe_list/README.md` (если есть) или новый docs-файл:
  таблица «Маршрут → экран» как карта.

### Тесты
* `flutter test` — все существующие тесты зелёные.
* `flutter analyze` — без warnings и errors.
* `grep -rn "AppBottomNavBar(" recipe_list/lib | wc -l` → 1.
* `grep -rn "originTab" recipe_list/lib | wc -l` → 0.
* `grep -rn "MaterialPageRoute" recipe_list/lib | wc -l` → 0
  (или только в обоснованных местах с явным комментарием).

### Приёмка (финальная для всего todo)
- [ ] При навигации Favorites → Detail → Back позиция скролла
      и поисковый запрос сохранены.
- [ ] На вебе `https://mahallem.ist/#/recipes/details/52772`
      открывает страницу деталей конкретного рецепта без
      прохождения splash.
- [ ] Анимация slide-up для login/signup/recovery сохранилась
      (визуальная регрессия отсутствует).
- [ ] `originTab` физически удалён из кодовой базы.
- [ ] `AppBottomNavBar` инстанцируется ровно в одном месте
      (внутри `AppShell`).
- [ ] `flutter test && flutter analyze` зелёные.

---

## Карта файлов (для удобства просмотра при ревью)

### Новые
| Файл | Назначение | Чанк |
|------|-----------|------|
| `recipe_list/lib/router/routes.dart` | Константы путей | A |
| `recipe_list/lib/router/app_router.dart` | Конфигурация GoRouter | A → C → D |
| `recipe_list/lib/ui/app_shell.dart` | Один Scaffold + NavBar | A |
| `recipe_list/test/router/router_smoke_test.dart` | Базовый smoke | A |
| `recipe_list/test/router/branches_test.dart` | Состояние веток | B |
| `recipe_list/test/router/profile_branch_test.dart` | Профильная ветка | C |
| `recipe_list/test/router/source_page_test.dart` | Подэкраны | D |

### Изменённые
| Файл | Что меняем | Чанк |
|------|-----------|------|
| `recipe_list/pubspec.yaml` | + go_router | A |
| `recipe_list/lib/main.dart` | MaterialApp.router | A |
| `recipe_list/lib/ui/recipe_list_page.dart` | -nav, -onNavTap | A → B |
| `recipe_list/lib/ui/favorites_page.dart` | -nav, -onNavTap | B |
| `recipe_list/lib/ui/recipe_details_page.dart` | **−originTab**, recipeId path-param | B |
| `recipe_list/lib/ui/source_page.dart` | -nav | D |
| `recipe_list/lib/ui/login_page.dart` | context.go/pop | C |
| `recipe_list/lib/ui/signup_page.dart` | context.go/pop | C |
| `recipe_list/lib/ui/password_recovery_page.dart` | context.go/pop | C |
| `recipe_list/lib/ui/add_recipe_page.dart` | context.push/pop | D |
| `docs/project_log.md` | Запись о рефакторинге | E |

---

## Связанные документы

* [docs/go-router-shell-refactor.md](../docs/go-router-shell-refactor.md) — обоснование и архитектура.
* [docs/design_system.md](../docs/design_system.md) §6 — спецификация `AppBottomNavBar` (не меняется).
* [pub.dev/go_router](https://pub.dev/packages/go_router) — официальная документация пакета.
