// Тесты на чанк D `todo/19-go-router-shell.md`: вспомогательные
// подэкраны (Source/Add/Edit) как nested-routes под каждой
// веткой `StatefulShellRoute`. Проверяем, что:
//   * `Routes.*Under` собирают валидные пути с правильным
//     префиксом и query;
//   * `Routes.currentBranchBase` корректно возвращает базу
//     по location'у;
//   * `context.push` на сгенерированный путь действительно
//     рендерит ожидаемый экран без выхода из ветки.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/router/routes.dart';
import 'package:recipe_list/ui/app_bottom_nav_bar.dart';
import 'package:recipe_list/ui/app_shell.dart';

GoRouter _buildTestRouter() {
  Page<void> stub(String label) => NoTransitionPage<void>(
    child: Scaffold(body: Center(child: Text(label))),
  );
  GoRoute branchRoute(String base, String rootLabel) {
    return GoRoute(
      path: base,
      pageBuilder: (context, state) => stub('$rootLabel-root'),
      routes: <RouteBase>[
        GoRoute(
          path: Routes.addSubpath,
          builder: (context, state) =>
              Scaffold(body: Center(child: Text('$rootLabel-add'))),
        ),
        GoRoute(
          path: Routes.editSubpath,
          builder: (context, state) {
            final extra = state.extra;
            final extraTag = extra is String ? '+extra=$extra' : '';
            return Scaffold(
              body: Center(
                child: Text(
                  '$rootLabel-edit-${state.pathParameters['id']}$extraTag',
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: Routes.sourceSubpath,
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                '$rootLabel-source-${state.uri.queryParameters['url']}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  return GoRouter(
    initialLocation: Routes.recipes,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => AppShell(navShell: navShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[branchRoute(Routes.recipes, 'recipes')],
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
            routes: <RouteBase>[branchRoute(Routes.favorites, 'favorites')],
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
  group('Routes path helpers', () {
    test('addUnder/editUnder/sourceUnder collate paths correctly', () {
      expect(Routes.addUnder(Routes.recipes), '/recipes/add');
      expect(Routes.addUnder(Routes.favorites), '/favorites/add');
      expect(Routes.editUnder(Routes.recipes, 42), '/recipes/edit/42');
      expect(Routes.editUnder(Routes.favorites, 42), '/favorites/edit/42');
      expect(
        Routes.sourceUnder(Routes.recipes, 'https://example.com/?a=1'),
        '/recipes/source?url=https%3A%2F%2Fexample.com%2F%3Fa%3D1',
      );
    });

    test('currentBranchBase resolves prefix to recipes/favorites', () {
      expect(Routes.currentBranchBase('/recipes'), Routes.recipes);
      expect(Routes.currentBranchBase('/recipes/details/7'), Routes.recipes);
      expect(Routes.currentBranchBase('/favorites'), Routes.favorites);
      expect(
        Routes.currentBranchBase('/favorites/details/7'),
        Routes.favorites,
      );
      // По плану любой нерелевантный префикс трактуется как recipes
      // (там этих подэкранов всё равно нет, но дефолт нужен валидный).
      expect(Routes.currentBranchBase('/profile/login'), Routes.recipes);
    });
  });

  testWidgets('push add under recipes branch renders add page', (tester) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final ctx = tester.element(find.byType(AppShell));
    GoRouter.of(ctx).push(Routes.addUnder(Routes.recipes));
    await tester.pumpAndSettle();

    expect(find.text('recipes-add'), findsOneWidget);
    // AppShell + навбар должны остаться поверх — это nested route
    // внутри своей ветки, а не отдельный экран.
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('push edit under favorites branch passes id and extra', (
    tester,
  ) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final ctx = tester.element(find.byType(AppShell));
    GoRouter.of(ctx).go(Routes.favorites);
    await tester.pumpAndSettle();
    GoRouter.of(ctx).push(Routes.editUnder(Routes.favorites, 99), extra: 'r99');
    await tester.pumpAndSettle();

    expect(find.text('favorites-edit-99+extra=r99'), findsOneWidget);
    // Сам факт рендера достаточен: путь активной ветки в
    // go_router после `push`-а в IndexedStack возвращает
    // root-локацию ветки, а не верхний кадр стека.
  });

  testWidgets('push source carries url query param', (tester) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final ctx = tester.element(find.byType(AppShell));
    GoRouter.of(
      ctx,
    ).push(Routes.sourceUnder(Routes.recipes, 'https://example.com'));
    await tester.pumpAndSettle();

    expect(find.text('recipes-source-https://example.com'), findsOneWidget);
  });
}
