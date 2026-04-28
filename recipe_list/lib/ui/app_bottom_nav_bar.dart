import 'package:flutter/material.dart';

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
    _NavItem(AppNavTab.recipes, 'Рецепты', Icons.local_pizza_outlined),
    _NavItem(AppNavTab.fridge, 'Холодильник', Icons.kitchen_outlined),
    _NavItem(AppNavTab.favorites, 'Избранное', Icons.favorite_border),
    _NavItem(AppNavTab.profile, 'Профиль', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
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
            height: 60,
            child: Row(
              children: [
                for (final item in _items)
                  Expanded(
                    child: _Tab(
                      item: item,
                      active: item.tab == current,
                      onTap: onTap == null ? null : () => onTap!(item.tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final AppNavTab tab;
  final String label;
  final IconData icon;

  const _NavItem(this.tab, this.label, this.icon);
}

class _Tab extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback? onTap;

  const _Tab({required this.item, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textInactive;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(item.icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: AppTextStyles.tabLabel.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
