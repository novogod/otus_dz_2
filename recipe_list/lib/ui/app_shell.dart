import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_session.dart' show userLoggedInNotifier;
import '../i18n.dart';
import '../main.dart' show bottomNavVisibleNotifier;
import 'app_bottom_nav_bar.dart';
import 'signup_page.dart' show openSignUpPage;
import 'login_page.dart' show openLoginPage;

/// Корневой Scaffold приложения для shell-навигации
/// `StatefulShellRoute.indexedStack`. Рисует один общий
/// [AppBottomNavBar] поверх всех вкладок и проксирует тапы
/// в `navShell.goBranch(...)`.
///
/// Подробнее см. `docs/go-router-shell-refactor.md` и
/// `todo/19-go-router-shell.md` (чанк A).
class AppShell extends StatelessWidget {
  /// Передаётся `StatefulShellRoute.indexedStack.builder`-ом.
  /// Содержит текущий [Navigator] для каждой ветки и API
  /// `goBranch` для переключения.
  final StatefulNavigationShell navShell;

  const AppShell({super.key, required this.navShell});

  @override
  Widget build(BuildContext context) {
    final tab = AppNavTab.values[navShell.currentIndex];
    return Scaffold(
      body: navShell,
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: bottomNavVisibleNotifier,
        builder: (context, visible, _) {
          if (!visible) return const SizedBox.shrink();
          return AppBottomNavBar(
            current: tab,
            onTap: (next) => _onTabTap(context, next),
          );
        },
      ),
    );
  }

  /// Поведение `goBranch`: при повторном тапе на текущую вкладку
  /// `initialLocation: true` сбрасывает её стек к корневому
  /// маршруту (стандартный UX мобильных табов).
  ///
  /// Гость, тапнувший по «Избранному», не должен попадать
  /// внутрь — `docs/login-auth.md` §5 требует показать snackbar
  /// `favoritesRegistrationRequired` с экшеном «Sign Up».
  /// Раньше эта проверка жила в `RecipeListPage._onNavTap`,
  /// но после рефакторинга навбар рисуется тут и проверку
  /// нужно делать на этом же уровне.
  void _onTabTap(BuildContext context, AppNavTab tab) {
    if (tab == AppNavTab.favorites && !userLoggedInNotifier.value) {
      _showFavoritesRegistrationRequired(context);
      return;
    }
    final idx = tab.index;
    navShell.goBranch(idx, initialLocation: idx == navShell.currentIndex);
  }

  void _showFavoritesRegistrationRequired(BuildContext context) {
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.favoritesRegistrationRequired),
          action: SnackBarAction(
            label: s.signUp,
            onPressed: () async {
              final created = await openSignUpPage(context);
              if (!context.mounted || !created) return;
              await openLoginPage(context);
            },
          ),
        ),
      );
  }
}
