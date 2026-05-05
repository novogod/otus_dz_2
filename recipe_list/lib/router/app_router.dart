import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_session.dart';
import '../data/app_services.dart';
import '../i18n.dart';
import '../main.dart' show splashAndRecipesKey;
import '../models/recipe.dart';
import '../ui/add_recipe_page.dart';
import '../ui/admin_after_login_page.dart';
import '../ui/app_shell.dart';
import '../ui/app_theme.dart' show AppDurations;
import '../ui/favorites_page.dart';
import '../ui/login_page.dart';
import '../ui/recipe_details_page.dart';
import '../ui/source_page.dart';
import '../ui/splash_and_recipes.dart';
import 'routes.dart';

/// Корневой [GlobalKey] для root-навигатора `GoRouter`.
///
/// Передаётся в `parentNavigatorKey:` тех роутов, которые
/// должны рендериться **поверх** shell-навбара (login/admin).
/// Без этого они открывались бы внутри ветки профиля, и
/// `AppBottomNavBar` оставался бы видимым под ними — пользователь
/// видел экран авторизации с навбаром снизу. См. issue
/// «Splash and login/signup are below the bottom navbar».
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Глобальный [GoRouter] приложения.
///
/// Стратегия (см. `docs/go-router-shell-refactor.md`):
/// * `StatefulShellRoute.indexedStack` — корневой shell с
///   `AppBottomNavBar` в [AppShell]. На чанке A определена
///   единственная реальная ветка `recipes`; остальные вкладки
///   (`fridge`, `favorites`, `profile`) — placeholder-ы, которые
///   будут заменены в чанках B/C.
/// * Внутри recipes-ветки рендерится связка `splash → recipe list`
///   (тот же [_AppRoot], что был раньше внутри `MaterialApp.home`).
/// * Анимация slide-up сохраняется, потому что [SplashAndRecipes]
///   живёт в `pageBuilder` ветки и его state кэшируется
///   `IndexedStack`-ом shell-а.
final GoRouter appRouter = GoRouter(
  initialLocation: Routes.recipes,
  navigatorKey: rootNavigatorKey,
  // Перерисовываем редиректы при смене auth-состояния: после
  // успешного логина `/profile/login` должен автоматически
  // переехать на `/profile/admin`, а после `logout` — обратно
  // (см. `_profileRedirect` ниже). Без `refreshListenable`
  // редиректы запускались бы только на явных навигациях.
  refreshListenable: Listenable.merge(<Listenable>[
    adminLoggedInNotifier,
    userLoggedInNotifier,
    currentRecipeAdminTokenNotifier,
    currentUserLoginNotifier,
  ]),
  redirect: _profileRedirect,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navShell) {
        return AppShell(navShell: navShell);
      },
      branches: <StatefulShellBranch>[
        // [0] Recipes — реальный экран ленты + splash.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.recipes,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                child: SplashAndRecipes(key: splashAndRecipesKey),
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: Routes.detailsSubpath,
                  builder: (context, state) =>
                      _buildDetailsPage(context, state),
                ),
                GoRoute(
                  path: Routes.addSubpath,
                  builder: (context, state) => _buildAddRecipePage(state),
                ),
                GoRoute(
                  path: Routes.editSubpath,
                  builder: (context, state) => _buildAddRecipePage(state),
                ),
                GoRoute(
                  path: Routes.sourceSubpath,
                  builder: (context, state) => _buildSourcePage(state),
                ),
              ],
            ),
          ],
        ),
        // [1] Fridge — placeholder, чанк выходит за рамки 19;
        //     показывает «coming soon» с возвратом по тапу.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/fridge',
              pageBuilder: (context, state) =>
                  const NoTransitionPage<void>(child: _ComingSoonPage()),
            ),
          ],
        ),
        // [2] Favorites — реальный экран «Избранного». Зависимости
        //     (`api`/`repository`) забираются из [appServicesNotifier],
        //     который наполняется `RecipeListLoader`-ом при первом
        //     успешном раскладе ленты. До этого момента
        //     `FavoritesPage` корректно работает без api (FAB
        //     добавления просто не рендерится).
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.favorites,
              pageBuilder: (context, state) =>
                  const NoTransitionPage<void>(child: _FavoritesBranchRoot()),
              routes: <RouteBase>[
                GoRoute(
                  path: Routes.detailsSubpath,
                  builder: (context, state) =>
                      _buildDetailsPage(context, state),
                ),
                GoRoute(
                  path: Routes.addSubpath,
                  builder: (context, state) => _buildAddRecipePage(state),
                ),
                GoRoute(
                  path: Routes.editSubpath,
                  builder: (context, state) => _buildAddRecipePage(state),
                ),
                GoRoute(
                  path: Routes.sourceSubpath,
                  builder: (context, state) => _buildSourcePage(state),
                ),
              ],
            ),
          ],
        ),
        // [3] Profile — auth-aware ветка с двумя sub-роутами:
        //     `/profile/login` (форма входа) и `/profile/admin`
        //     (после-логин экран). Корневой `/profile` сам
        //     ничего не рендерит — `_profileRedirect` уводит
        //     либо на login, либо на admin в зависимости от
        //     состояния notifier-ов из `admin_session.dart`.
        //     Slide-up анимация sub-роутов сохранена через
        //     `CustomTransitionPage` (см. `_slideUpPage`).
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.profile,
              // Никогда не рендерится — redirect всегда уводит
              // на login или admin. Builder нужен формально.
              builder: (context, state) =>
                  const Scaffold(body: SizedBox.shrink()),
              routes: <RouteBase>[
                GoRoute(
                  path: 'login',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) => _slideUpPage<void>(
                    key: const ValueKey('profile-login'),
                    child: LoginPage(
                      initialLogin:
                          currentUserLoginNotifier.value?.trim().isNotEmpty ==
                              true
                          ? currentUserLoginNotifier.value!.trim()
                          : null,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'admin',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final login = currentUserLoginNotifier.value?.trim() ?? '';
                    return _slideUpPage<void>(
                      key: const ValueKey('profile-admin'),
                      child: AdminAfterLoginPage(
                        adminLogin: login,
                        adminPassword: currentSessionAdminPassword ?? '',
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Заглушка для ещё не реализованных вкладок (Fridge).
/// Показывает локализованное «скоро будет» и кнопку назад
/// на ветку Recipes.
class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(body: Center(child: Text(s.tabComingSoon)));
  }
}

/// Заглушка для вкладки «Избранное» на чанке A. Будет заменена
/// в чанке B на реальный `FavoritesPage` со state-сохранением
/// между переключениями вкладок.
class _FavoritesBranchRoot extends StatelessWidget {
  const _FavoritesBranchRoot();

  @override
  Widget build(BuildContext context) {
    // `FavoritesPage` ждёт `api`/`repository`, которые
    // публикуются `RecipeListLoader` через [appServicesNotifier]
    // (см. `lib/data/app_services.dart`). На холодный старт
    // notifier ещё пуст — рендерим страницу без зависимостей,
    // FAB добавления просто не появится. Когда сервисы доедут,
    // [ValueListenableBuilder] перерисует ветку с уже не-null
    // api/repo.
    return ValueListenableBuilder<AppServices?>(
      valueListenable: appServicesNotifier,
      builder: (context, services, _) {
        return FavoritesPage(
          api: services?.api,
          repository: services?.repository,
        );
      },
    );
  }
}

/// Сборка экрана деталей рецепта для go_router-веток. Полный
/// `Recipe` пробрасывается через `state.extra` (так делают
/// тапы с ленты/избранного), что позволяет открыть детали
/// без повторного fetch-а. При deep-link / refresh-е страницы
/// extra будет null — в этом случае показываем `Scaffold` с
/// «загрузка…», т.к. реальный fetch по id появится в чанке D.
Widget _buildDetailsPage(BuildContext context, GoRouterState state) {
  final recipe = state.extra;
  if (recipe is Recipe) {
    final services = appServicesNotifier.value;
    return RecipeDetailsPage(
      recipe: recipe,
      api: services?.api,
      repository: services?.repository,
    );
  }
  // Deep-link без extra — детали без фоновой подгрузки пока
  // не реализованы (см. чанк D плана). Возвращаемся на ветку.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted && context.canPop()) context.pop();
  });
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Сборка экрана `AddRecipePage` для add- и edit-роутов.
///
/// Подхватывает api/repository из [appServicesNotifier] (так же,
/// как [_FavoritesBranchRoot]), чтобы строки на push не нужно
/// было таскать сервисы вручную через `extra`. В edit-режиме
/// полный [Recipe] прилетает через `state.extra` (callsite
/// уже знает рецепт). Если extra пустое (например, прямой
/// deep-link на `/recipes/edit/123` без preload) — выходим
/// обратно: full edit без подкачки рецепта в чанке D не
/// реализуем.
Widget _buildAddRecipePage(GoRouterState state) {
  final services = appServicesNotifier.value;
  final extra = state.extra;
  Recipe? existing;
  if (extra is Recipe) existing = extra;
  return AddRecipePage(
    api: services?.api,
    repository: services?.repository,
    existing: existing,
  );
}

/// Сборка [SourcePage] из query-параметра `url`. Если url не
/// задан — `SourcePage` всё равно отрендерится, но загрузить
/// ничего не сможет (пустая строка), поэтому в этом редком
/// случае показываем заглушку и возвращаемся.
Widget _buildSourcePage(GoRouterState state) {
  final url = state.uri.queryParameters['url'] ?? '';
  if (url.isEmpty) {
    return const Scaffold(body: Center(child: Text('source url missing')));
  }
  return SourcePage(url: url);
}

/// Auth-aware redirect для профильной ветки. Запускается
/// `GoRouter` на каждой навигации и при срабатывании
/// `refreshListenable` (см. конфигурацию выше). Логика:
///
/// * Корень `/profile` сам по себе не имеет UI — он всегда
///   уводит на `/profile/login` или `/profile/admin`.
/// * Если пользователь оказался на `/profile/login`, но
///   admin-токен/пароль появились (= успешный логин), уводим
///   на `/profile/admin`.
/// * Если на `/profile/admin`, но admin-доступ пропал (logout
///   очистил `currentRecipeAdminTokenNotifier` и
///   `adminLoggedInNotifier`), уводим обратно на login.
/// * Прочие пути (вне `/profile`) пропускаем как есть.
String? _profileRedirect(BuildContext context, GoRouterState state) {
  final path = state.uri.path;
  if (!path.startsWith(Routes.profile)) return null;
  final hasAdmin = adminLoggedInNotifier.value;
  final token = currentRecipeAdminTokenNotifier.value;
  final hasToken = token != null && token.isNotEmpty;
  final login = currentUserLoginNotifier.value?.trim() ?? '';
  final canShowAdmin = (hasAdmin || hasToken) && login.isNotEmpty;
  if (path == Routes.profile) {
    return canShowAdmin ? Routes.profileAdmin : Routes.profileLogin;
  }
  if (path == Routes.profileLogin && canShowAdmin) {
    return Routes.profileAdmin;
  }
  if (path == Routes.profileAdmin && !canShowAdmin) {
    return Routes.profileLogin;
  }
  return null;
}

/// Slide-up `CustomTransitionPage` — общий конструктор для
/// `/profile/login` и `/profile/admin`. Параметры тayouта
/// (длительность, кривая, направление) совпадают с тем, что
/// раньше задавалось в `buildLoginRoute`/`_signUpRoute`/
/// `openPasswordRecoveryPage`, чтобы UX слайд-апа не дрейфовал
/// между «модальным» и «вкладочным» открытием.
CustomTransitionPage<T> _slideUpPage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: AppDurations.splashTransition,
    reverseTransitionDuration: AppDurations.splashTransition,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved);
      return SlideTransition(position: slide, child: child);
    },
  );
}
