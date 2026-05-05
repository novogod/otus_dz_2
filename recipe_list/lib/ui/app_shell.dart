import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_session.dart'
    show adminLoggedInNotifier, userLoggedInNotifier;
import '../main.dart' show bottomNavVisibleNotifier;
import 'app_bottom_nav_bar.dart';
import 'registration_required_snackbar.dart';

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
    // Login/SignUp/PasswordRecovery должны быть full-screen — без
    // bottom-навбара под ними. SignUp/Recovery пушатся через
    // `Navigator.of(context).push` из `LoginPage`, который сам
    // живёт внутри branch-навигатора `/profile`. Значит их видимость
    // совпадает с условием «текущая ветка — profile, и пользователь
    // не залогинен» (для залогиненного на /profile рисуется
    // `AdminAfterLoginPage` — там навбар уместен). Подписываемся
    // на `userLoggedInNotifier`, чтобы навбар возвращался сразу
    // после успешного логина без перерисовки сверху.
    final onProfileBranch = tab == AppNavTab.profile;
    return Scaffold(
      body: navShell,
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: bottomNavVisibleNotifier,
        builder: (context, visible, _) {
          if (!visible) return const SizedBox.shrink();
          return ValueListenableBuilder<bool>(
            valueListenable: userLoggedInNotifier,
            builder: (context, userLoggedIn, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: adminLoggedInNotifier,
                builder: (context, adminLoggedIn, _) {
                  // На ветке profile без авторизации показывается
                  // LoginPage / SignUpPage / PasswordRecoveryPage —
                  // они должны быть full-screen, без навбара.
                  if (onProfileBranch && !userLoggedIn && !adminLoggedIn) {
                    return const SizedBox.shrink();
                  }
                  return AppBottomNavBar(
                    current: tab,
                    onTap: (next) => _onTabTap(context, next),
                  );
                },
              );
            },
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
      showRegistrationRequiredSnackBar(context);
      return;
    }
    final idx = tab.index;
    navShell.goBranch(idx, initialLocation: idx == navShell.currentIndex);
  }
}
