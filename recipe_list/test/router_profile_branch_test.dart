// Тесты профильной ветки роутера.
//
// После упрощения (удалены sub-routes /profile/login и
// /profile/admin) — единственный профильный роут `/profile`
// рендерит auth-aware виджет, который сам выбирает между
// LoginPage и AdminAfterLoginPage по auth-нотифаерам.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_list/auth/admin_session.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/router/routes.dart';
import 'package:recipe_list/ui/app_bottom_nav_bar.dart';
import 'package:recipe_list/ui/app_shell.dart';

class _ProfileStub extends StatelessWidget {
  const _ProfileStub();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adminLoggedInNotifier,
      builder: (context, _, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: userLoggedInNotifier,
          builder: (context, _, __) {
            return ValueListenableBuilder<String?>(
              valueListenable: currentUserLoginNotifier,
              builder: (context, login, _) {
                final hasAuth =
                    (adminLoggedInNotifier.value ||
                        userLoggedInNotifier.value) &&
                    (login?.trim().isNotEmpty ?? false);
                return Scaffold(
                  body: Center(
                    child: Text(hasAuth ? 'admin-stub' : 'login-stub'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
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
                builder: (context, state) => const _ProfileStub(),
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

  testWidgets('tapping Profile with no auth shows login-stub on /profile', (
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
      Routes.profile,
    );
    expect(find.text('login-stub'), findsOneWidget);
    // Гость на ветке profile — навбар скрыт (LoginPage full-screen).
    expect(find.byType(AppBottomNavBar), findsNothing);
  });

  testWidgets('tapping Profile while admin shows admin-stub on /profile', (
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
      Routes.profile,
    );
    expect(find.text('admin-stub'), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('flipping admin auth on /profile swaps stub login -> admin', (
    tester,
  ) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabProfile));
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsOneWidget);

    adminLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'bob';
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.profile,
    );
    expect(find.text('admin-stub'), findsOneWidget);
    expect(find.text('login-stub'), findsNothing);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
  });

  testWidgets('logout on /profile swaps stub admin -> login', (tester) async {
    adminLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'carol';

    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabProfile));
    await tester.pumpAndSettle();
    expect(find.text('admin-stub'), findsOneWidget);

    adminLoggedInNotifier.value = false;
    currentUserLoginNotifier.value = null;
    currentRecipeAdminTokenNotifier.value = null;
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.profile,
    );
    expect(find.text('login-stub'), findsOneWidget);
  });

  // Regression: после входа обычным пользователем (не админом)
  // adminLoggedInNotifier=false, userLoggedInNotifier=true.
  testWidgets('flipping user auth on /profile swaps stub login -> admin', (
    tester,
  ) async {
    final router = _buildTestRouter();
    await tester.pumpWidget(_wrap(router));
    await tester.pump();

    final s = S.of(tester.element(find.byType(AppShell)));
    await tester.tap(find.text(s.tabProfile));
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsOneWidget);

    userLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'dave';
    await tester.pumpAndSettle();

    expect(find.text('admin-stub'), findsOneWidget);
  });
}
