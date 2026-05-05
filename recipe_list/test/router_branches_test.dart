// Тесты на чанк B `todo/19-go-router-shell.md`: вкладка Favorites
// в виде отдельной ветки `StatefulShellRoute`, экран деталей без
// `originTab`, переходы через `context.push` с расходящимися
// путями `/recipes/details/:id` и `/favorites/details/:id`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_list/auth/admin_session.dart' show userLoggedInNotifier;
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/router/routes.dart';
import 'package:recipe_list/ui/app_bottom_nav_bar.dart';
import 'package:recipe_list/ui/app_shell.dart';

/// Минимальный аналог настоящего роутера: те же 4 ветки и тот
/// же `AppShell`, но с лёгкими плэйсхолдерами вместо
/// `FavoritesPage`/`RecipeDetailsPage` (этим экранам нужен живой
/// SQLite/`appServicesNotifier`, что для smoke-теста маршрутов
/// избыточно). Что важно для теста — структура веток и пути.
GoRouter _buildTestRouter() {
  Page<void> stub(String label) => NoTransitionPage<void>(
    child: Scaffold(body: Center(child: Text(label))),
  );
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
                pageBuilder: (context, state) => stub('recipes-root'),
                routes: <RouteBase>[
                  GoRoute(
                    path: Routes.detailsSubpath,
                    builder: (context, state) => Scaffold(
                      body: Center(
                        child: Text(
                          'recipes-details-${state.pathParameters['id']}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/fridge',
                pageBuilder: (context, state) => stub('fridge-root'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.favorites,
                pageBuilder: (context, state) => stub('favorites-root'),
                routes: <RouteBase>[
                  GoRoute(
                    path: Routes.detailsSubpath,
                    builder: (context, state) => Scaffold(
                      body: Center(
                        child: Text(
                          'favorites-details-${state.pathParameters['id']}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.profile,
                pageBuilder: (context, state) => stub('profile-root'),
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
  test('Routes generates branch-specific paths', () {
    expect(Routes.recipeDetails(42), '/recipes/details/42');
    expect(Routes.favoritesDetails(42), '/favorites/details/42');
    expect(Routes.detailsSubpath, 'details/:id');
  });

  testWidgets('push details from recipes branch keeps shell + path', (
    tester,
  ) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    expect(find.text('recipes-root'), findsOneWidget);

    router.go(Routes.recipeDetails(7));
    await tester.pumpAndSettle();

    expect(find.text('recipes-details-7'), findsOneWidget);
    // AppShell с навбаром продолжает рендериться поверх деталей,
    // подсветка вкладки Recipes сохраняется.
    expect(find.byType(AppBottomNavBar), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/recipes/details/7',
    );
  });

  testWidgets('favorites branch has its own details path', (tester) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    router.go(Routes.favoritesDetails(11));
    await tester.pumpAndSettle();

    expect(find.text('favorites-details-11'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/favorites/details/11',
    );
    // Главное: путь именно favorites/, а не recipes/. Это и есть
    // замена выпиленному `originTab` — branch-aware nav.
  });

  testWidgets('details state survives tab switch (IndexedStack)', (
    tester,
  ) async {
    // Гость не может зайти в Favorites (см. AppShell гард,
    // `docs/login-auth.md` §5). Симулируем залогиненную сессию.
    userLoggedInNotifier.value = true;
    addTearDown(() => userLoggedInNotifier.value = false);
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    // Открываем детали в Recipes-ветке через push, чтобы
    // в стеке ветки оказался details/1 поверх recipes-root.
    final ctx = tester.element(find.byType(AppShell));
    GoRouter.of(ctx).push(Routes.recipeDetails(1));
    await tester.pumpAndSettle();
    expect(find.text('recipes-details-1'), findsOneWidget);

    // Переключаемся на Favorites через AppBottomNavBar — это
    // вызывает `navShell.goBranch`, которое ведёт IndexedStack
    // по веткам, не сбрасывая стек Recipes.
    final favoritesCtx = tester.element(find.byType(AppShell));
    final s = Translations.of(favoritesCtx);
    await tester.tap(find.text(s.tabFavorites));
    await tester.pumpAndSettle();
    expect(find.text('favorites-root'), findsOneWidget);

    // Возвращаемся на Recipes — там по-прежнему открыт details/1
    // (state ветки сохранился благодаря IndexedStack).
    await tester.tap(find.text(s.tabRecipes));
    await tester.pumpAndSettle();
    expect(find.text('recipes-details-1'), findsOneWidget);
  });
}
