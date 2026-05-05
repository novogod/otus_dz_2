// Tests for todo/20 chunk D — locale-prefix routing helpers and
// the top-level redirect from `/<lang>/recipes/<id>` into the SPA
// `/recipes/details/<id>?lang=<lang>` route.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_list/router/routes.dart';

void main() {
  group('Routes.localizedRecipe / localizedRecipes', () {
    test('builds /<lang>/recipes/<id>', () {
      expect(Routes.localizedRecipe('en', 52772), '/en/recipes/52772');
      expect(Routes.localizedRecipe('ar', 1), '/ar/recipes/1');
      expect(Routes.localizedRecipe('ku', 999999), '/ku/recipes/999999');
    });

    test('builds /<lang>/recipes', () {
      expect(Routes.localizedRecipes('ru'), '/ru/recipes');
      expect(Routes.localizedRecipes('fa'), '/fa/recipes');
    });

    test('isSupportedLocale matches the supported list', () {
      for (final lang in Routes.supportedLocales) {
        expect(Routes.isSupportedLocale(lang), isTrue, reason: lang);
      }
      expect(Routes.isSupportedLocale('xx'), isFalse);
      expect(Routes.isSupportedLocale(''), isFalse);
    });

    test('localePathPattern lists every supported locale', () {
      final fromPattern = Routes.localePathPattern.split('|').toSet();
      expect(fromPattern, Routes.supportedLocales.toSet());
    });
  });

  testWidgets('top-level GoRoute /<lang>/recipes/<id> redirects into SPA', (
    tester,
  ) async {
    // Minimal router that mirrors only the redirects under test
    // — the rest of the SPA shell is exercised by router_smoke_test.
    final router = GoRouter(
      initialLocation: '/en/recipes/52772',
      routes: <RouteBase>[
        GoRoute(
          path: '/:lang(${Routes.localePathPattern})/recipes/:id',
          redirect: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final lang = state.pathParameters['lang'] ?? '';
            return '${Routes.recipes}/details/$id?lang=$lang';
          },
        ),
        GoRoute(
          path: '/:lang(${Routes.localePathPattern})/recipes',
          redirect: (context, state) {
            final lang = state.pathParameters['lang'] ?? '';
            return '${Routes.recipes}?lang=$lang';
          },
        ),
        GoRoute(
          path: Routes.recipes,
          builder: (context, state) => Scaffold(
            body: Text(
              'recipes lang=${state.uri.queryParameters['lang'] ?? ''}',
            ),
          ),
          routes: <RouteBase>[
            GoRoute(
              path: Routes.detailsSubpath,
              builder: (context, state) => Scaffold(
                body: Text(
                  'details id=${state.pathParameters['id']} '
                  'lang=${state.uri.queryParameters['lang'] ?? ''}',
                ),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('details id=52772 lang=en'), findsOneWidget);

    router.go('/ar/recipes/1');
    await tester.pumpAndSettle();
    expect(find.text('details id=1 lang=ar'), findsOneWidget);

    router.go('/ru/recipes');
    await tester.pumpAndSettle();
    expect(find.text('recipes lang=ru'), findsOneWidget);
  });
}
