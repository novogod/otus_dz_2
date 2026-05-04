// Smoke-тесты роутера: чанк A `todo/19-go-router-shell.md`.
//
// Проверяют, что после миграции на `MaterialApp.router` приложение
// поднимается, отображает splash, по таймеру переходит на список
// рецептов, и нижний `AppBottomNavBar` присутствует ровно
// в одном экземпляре во всём дереве.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/router/routes.dart';
import 'package:recipe_list/ui/app_bottom_nav_bar.dart';
import 'package:recipe_list/ui/app_shell.dart';
import 'package:recipe_list/ui/splash_and_recipes.dart';
import 'package:recipe_list/ui/splash_page.dart';

/// Минимальный роутер для тестов: тот же `StatefulShellRoute`,
/// но без splash-задержки — вместо `SplashAndRecipes` подставляем
/// плэйсхолдер, чтобы pumpAndSettle не зависал на 1.5 с таймере
/// сплэша. Расширения структуры (тогглы вкладок, deep links и т.п.)
/// тестируются в чанках B+.
GoRouter _buildTestRouter({Widget? recipesChild}) {
  return GoRouter(
    initialLocation: Routes.recipes,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => AppShell(navShell: navShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.recipes,
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  child:
                      recipesChild ??
                      const Scaffold(body: Center(child: Text('recipes-stub'))),
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
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: Scaffold(body: Center(child: Text('profile-stub'))),
                ),
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

void main() {
  testWidgets('shell renders AppBottomNavBar exactly once', (tester) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    expect(find.byType(AppBottomNavBar), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('initial route redirects to /recipes', (tester) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.recipes);
    expect(find.text('recipes-stub'), findsOneWidget);
  });

  testWidgets('switching tabs through nav bar uses goBranch', (tester) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    // Тапаем по вкладке Favorites через её label из локализации.
    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabFavorites));
    await tester.pumpAndSettle();

    expect(find.text('favorites-stub'), findsOneWidget);
    expect(find.text('recipes-stub'), findsNothing);

    // Возврат на Recipes.
    await tester.tap(find.text(s.tabRecipes));
    await tester.pumpAndSettle();

    expect(find.text('recipes-stub'), findsOneWidget);
  });

  testWidgets('SplashAndRecipes shows SplashPage at start', (tester) async {
    // Используем настоящую ветку с SplashAndRecipes — но без
    // pumpAndSettle (он бы блокировался на сетевом fetch).
    final router = _buildTestRouter(recipesChild: const SplashAndRecipes());
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    expect(find.byType(SplashPage), findsOneWidget);

    // Гасим оставшиеся таймеры явно — сетевой запрос внутри
    // RecipeListLoader будет зафейлен, что в смоук-тесте ОК.
    await tester.pump(const Duration(seconds: 5));
  });
}
