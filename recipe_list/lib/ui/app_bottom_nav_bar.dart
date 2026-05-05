import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import 'app_theme.dart';

/// Идентификаторы вкладок нижнего навбара (`logIn`-вариант, §6 дизайн-системы).
enum AppNavTab { recipes, fridge, favorites, profile }

/// Нижний навбар согласно `docs/design_system.md` §6:
/// 428×60 dp, фон `#FFFFFF`, тень blur 8 / offset 0/0 / `rgba(0,0,0,0.25)`.
/// Активная вкладка — `#2ECC71`, неактивные — `#C2C2C2`. Подписи
/// Roboto 400 / 10 / 23. Иконки 24 dp.
///
/// Иконки в Figma — растровые `icons8-*`. До добавления SVG-ассетов в
/// `assets/icons/nav/` используем близкие по смыслу `Icons.*` из
/// Material-набора.
class AppBottomNavBar extends StatelessWidget {
  final AppNavTab current;
  final ValueChanged<AppNavTab>? onTap;

  const AppBottomNavBar({super.key, required this.current, this.onTap});

  static const _items = <_NavItem>[
    _NavItem(AppNavTab.recipes, Icons.local_pizza_outlined),
    _NavItem(AppNavTab.fridge, Icons.kitchen_outlined),
    _NavItem(AppNavTab.favorites, Icons.favorite_border),
    _NavItem(AppNavTab.profile, Icons.person_outline),
  ];

  static String _label(AppNavTab tab, S s) => switch (tab) {
    AppNavTab.recipes => s.tabRecipes,
    AppNavTab.fridge => s.tabFridge,
    AppNavTab.favorites => s.tabFavorites,
    AppNavTab.profile => s.tabProfile,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Material(
      color: AppColors.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: AppShadows.navBar,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 84,
            // Закрепляем порядок вкладок слева-направо даже в RTL-локалях
            // (ar/fa/ku). Дизайн-система §6 описывает фиксированную
            // последовательность Recipes → Fridge → Favorites → Profile;
            // зеркалить её под направление текста было бы дезориентирующе
            // (иконки не несут текстовой семантики). Локальная
            // Directionality.ltr не влияет на остальной интерфейс.
            child: ValueListenableBuilder<bool>(
              valueListenable: userLoggedInNotifier,
              builder: (context, userLoggedIn, _) {
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      for (final item in _items)
                        Expanded(
                          child: _Tab(
                            icon: item.tab == AppNavTab.profile && userLoggedIn
                                ? Icons.person
                                : item.icon,
                            label: _label(item.tab, s),
                            // Profile-tab имеет 3 состояния:
                            //   grey outlined  — не выбрана, не залогинен
                            //   green outlined — выбрана, не залогинен
                            //   green filled   — залогинен (выбрана или нет)
                            // Остальные tab'ы — обычное active = (tab == current).
                            active:
                                item.tab == current ||
                                (item.tab == AppNavTab.profile && userLoggedIn),
                            onTap: onTap == null
                                ? null
                                : () => onTap!(item.tab),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final AppNavTab tab;
  final IconData icon;

  const _NavItem(this.tab, this.icon);
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textInactive;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.tabLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
