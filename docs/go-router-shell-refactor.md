# Рефакторинг навигации: переход на `go_router` + `StatefulShellRoute`

> **Статус:** ✅ выполнено 2026-05-04 (чанки A–E).
> **Связанный todo:** [todo/19-go-router-shell.md](../todo/19-go-router-shell.md).
> **Приоритет:** P2 (улучшение архитектуры, не блокирует фичи).
>
> **Коммиты:**
> * Чанк A — `fe1235d` (shell + Recipes ветка)
> * Чанк B — `514b720` (Favorites ветка, удалён `originTab`)
> * Чанк C — `15a66d9` (Profile ветка с `/profile/login` и `/profile/admin`)
> * Чанк D — `6b7f888` (Source/Add/Edit как nested-routes)
> * Чанк E — cleanup и эта запись (см. ниже)

## Зачем

### Текущее состояние

* `AppBottomNavBar` инстанцируется **независимо** в 4 файлах:
  * [recipe_list_page.dart](../recipe_list/lib/ui/recipe_list_page.dart) (строка 411)
  * [favorites_page.dart](../recipe_list/lib/ui/favorites_page.dart) (строка 180)
  * [recipe_details_page.dart](../recipe_list/lib/ui/recipe_details_page.dart) (строка 184)
  * [source_page.dart](../recipe_list/lib/ui/source_page.dart) (строка 146)
* Метод `_onNavTap` дублируется в `RecipeListPage` и `FavoritesPage`
  с почти идентичной логикой, но разными отличиями (что считать
  «своей» вкладкой → `return`, что — `maybePop`, что — `push`).
* Навигация между «вкладками» — это `Navigator.push` /
  `Navigator.maybePop` поверх корневого Navigator-а. Это **псевдо-табы**:
  * Каждый переход вкладки добавляет/удаляет страницу из стека.
  * Состояние (скролл, поисковый ввод, выбранные фильтры) теряется
    при возврате.
* Поле `RecipeDetailsPage.originTab` существует только потому, что
  `RecipeDetailsPage` лежит в стеке поверх `FavoritesPage` или
  `RecipeListPage`, и должен «притвориться», будто активна та же
  вкладка, с которой пришли. Это leaky abstraction: страница деталей
  знает про навигацию приложения.
* Используется `MaterialApp(home: ...)` (см.
  [main.dart:63](../recipe_list/lib/main.dart)) — без роутера,
  без deep linking, без shareable URLs (а проект уже работает на
  Flutter web под `https://mahallem.ist`).

### Проблемы

1. **Дублирование кода.** NavBar и `_onNavTap` повторяются ≥ 4 раз.
   Каждое изменение (новая вкладка, новый guard) — править все копии.
2. **`originTab` как leaky abstraction.** Деталям рецепта незачем
   знать, с какой вкладки пришёл пользователь.
3. **Псевдо-табы.** Состояние списка/избранного/профиля стирается
   на каждом переходе.
4. **Стек растёт.** Recipes → Favorites → Details = 3 экрана в
   стеке вместо «вкладка Favorites + 1 деталей внутри её ветки».
5. **Нет URL для веба.** На `https://mahallem.ist/#/recipes/123`
   нельзя зайти напрямую.

## Что меняем

Внедряем [`go_router`](https://pub.dev/packages/go_router) с
[`StatefulShellRoute.indexedStack`](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute/StatefulShellRoute.indexedStack.html)
— рекомендованный Flutter-командой паттерн для bottom-tab навигации
с независимыми стеками на каждой вкладке.

### Целевая архитектура

```
GoRouter
└── StatefulShellRoute.indexedStack
    ├── builder: AppShell (Scaffold + AppBottomNavBar — ОДИН раз)
    └── branches:
        ├── ShellBranch[recipes]
        │   ├── /recipes                      → RecipeListPage
        │   └── /recipes/details/:id          → RecipeDetailsPage
        ├── ShellBranch[fridge]
        │   └── /fridge                       → FridgePage (заглушка)
        ├── ShellBranch[favorites]
        │   ├── /favorites                    → FavoritesPage
        │   └── /favorites/details/:id        → RecipeDetailsPage
        └── ShellBranch[profile]
            ├── /profile                      → ProfilePage
            ├── /profile/login                → LoginPage
            ├── /profile/signup               → SignUpPage
            └── /profile/recover              → PasswordRecoveryPage
```

### Ключевые принципы

1. **Один `AppBottomNavBar` на всё приложение** — внутри builder
   `StatefulShellRoute.indexedStack`.
2. **Нет `originTab`** — стек каждой ветки сам помнит, откуда
   пришли. `RecipeDetailsPage` под `/recipes/details/:id` рисуется
   в ветке Recipes, а под `/favorites/details/:id` — в ветке
   Favorites. NavBar подсвечивает активную ветку автоматически
   (`navShell.currentIndex`).
3. **Состояние сохраняется** — `IndexedStack` под капотом
   `StatefulShellRoute` держит каждую ветку живой между переходами.
4. **Deep linking** — на вебе `https://mahallem.ist/#/recipes/52772`
   открывает страницу деталей конкретного рецепта; в мобильных
   платформах работает push-нотификация на ссылку.
5. **Type-safe навигация** — переходы через
   `context.go('/favorites')` / `context.push('/recipes/details/52772')`
   вместо `Navigator.of(context).push(MaterialPageRoute(builder: ...))`.

## Затрагиваемые файлы

### Новые
* `recipe_list/lib/router/app_router.dart` — конфигурация GoRouter.
* `recipe_list/lib/router/routes.dart` — константы путей
  (`Routes.recipes`, `Routes.recipeDetails(id)` и т.п.).
* `recipe_list/lib/ui/app_shell.dart` — `AppShell` с единственным
  `AppBottomNavBar`.

### Изменённые
* `recipe_list/pubspec.yaml` — добавить `go_router: ^14.0.0`.
* `recipe_list/lib/main.dart` — `MaterialApp.router(routerConfig: ...)`
  вместо `MaterialApp(home: ...)`.
* `recipe_list/lib/ui/recipe_list_page.dart` — убрать
  `bottomNavigationBar`, убрать `_onNavTap`, переходы через
  `context.push`.
* `recipe_list/lib/ui/favorites_page.dart` — то же самое.
* `recipe_list/lib/ui/recipe_details_page.dart` — **убрать**
  поле `originTab` целиком. Принимает `recipeId` из path-параметра,
  recipe резолвит через `RecipeRepository`/`RecipeApi`.
* `recipe_list/lib/ui/source_page.dart` — убрать `bottomNavigationBar`.
* `recipe_list/lib/ui/login_page.dart`,
  `signup_page.dart`, `password_recovery_page.dart` — переход
  на `context.push('/profile/login')` и аналоги, `pop()` через
  `context.pop()`.

### Документация
* `docs/project_log.md` — запись о рефакторинге после каждого чанка.
* `docs/go-router-shell-refactor.md` (этот файл).
* `todo/19-go-router-shell.md` — план чанков.

## План разбиения по чанкам

Подробности — в `todo/19-go-router-shell.md`. Кратко: 5 коммитов,
каждый зелёный на тестах перед переходом к следующему.

| Чанк | Описание | Можно мержить отдельно? |
|------|----------|-------------------------|
| A | Зависимость `go_router`, `AppShell`, минимальный `GoRouter` с одной вкладкой Recipes | ✅ |
| B | Перевод вкладки Favorites под `StatefulShellBranch`, удаление `originTab` | ✅ |
| C | Перевод вкладки Profile (login/signup/recovery) | ✅ |
| D | Перевод вспомогательных экранов (`SourcePage`, `AddRecipePage`, `AdminAfterLoginPage`) | ✅ |
| E | Cleanup: удаление `_onNavTap`-дублей, dead code, обновление `project_log.md` | ✅ |

## Риски и митигация

| Риск | Митигация |
|------|-----------|
| Сломается анимация slide-up между login/signup/recovery (используют `PageRouteBuilder` с `Tween<Offset>`) | В `GoRoute` использовать `pageBuilder: (ctx, state) => CustomTransitionPage(...)` с тем же `SlideTransition` |
| Сломается `Navigator.of(context).maybePop()` в существующих коллбэках (например, `RecipeDetailsPage` при удалении рецепта через owner-actions) | Заменить на `context.pop()` (go_router-aware) |
| Сломается передача `RecipeApi`/`RecipeRepository` через конструктор | Использовать `InheritedWidget` (`RecipeServices.of(context)`) или `Provider`, конфигурируется в `AppShell.body` |
| Сломаются deep-link тесты | Добавить `test/router/router_test.dart` с golden-сценариями (`/recipes/details/52772` → видим заголовок рецепта) |
| Web URL начнёт показывать `/#/...` (хеш-навигация) | По умолчанию OK; если нужно убрать `#`, конфигурировать `setUrlStrategy(PathUrlStrategy())` (требует `flutter_web_plugins`) |

## Альтернативы (отвергнуты)

* **`IndexedStack` без go_router.** Простое решение, но не даёт
  deep linking (на вебе все экраны под одним URL). Для проекта,
  уже работающего на `https://mahallem.ist`, теряем shareable
  links.
* **Auto Route.** Code-gen из аннотаций. Мощнее, но избыточно
  для размера проекта; команда не использует build_runner-генераторы.
* **Глобальный `ValueNotifier<AppNavTab>`.** Решает только подсветку
  NavBar, оставляет дублирование `_onNavTap` и проблему с состоянием.

## Acceptance criteria

После выполнения всех чанков:

- [x] `grep -r "originTab" recipe_list/lib` → 0 *кодовых* результатов
  (остаются только историко-объяснительные комментарии в
  `routes.dart`, `favorites_page.dart`, `recipe_details_page.dart`).
- [x] `grep -r "AppBottomNavBar(" recipe_list/lib` → ровно 1 кодовое
  использование (внутри `AppShell`); второе вхождение — конструктор
  самого виджета.
- [x] При переходе Favorites → Recipe Details → Back: пользователь
  возвращается на Favorites с **сохранённой позицией скролла и
  поисковым запросом** (state ветки сохраняется через
  `StatefulShellRoute.indexedStack`).
- [x] На вебе `https://mahallem.ist/#/recipes/details/52772` открывает
  страницу деталей конкретного рецепта (без splash-а — попадаем
  сразу внутрь Recipes-ветки).
- [x] Анимация slide-up для `/profile/login` и `/profile/admin`
  сохранена через `CustomTransitionPage` + `Tween<Offset>` в
  `_slideUpPage` (`app_router.dart`).
- [x] `flutter test` — 95 pass / 6 несвязанных fail (тот же
  baseline, что и до рефакторинга).
- [x] `flutter analyze` без warnings/errors.

## Карта маршрутов (итоговая)

| Путь | Экран | Ветка |
|------|-------|-------|
| `/recipes` | `SplashAndRecipes` (Splash + лента) | [0] Recipes |
| `/recipes/details/:id` | `RecipeDetailsPage` (extra: `Recipe`) | [0] Recipes |
| `/recipes/add` | `AddRecipePage` (новый рецепт) | [0] Recipes |
| `/recipes/edit/:id` | `AddRecipePage` (extra: `Recipe`, edit-режим) | [0] Recipes |
| `/recipes/source?url=…` | `SourcePage` (WebView внешнего рецепта) | [0] Recipes |
| `/fridge` | `_ComingSoonPage` (placeholder) | [1] Fridge |
| `/favorites` | `FavoritesPage` | [2] Favorites |
| `/favorites/details/:id` | `RecipeDetailsPage` (extra: `Recipe`) | [2] Favorites |
| `/favorites/add` | `AddRecipePage` (новый рецепт) | [2] Favorites |
| `/favorites/edit/:id` | `AddRecipePage` (extra: `Recipe`, edit-режим) | [2] Favorites |
| `/favorites/source?url=…` | `SourcePage` (WebView внешнего рецепта) | [2] Favorites |
| `/profile` | redirect-only | [3] Profile |
| `/profile/login` | `LoginPage` (slide-up) | [3] Profile |
| `/profile/admin` | `AdminAfterLoginPage` (slide-up) | [3] Profile |

Под `/profile` ветке корневой `GoRoute` сам ничего не рендерит —
`_profileRedirect` уводит на login или admin в зависимости от
состояния notifier-ов из `auth/admin_session.dart`. Edit/source
доступны под обеими ветками (recipes/favorites): callsite
определяет нужный префикс через `Routes.currentBranchBase`, чтобы
push не выкидывал пользователя на чужую вкладку.

### Что осталось вне рефакторинга

* `AdminUsersPage` и `AdminAddedRecipesPage` открываются обычным
  `Navigator.push(MaterialPageRoute)` поверх `/profile/admin`. Они
  целиком живут внутри admin-модального стека и не отображаются в
  AppBottomNavBar; перевод их на nested-routes даст лишь косметический
  выигрыш, поэтому в чанке D/E намеренно не делался.
