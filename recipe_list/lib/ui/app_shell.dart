import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_bottom_nav_bar.dart';

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
      bottomNavigationBar: AppBottomNavBar(
        current: tab,
        onTap: (next) => _onTabTap(next),
      ),
    );
  }

  /// Поведение `goBranch`: при повторном тапе на текущую вкладку
  /// `initialLocation: true` сбрасывает её стек к корневому
  /// маршруту (стандартный UX мобильных табов).
  void _onTabTap(AppNavTab tab) {
    final idx = tab.index;
    navShell.goBranch(idx, initialLocation: idx == navShell.currentIndex);
  }
}
