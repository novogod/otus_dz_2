// Тесты профильной ветки роутера: чанк C
// `todo/19-go-router-shell.md`.
//
// Покрытие:
// * Тап по вкладке Profile с пустыми auth-нотифаерами уводит
//   на `/profile/login` (через `_profileRedirect`).
// * Если admin-нотифаеры выставлены ДО навигации, переход
//   уходит сразу на `/profile/admin`.
// * Включение `adminLoggedInNotifier`/`currentUserLoginNotifier`
//   уже на `/profile/login` перерисовывает редирект благодаря
//   `refreshListenable` и заводит на `/profile/admin`.
// * `AppBottomNavBar` остаётся ровно один экземпляр на любой
//   из sub-роутов (главное достижение чанка A — здесь не
//   ломается).
//
// Тестовый роутер — самостоятельная сборка, чтобы избежать
// зависимостей реального `appRouter` от splash-таймеров и
// сетевых вызовов в `SplashAndRecipes`/`FavoritesPage`. Логика
// редиректа дублируется 1-в-1 c `_profileRedirect`
// в `lib/router/app_router.dart`. Если та логика
// перенастраивается — этот тест нужно править синхронно.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_list/auth/admin_session.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/router/routes.dart';
import 'package:recipe_list/ui/app_bottom_nav_bar.dart';
import 'package:recipe_list/ui/app_shell.dart';

/// Точная копия `_profileRedirect`. Дублирование намеренное —
/// не хочется делать функцию публичной только ради теста.
String? _profileRedirect(BuildContext context, GoRouterState state) {
  final path = state.uri.path;
  if (!path.startsWith(Routes.profile)) return null;
  final hasAdmin = adminLoggedInNotifier.value;
  final hasUser = userLoggedInNotifier.value;
  final token = currentRecipeAdminTokenNotifier.value;
  final hasToken = token != null && token.isNotEmpty;
  final login = currentUserLoginNotifier.value?.trim() ?? '';
  final canShowProfile =
      (hasAdmin || hasUser || hasToken) && login.isNotEmpty;
  if (path == Routes.profile) {
    return canShowProfile ? Routes.profileAdmin : Routes.profileLogin;
  }
  if (path == Routes.profileLogin && canShowProfile) {
    return Routes.profileAdmin;
  }
  if (path == Routes.profileAdmin && !canShowProfile) {
    return Routes.profileLogin;
  }
  return null;
}

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: Routes.recipes,
    refreshListenable: Listenable.merge(<Listenable>[
      adminLoggedInNotifier,
      userLoggedInNotifier,
      currentRecipeAdminTokenNotifier,
      currentUserLoginNotifier,
    ]),
    redirect: _profileRedirect,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => AppShell(navShell: navShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.recipes,
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: Scaffold(body: Center(child: Text('recipes-stub'))),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/fridge',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: Scaffold(body: Center(child: Text('fridge-stub'))),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.favorites,
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: Scaffold(body: Center(child: Text('favorites-stub'))),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.profile,
                builder: (context, state) =>
                    const Scaffold(body: SizedBox.shrink()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'login',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: Scaffold(
                            body: Center(child: Text('login-stub')),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'admin',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: Scaffold(
                            body: Center(child: Text('admin-stub')),
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _wrap(GoRouter router) {
  return TranslationProvider(
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
    ),
  );
}

void _resetAuth() {
  adminLoggedInNotifier.value = false;
  userLoggedInNotifier.value = false;
  currentRecipeAdminTokenNotifier.value = null;
  currentUserLoginNotifier.value = null;
}

void main() {
  setUp(_resetAuth);
  tearDown(_resetAuth);

  testWidgets('tapping Profile with no auth lands on /profile/login', (
    tester,
  ) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabProfile));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.profileLogin,
    );
    expect(find.text('login-stub'), findsOneWidget);
    // Гость на ветке profile — навбар скрыт (LoginPage full-screen).
    expect(find.byType(AppBottomNavBar), findsNothing);
  });

  testWidgets('tapping Profile while admin lands on /profile/admin', (
    tester,
  ) async {
    adminLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'alice';

    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabProfile));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.profileAdmin,
    );
    expect(find.text('admin-stub'), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('flipping auth notifiers on /profile/login redirects to admin', (
    tester,
  ) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    // Идём на login.
    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabProfile));
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsOneWidget);

    // Имитируем «успешный логин админа» — flipаем нотифаеры,
    // refreshListenable должен перерисовать redirect.
    adminLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'bob';
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.profileAdmin,
    );
    expect(find.text('admin-stub'), findsOneWidget);
    expect(find.text('login-stub'), findsNothing);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('logout on /profile/admin redirects back to /profile/login', (
    tester,
  ) async {
    adminLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'carol';

    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabProfile));
    await tester.pumpAndSettle();
    expect(find.text('admin-stub'), findsOneWidget);

    // Имитируем logout: чистим нотифаеры. refreshListenable
    // запускает redirect, путь меняется на /profile/login.
    adminLoggedInNotifier.value = false;
    currentUserLoginNotifier.value = null;
    currentRecipeAdminTokenNotifier.value = null;
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.profileLogin,
    );
    expect(find.text('login-stub'), findsOneWidget);
  });

  // Regression: после входа обычным пользователем (не админом)
  // adminLoggedInNotifier остаётся false, но userLoggedInNotifier
  // = true. Раньше canShowAdmin учитывал только admin-флаги, и
  // пользователь оставался на /profile/login. Теперь любой
  // залогиненный пользователь уходит на /profile/admin.
  testWidgets('flipping userLoggedInNotifier on /profile/login redirects to admin', (
    tester,
  ) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabProfile));
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsOneWidget);

    // Имитируем «успешный логин обычного пользователя».
    userLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'dave';
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.profileAdmin,
    );
    expect(find.text('admin-stub'), findsOneWidget);
  });
}
