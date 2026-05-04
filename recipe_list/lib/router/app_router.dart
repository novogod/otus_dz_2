import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../i18n.dart';
import '../main.dart' show splashAndRecipesKey;
import '../ui/app_shell.dart';
import '../ui/login_page.dart' show openProfilePage;
import '../ui/splash_and_recipes.dart';
import 'routes.dart';

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
        // [2] Favorites — placeholder, заменяется в чанке B
        //     на реальный `FavoritesPage`.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.favorites,
              pageBuilder: (context, state) =>
                  const NoTransitionPage<void>(child: _FavoritesStubPage()),
            ),
          ],
        ),
        // [3] Profile — placeholder, заменяется в чанке C.
        //     На чанке A открывает legacy-флоу логина через push,
        //     чтобы UX не ломался.
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.profile,
              pageBuilder: (context, state) =>
                  const NoTransitionPage<void>(child: _ProfileStubPage()),
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
class _FavoritesStubPage extends StatelessWidget {
  const _FavoritesStubPage();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(body: Center(child: Text(s.tabComingSoon)));
  }
}

/// Заглушка для вкладки «Профиль» на чанке A. При маунтинге
/// сразу открывает legacy-флоу логина через [openProfilePage]
/// (использует Navigator.push под капотом). Это сохраняет
/// привычное поведение «тап на Profile → форма логина», пока
/// чанк C не переедет на честные роуты.
class _ProfileStubPage extends StatefulWidget {
  const _ProfileStubPage();

  @override
  State<_ProfileStubPage> createState() => _ProfileStubPageState();
}

class _ProfileStubPageState extends State<_ProfileStubPage> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    // Откладываем до конца кадра: openProfilePage пушит роут
    // на текущий Navigator, а тот ещё не доехал до build-а.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openProfilePage(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
